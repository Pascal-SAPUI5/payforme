//
//  ReceiptTotals.swift
//  Divido
//
//  Findet den Endbetrag im erkannten Text, ohne ein Modell zu fragen.
//
//  Das ist bewusst kein Ersatz, sondern ein Netz. Ein Sprachmodell laesst sich
//  hier nicht pruefen, also darf der wichtigste Wert der ganzen Rechnung nicht
//  allein an ihm haengen. Der Endbetrag ist ausserdem der einzige Wert, den ein
//  Kassenzettel verlaesslich auszeichnet: Er steht unten und traegt ein
//  Schluesselwort.
//

import Foundation

enum ReceiptTotals {

    /// Woran eine Endbetragszeile zu erkennen ist.
    static let markers = [
        "GESAMTBETRAG", "GESAMTSUMME", "ZAHLBETRAG", "ZU ZAHLEN",
        "GESAMT", "SUMME", "TOTAL", "ENDBETRAG"
    ]

    /// Zeilen, die zwar ein Schluesselwort tragen, aber nicht der Endbetrag sind.
    ///
    /// ZWISCHENSUMME enthaelt SUMME und wuerde sonst gewinnen, weil sie weiter
    /// unten stehen kann als die Positionen. Die Zahlungszeilen sind noch
    /// gefaehrlicher: Gegeben und Rueckgeld sind fast immer groesser als der
    /// Betrag, den man teilen will.
    static let disqualifiers = [
        "ZWISCHENSUMME", "ZW.SUMME", "ZWSUMME",
        "MWST", "UST", "STEUER", "NETTO", "BRUTTO",
        "GEGEBEN", "RUECKGELD", "RÜCKGELD", "WECHSELGELD", "ZURUECK", "ZURÜCK",
        "TRINKGELD", "PFAND"
    ]

    /// Der Endbetrag, oder nichts, wenn keine Zeile ihn ausweist.
    ///
    /// Gesucht wird von unten nach oben, weil der Endbetrag am Ende des
    /// Kassenzettels steht. Die erste Zeile von unten, die ein Schluesselwort
    /// und einen Betrag traegt, gewinnt.
    static func total(in lines: [String]) -> Double? {
        for line in lines.reversed() {
            let upper = normalized(line)
            guard markers.contains(where: { upper.contains($0) }) else { continue }
            guard !disqualifiers.contains(where: { upper.contains($0) }) else { continue }
            if let amount = lastAmount(in: line) { return amount }
        }
        return nil
    }

    /// Entscheidet, welcher Endbetrag gilt, wenn Modell und Text sich uneinig
    /// sind.
    ///
    /// Der Schiedsrichter ist die Summe der Positionen. Ein Endbetrag, der zu
    /// ihr passt, ist mit hoher Wahrscheinlichkeit der richtige; einer, der
    /// abweicht, ist meist eine Zwischensumme oder ein gegebener Betrag.
    /// Passt keiner, bleibt es beim Modell — es hat den ganzen Zettel gesehen,
    /// die Suche nur die Zeilen mit Schluesselwort.
    static func preferred(model: Double?, fromText: Double?, sumOfItems: Double) -> Double? {
        guard let model else { return fromText }
        guard let fromText, abs(fromText - model) > 0.005 else { return model }

        let modelFits = abs(model - sumOfItems) <= 0.02
        let textFits = abs(fromText - sumOfItems) <= 0.02
        return textFits && !modelFits ? fromText : model
    }

    // MARK: - Intern

    /// Grossschreibung und Umlaute vereinheitlichen, damit "Zwischensumme",
    /// "ZWISCHENSUMME" und "Zw.Summe" dieselbe Behandlung bekommen.
    private static func normalized(_ line: String) -> String {
        line.uppercased()
            .replacingOccurrences(of: "Ä", with: "AE")
            .replacingOccurrences(of: "Ö", with: "OE")
            .replacingOccurrences(of: "Ü", with: "UE")
    }

    /// Der letzte Betrag der Zeile.
    ///
    /// "SUMME 19% EUR 31,90" traegt mehrere Zahlen, wenn die Texterkennung den
    /// Steuersatz mitliest. Der Betrag steht rechts.
    static func lastAmount(in line: String) -> Double? {
        // Optionale Tausendergruppen, dann genau zwei Nachkommastellen.
        let pattern = #"-?\d{1,7}(?:[.,]\d{3})*[.,]\d{2}(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..., in: line)
        guard let last = regex.matches(in: line, range: range).last,
              let found = Range(last.range, in: line) else { return nil }
        return amount(from: String(line[found]))
    }

    /// Wandelt einen geschriebenen Betrag in eine Zahl.
    ///
    /// Nicht ueber ReceiptParser.price: Das letzte Trennzeichen ist das
    /// Dezimaltrennzeichen, alle davor gruppieren Tausender. Wer stur jedes
    /// Komma zum Punkt macht, bekommt aus "1.234,56" die Zeichenkette
    /// "1.234.56" und damit keine Zahl mehr.
    static func amount(from text: String) -> Double? {
        let cleaned = text.filter { $0.isNumber || $0 == "." || $0 == "," || $0 == "-" }
        guard let separator = cleaned.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return Double(cleaned).flatMap { $0 > 0 ? $0 : nil }
        }
        let whole = cleaned[cleaned.startIndex..<separator].filter { $0.isNumber || $0 == "-" }
        let fraction = cleaned[cleaned.index(after: separator)...]
        guard let value = Double("\(whole).\(fraction)"), value > 0 else { return nil }
        return (value * 100).rounded() / 100
    }
}
