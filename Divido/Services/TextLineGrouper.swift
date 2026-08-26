//
//  TextLineGrouper.swift
//  Divido
//
//  Setzt die Textbruchstücke einer Texterkennung zu Zeilen zusammen.
//
//  Vision liefert keine Zeilen, sondern Regionen mit Rechteck. Auf einem
//  Kassenbon stehen Artikelname und Preis meist in getrennten Regionen, weil
//  die Spalten weit auseinander liegen. Wer die Regionen in der gelieferten
//  Reihenfolge aneinanderhaengt, bekommt Namen und Preise entkoppelt und damit
//  einen Bon, den kein Modell mehr richtig zuordnen kann.
//
//  Bewusst ohne Vision-Import: Das Zusammensetzen ist reine Geometrie und
//  laesst sich damit ohne Kamera und ohne Geraet pruefen.
//

import Foundation

/// Ein erkanntes Textstueck mit seiner Lage im Bild.
///
/// Die Koordinaten folgen der Konvention von Vision: normiert auf 0 bis 1, und
/// der Ursprung liegt unten links. `midY` ist also umso groesser, je weiter
/// oben das Stueck auf dem Bon steht.
struct TextFragment: Equatable {
    let text: String
    let midY: Double
    let minX: Double
    let height: Double

    init(text: String, midY: Double, minX: Double, height: Double) {
        self.text = text
        self.midY = midY
        self.minX = minX
        self.height = height
    }
}

enum TextLineGrouper {

    /// Wie weit zwei Stuecke senkrecht auseinander liegen duerfen und trotzdem
    /// als eine Zeile gelten, gemessen in Vielfachen der Texthoehe.
    ///
    /// Der Wert ist bewusst kleiner als eins: Zwei Bruchstuecke derselben Zeile
    /// weichen in der Mitte kaum ab, waehrend die naechste Zeile mindestens eine
    /// Texthoehe entfernt beginnt.
    static let defaultTolerance = 0.6

    /// Fuegt die Bruchstuecke zu Zeilen zusammen, von oben nach unten.
    ///
    /// Innerhalb einer Zeile wird von links nach rechts sortiert, damit der
    /// Artikelname vor seinem Preis steht. Leere Stuecke fallen raus, sonst
    /// entstehen Zeilen aus lauter Leerzeichen.
    static func lines(from fragments: [TextFragment],
                      tolerance: Double = defaultTolerance) -> [String] {
        let usable = fragments.filter {
            !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !usable.isEmpty else { return [] }

        // Von oben nach unten, also nach fallendem midY.
        let sorted = usable.sorted { $0.midY > $1.midY }

        var groups: [[TextFragment]] = []
        for fragment in sorted {
            if let last = groups.last, belongsToSameLine(fragment, as: last, tolerance: tolerance) {
                groups[groups.count - 1].append(fragment)
            } else {
                groups.append([fragment])
            }
        }

        return groups.map { group in
            group
                .sorted { $0.minX < $1.minX }
                .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                .joined(separator: " ")
        }
    }

    /// Der Text des ganzen Bons, Zeile fuer Zeile.
    static func text(from fragments: [TextFragment],
                     tolerance: Double = defaultTolerance) -> String {
        lines(from: fragments, tolerance: tolerance).joined(separator: "\n")
    }

    // MARK: - Intern

    /// Vergleicht gegen den Mittelwert der bisherigen Zeile statt gegen ihr
    /// erstes Stueck. Sonst wandert die Zeile mit jedem angehaengten Stueck
    /// weiter und schluckt irgendwann die naechste.
    private static func belongsToSameLine(_ fragment: TextFragment,
                                          as line: [TextFragment],
                                          tolerance: Double) -> Bool {
        let lineMidY = line.reduce(0.0) { $0 + $1.midY } / Double(line.count)
        let lineHeight = line.reduce(0.0) { $0 + $1.height } / Double(line.count)
        let limit = max(fragment.height, lineHeight) * tolerance
        return abs(fragment.midY - lineMidY) <= limit
    }
}
