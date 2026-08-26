//
//  ReceiptSplitter.swift
//  Divido
//
//  Macht aus einem Bon mit zugeordneten Positionen die Rechnungen, die daraus
//  entstehen.
//
//  Eine Bill kennt einen Betrag und eine Liste von Schuldnern, aber keine
//  Positionen. Die Zuordnung pro Artikel muss deshalb beim Anlegen uebersetzt
//  werden. Eine Rechnung je Person waere die naive Loesung und erzeugt bei
//  einem Wocheneinkauf ein Dutzend Belege. Stattdessen wird nach Zuordnung
//  gruppiert: Alles, was denselben Leuten gehoert, wird ein Beleg.
//
//  Reine Arithmetik, kein Netzwerk, keine Oberflaeche.
//

import Foundation

/// Eine Rechnung, wie sie aus dem Bon entstehen wuerde, bevor sie angelegt ist.
struct BillDraft: Equatable {
    /// Wofuer, aus den Namen der enthaltenen Positionen gebildet.
    var what: String
    /// Der Betrag in Euro, auf Cent gerundet.
    var amount: Double
    /// Wer die Rechnung traegt, aufsteigend sortiert damit der Vergleich
    /// unabhaengig von der Reihenfolge im Bon ist.
    var owerIDs: [Int]
    /// Die Positionen, aus denen die Rechnung entstanden ist.
    var items: [ScannedItem]
}

enum ReceiptSplitter {

    /// Wie viele Artikelnamen in die Bezeichnung wandern, bevor gekuerzt wird.
    static let namesInDescription = 3

    /// Die Rechnungen, die aus dem Bon entstehen.
    ///
    /// `participants` sind die Personen des Projekts. Positionen ohne Zuordnung
    /// gehoeren allen. Eine Zuordnung auf jemanden, der nicht mehr im Projekt
    /// ist, faellt auf alle zurueck, weil eine Rechnung ohne Schuldner beim
    /// Server nicht anzulegen ist.
    static func drafts(for receipt: ScannedReceipt, participants: [Int]) -> [BillDraft] {
        guard !participants.isEmpty else { return [] }
        let everyone = participants.sorted()

        // Nach Zuordnung gruppieren. Der Schluessel ist die sortierte Liste der
        // Personen, damit {2,1} und {1,2} dieselbe Gruppe ergeben.
        var groups: [[Int]: [ScannedItem]] = [:]
        for item in receipt.items where item.price > 0 {
            let assigned = participants.filter { item.assignedTo.contains($0) }.sorted()
            let key = assigned.isEmpty ? everyone : assigned
            groups[key, default: []].append(item)
        }

        // Nach Schuldnern sortiert ausgeben, damit die Reihenfolge nicht von
        // der Laune eines Dictionary abhaengt.
        return groups
            .sorted { lexicographicallyPrecedes($0.key, $1.key) }
            .map { key, items in
                BillDraft(what: description(of: items),
                          amount: cents(items.reduce(0) { $0 + $1.price * Double($1.quantity) }),
                          owerIDs: key,
                          items: items)
            }
    }

    /// Was der Bon ausweist, aber keine Position erklaert.
    ///
    /// Groesser als null heisst meist: Die Texterkennung hat eine Zeile
    /// verschluckt. Das wird gemeldet statt still ausgeglichen, denn eine
    /// erfundene Position waere schlimmer als ein sichtbarer Rest.
    static func unaccounted(in receipt: ScannedReceipt) -> Double {
        guard let total = receipt.total else { return 0 }
        return cents(total - receipt.sumOfItems)
    }

    // MARK: - Intern

    private static func description(of items: [ScannedItem]) -> String {
        let names = items.map(\.name)
        guard names.count > namesInDescription else {
            return names.joined(separator: ", ")
        }
        let shown = names.prefix(namesInDescription).joined(separator: ", ")
        return "\(shown) und \(names.count - namesInDescription) weitere"
    }

    /// Auf Cent runden. Preise und Mengen sind bereits centgenau, gerundet wird
    /// also nur das Rauschen der Gleitkommadarstellung weg.
    private static func cents(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }

    private static func lexicographicallyPrecedes(_ a: [Int], _ b: [Int]) -> Bool {
        a.lexicographicallyPrecedes(b)
    }
}
