//
//  ScannedReceipt.swift
//  Divido
//
//  Was aus einem fotografierten Kassenbon herausgelesen wurde, bevor daraus
//  eine Rechnung wird.
//
//  Der Wert steckt nicht im Gesamtbetrag — den tippt man in fünf Sekunden ab —
//  sondern in den Einzelpositionen. Wer für drei Leute einkauft, hat auf dem Bon
//  Dinge, die allen gehören, und Dinge, die einer Person gehören. Erst wenn die
//  Positionen einzeln vorliegen, lässt sich das ohne Kopfrechnen aufteilen.
//

import Foundation

/// Eine Position auf dem Bon.
struct ScannedItem: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var quantity: Int
    var price: Double

    /// Wem diese Position zugeordnet ist. Leer heißt: von allen geteilt.
    var assignedTo: Set<Int> = []

    private enum CodingKeys: String, CodingKey {
        case name, quantity, price
    }
}

/// Das Ergebnis einer Bonerkennung.
struct ScannedReceipt: Equatable {
    var retailer: String?
    var date: Date
    var total: Double?
    var items: [ScannedItem]

    /// Summe der erkannten Positionen.
    var sumOfItems: Double {
        items.reduce(0) { $0 + $1.price * Double($1.quantity) }
    }

    /// Passt die Summe der Positionen zum ausgelesenen Gesamtbetrag?
    ///
    /// Die Toleranz von zwei Cent fängt Rundung auf Bonzeilen ab. Weicht es
    /// stärker ab, fehlt meist eine Zeile oder eine wurde doppelt gelesen — der
    /// Nutzer sollte das sehen, statt dass die App eine falsche Summe als
    /// sicher ausgibt.
    var matchesTotal: Bool {
        guard let total else { return false }
        return abs(total - sumOfItems) <= 0.02
    }

    /// Der Betrag, mit dem die Rechnung angelegt wird.
    ///
    /// Der ausgelesene Gesamtbetrag hat Vorrang, denn er steht als eine Zahl auf
    /// dem Bon und wird zuverlässiger erkannt als zwanzig einzelne Zeilen.
    var effectiveTotal: Double {
        total ?? sumOfItems
    }
}
