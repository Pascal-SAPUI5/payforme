//
//  ReceiptBillBuilder.swift
//  Divido
//
//  Macht aus den Entwuerfen des Bons echte Rechnungen und schickt sie weg.
//
//  Das Wegschicken ist bewusst streng nacheinander. Das ist keine Vorsicht,
//  sondern Pflicht: ProjectManager haelt genau eine Cancellable und bricht sie
//  bei jedem neuen Aufruf ab. Zwei Rechnungen gleichzeitig abzuschicken heisst,
//  die erste still zu verlieren — ohne Fehler, ohne Meldung.
//

import Foundation

enum ReceiptBillBuilder {

    /// Die Rechnungen, die angelegt werden sollen.
    ///
    /// `members` bestimmt, wer als Schuldner in Frage kommt. Eine Kennung ohne
    /// passendes Mitglied faellt raus, statt eine leere Person zu erfinden.
    static func bills(from drafts: [BillDraft],
                      payerID: Int,
                      date: Date,
                      members: [Person],
                      backend: ProjectBackend) -> [Bill] {
        // Nicht uniqueKeysWithValues: Zwei Mitglieder mit derselben Kennung
        // sind ein Serverfehler, aber kein Grund fuer einen Absturz.
        let byID = Dictionary(members.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        return drafts.compactMap { draft in
            let owers = draft.owerIDs.compactMap { byID[$0] }
            guard !owers.isEmpty else { return nil }

            return Bill(id: -1,
                        amount: draft.amount,
                        what: draft.what,
                        date: date,
                        payer_id: payerID,
                        owers: owers,
                        // Cospend erwartet das Feld, iHateMoney kennt es nicht.
                        repeat: backend == .cospend ? "n" : nil,
                        lastchanged: 0,
                        categoryid: nil,
                        paymentmode: nil)
        }
    }

    /// Schickt die Rechnungen eine nach der anderen weg.
    ///
    /// `save` ist hereingereicht, damit die Reihenfolge pruefbar bleibt, ohne
    /// einen Server zu brauchen.
    static func post(_ bills: [Bill],
                     using save: @escaping (Bill, @escaping () -> Void) -> Void,
                     completion: @escaping () -> Void) {
        var remaining = bills

        func sendNext() {
            guard !remaining.isEmpty else {
                completion()
                return
            }
            let bill = remaining.removeFirst()
            save(bill) { sendNext() }
        }

        sendNext()
    }
}
