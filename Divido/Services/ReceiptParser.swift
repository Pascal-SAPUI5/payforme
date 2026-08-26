//
//  ReceiptParser.swift
//  Divido
//
//  Macht aus der Antwort eines Sprachmodells eine Bonstruktur.
//
//  Bewusst ohne Vision, ohne FoundationModels, ohne Netzwerk: So lässt sich das
//  Parsen gegen echte Modellantworten testen, ohne ein Gerät. Das ist der
//  größere und fehleranfälligere Teil der Erkennung — Modelle liefern Komma
//  statt Punkt, deutsche Datumsformate, und bei langen Bons Antworten, die
//  mitten in der Positionsliste abbrechen.
//

import Foundation

enum ReceiptParser {

    /// Der Prompt, mit dem das Modell antworten soll.
    ///
    /// Die Aufforderung, ausschließlich JSON zu liefern, ist notwendig, aber
    /// nicht hinreichend — Modelle stellen gern einen Satz voran. Deshalb sucht
    /// `extract` das JSON heraus, statt die ganze Antwort zu parsen.
    static let prompt = """
    Der folgende Text stammt von einem fotografierten Kassenbon. Lies den \
    Händler, das Kaufdatum, alle gekauften Artikel mit Einzelpreis und den \
    Gesamtbetrag. Ignoriere Pfand-, Rabatt-, Zwischensummen- und Steuerzeilen. \
    Antworte ausschließlich als JSON: \
    {"retailer":"...","date":"JJJJ-MM-TT","total":0.00,\
    "items":[{"name":"...","quantity":1,"price":0.00}]}. \
    Preise als Zahl mit Punkt. Keine Erklärung, kein Text vor oder nach dem JSON.
    """

    // MARK: - Einzelwerte

    /// Liest einen Preis aus dem, was ein Modell für eine Zahl hält.
    ///
    /// Deutsche Bons schreiben "1,29", Modelle geben mal `1.29`, mal `"1,29 €"`
    /// zurück. Negative Werte und Null sind auf einem Bon keine Position,
    /// sondern Rabatt- oder Summenzeilen.
    static func price(from value: Any?) -> Double? {
        guard let value else { return nil }
        let raw = String(describing: value)
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard let number = Double(raw), number > 0 else { return nil }
        return (number * 100).rounded() / 100
    }

    /// Akzeptiert 2026-08-16, 16.08.2026, 16.08.26 und 16/08/2026.
    ///
    /// Die Formate der Reihe nach durchzuprobieren reicht nicht. Ein
    /// DateFormatter mit "yyyy-MM-dd" nimmt auch "16.08.26" an und liest daraus
    /// das Jahr 16, weil er ueber die Trennzeichen hinwegsieht. Deshalb
    /// entscheidet erst die Form der Zeichenkette, welches Format ueberhaupt
    /// angewandt wird.
    static func date(from value: Any?, fallback: Date = Date()) -> Date {
        let raw = String(describing: value ?? "").trimmingCharacters(in: .whitespaces)

        let candidates: [(shape: String, format: String)] = [
            (#"(^\d{4}-\d{2}-\d{2})"#, "yyyy-MM-dd"),
            (#"(^\d{1,2}\.\d{1,2}\.\d{4})"#, "dd.MM.yyyy"),
            (#"(^\d{1,2}\.\d{1,2}\.\d{2})(?!\d)"#, "dd.MM.yy"),
            (#"(^\d{1,2}/\d{1,2}/\d{4})"#, "dd/MM/yyyy")
        ]

        for (shape, format) in candidates {
            guard let matched = firstMatch(in: raw, pattern: shape) else { continue }
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let parsed = formatter.date(from: matched) { return parsed }
        }
        return fallback
    }

    // MARK: - Ganze Antwort

    /// Holt das JSON-Objekt aus der Modellantwort.
    ///
    /// Sucht vom ersten `{` bis zum letzten `}`, weil Modelle Text davor und
    /// dahinter setzen. Schlägt das fehl, ist die Antwort meist mitten in der
    /// Positionsliste abgeschnitten — dann werden Kopfdaten und einzelne
    /// Positionen aus dem Rohtext gerettet, statt alles zu verwerfen. Bei einem
    /// Wocheneinkauf mit dreißig Zeilen passiert genau das regelmäßig.
    static func parse(_ text: String, now: Date = Date()) -> ScannedReceipt? {
        if let complete = parseComplete(text, now: now) { return complete }
        return salvage(text, now: now)
    }

    private static func parseComplete(_ text: String, now: Date) -> ScannedReceipt? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else { return nil }

        let slice = String(text[start...end])
        guard let data = slice.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        let items = (object["items"] as? [[String: Any]] ?? []).compactMap(item(from:))
        guard !items.isEmpty || object["total"] != nil else { return nil }

        return ScannedReceipt(
            retailer: (object["retailer"] as? String)?.trimmed.nilIfEmpty,
            date: date(from: object["date"], fallback: now),
            total: price(from: object["total"]),
            items: items
        )
    }

    /// Rettet, was aus einer abgeschnittenen Antwort noch lesbar ist.
    private static func salvage(_ text: String, now: Date) -> ScannedReceipt? {
        let retailer = firstMatch(in: text, pattern: #""retailer"\s*:\s*"([^"]*)""#)
        let dateString = firstMatch(in: text, pattern: #""date"\s*:\s*"([^"]*)""#)
        // Nicht [\d.,]+ nehmen: Die Klasse enthaelt das Komma und verschluckt
        // damit auch das Trennzeichen hinter dem Betrag. Aus 31.90, wird beim
        // Umwandeln 31.90. und das ist keine Zahl mehr.
        let totalString = firstMatch(in: text, pattern: #""total"\s*:\s*"?(-?\d+(?:[.,]\d+)?)"?"#)

        var items: [ScannedItem] = []
        for object in completeObjects(in: text) {
            if let parsed = item(from: object) { items.append(parsed) }
        }

        guard !items.isEmpty || totalString != nil else { return nil }

        return ScannedReceipt(
            retailer: retailer?.trimmed.nilIfEmpty,
            date: date(from: dateString, fallback: now),
            total: price(from: totalString),
            items: items
        )
    }

    // MARK: - Hilfen

    private static func item(from object: [String: Any]) -> ScannedItem? {
        guard let name = (object["name"] as? String)?.trimmed, !name.isEmpty,
              let unitPrice = price(from: object["price"]) else { return nil }
        // Nicht `price` nennen: Eine lokale Bindung mit dem Namen einer
        // statischen Funktion verdeckt diese im restlichen Rumpf.
        let quantity = max(1, (object["quantity"] as? Int) ?? Int(price(from: object["quantity"]) ?? 1))
        return ScannedItem(name: name, quantity: quantity, price: unitPrice)
    }

    /// Alle vollständigen `{...}`-Objekte, die keine weiteren enthalten.
    private static func completeObjects(in text: String) -> [[String: Any]] {
        guard let regex = try? NSRegularExpression(pattern: #"\{[^{}]*\}"#) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text),
                  let data = String(text[range]).data(using: .utf8) else { return nil }
            return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captured])
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
