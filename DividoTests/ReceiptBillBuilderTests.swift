//
//  ReceiptBillBuilderTests.swift
//  DividoTests
//
//  Prueft den Bau der Rechnungen und vor allem, dass sie einzeln nacheinander
//  weggehen. ProjectManager haelt genau eine Cancellable; ueberlappende Aufrufe
//  verlieren Rechnungen still.
//

import XCTest
@testable import Divido

final class ReceiptBillBuilderTests: XCTestCase {

    private let anna = Person(id: 1, weight: 1, name: "Anna", activated: true, color: nil)
    private let ben = Person(id: 2, weight: 1, name: "Ben", activated: true, color: nil)

    private var members: [Person] { [anna, ben] }

    private var referenceDate: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 26
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func draft(_ what: String, _ amount: Double, owers: [Int]) -> BillDraft {
        BillDraft(what: what, amount: amount, owerIDs: owers, items: [])
    }

    // MARK: - Bau

    func testDraftBecomesABillWithItsOwers() {
        let bills = ReceiptBillBuilder.bills(from: [draft("Milch, Brot", 3.78, owers: [1, 2])],
                                             payerID: anna.id,
                                             date: referenceDate,
                                             members: members,
                                             backend: .cospend)

        XCTAssertEqual(bills.count, 1)
        XCTAssertEqual(bills.first?.amount, 3.78)
        XCTAssertEqual(bills.first?.what, "Milch, Brot")
        XCTAssertEqual(bills.first?.owers, [anna, ben])
        XCTAssertEqual(bills.first?.payer_id, anna.id)
        XCTAssertEqual(bills.first?.date, referenceDate)
    }

    func testNewBillsCarryTheUnsavedIdentifier() {
        // -1 ist die Kennung, an der ProjectManager anlegen von aendern
        // unterscheidet. Eine echte Kennung hier wuerde eine fremde Rechnung
        // ueberschreiben.
        let bills = ReceiptBillBuilder.bills(from: [draft("Milch", 1.29, owers: [1])],
                                             payerID: anna.id, date: referenceDate,
                                             members: members, backend: .cospend)

        XCTAssertEqual(bills.first?.id, -1)
    }

    func testUnknownOwerIsDropped() {
        let bills = ReceiptBillBuilder.bills(from: [draft("Milch", 1.29, owers: [1, 99])],
                                             payerID: anna.id, date: referenceDate,
                                             members: members, backend: .cospend)

        XCTAssertEqual(bills.first?.owers, [anna])
    }

    func testDraftWithoutAnyKnownOwerIsSkipped() {
        // Eine Rechnung ohne Schuldner nimmt der Server nicht an. Lieber gar
        // nicht anlegen als einen Fehlschlag provozieren.
        let bills = ReceiptBillBuilder.bills(from: [draft("Milch", 1.29, owers: [99])],
                                             payerID: anna.id, date: referenceDate,
                                             members: members, backend: .cospend)

        XCTAssertTrue(bills.isEmpty)
    }

    func testRepeatFieldFollowsTheBackend() {
        let cospend = ReceiptBillBuilder.bills(from: [draft("Milch", 1.29, owers: [1])],
                                               payerID: anna.id, date: referenceDate,
                                               members: members, backend: .cospend)
        let iHateMoney = ReceiptBillBuilder.bills(from: [draft("Milch", 1.29, owers: [1])],
                                                  payerID: anna.id, date: referenceDate,
                                                  members: members, backend: .iHateMoney)

        XCTAssertEqual(cospend.first?.repeat, "n")
        XCTAssertNil(iHateMoney.first?.repeat, "iHateMoney kennt das Feld nicht")
    }

    func testNoDraftsGiveNoBills() {
        XCTAssertTrue(ReceiptBillBuilder.bills(from: [], payerID: anna.id, date: referenceDate,
                                               members: members, backend: .cospend).isEmpty)
    }

    // MARK: - Versand

    func testBillsAreSentOneAfterAnother() {
        // Der eigentliche Punkt: Nie darf ein zweiter Versand starten, solange
        // der erste laeuft.
        let bills = ReceiptBillBuilder.bills(
            from: [draft("A", 1.00, owers: [1]),
                   draft("B", 2.00, owers: [2]),
                   draft("C", 3.00, owers: [1, 2])],
            payerID: anna.id, date: referenceDate, members: members, backend: .cospend)

        var log: [String] = []
        var pending: (() -> Void)?
        var finished = false

        ReceiptBillBuilder.post(bills, using: { bill, done in
            log.append("start \(bill.what)")
            // Der Versand endet nicht sofort, sondern erst wenn der Test ihn
            // beendet — so wuerde eine Ueberlappung sichtbar.
            pending = {
                log.append("done \(bill.what)")
                done()
            }
        }, completion: { finished = true })

        while let next = pending {
            pending = nil
            next()
        }

        XCTAssertEqual(log, ["start A", "done A",
                             "start B", "done B",
                             "start C", "done C"])
        XCTAssertTrue(finished)
    }

    func testCompletionFiresEvenWithoutBills() {
        var finished = false

        ReceiptBillBuilder.post([], using: { _, done in done() }, completion: { finished = true })

        XCTAssertTrue(finished, "sonst haengt die Oberflaeche im Ladezustand fest")
    }

    func testEverySingleBillIsSent() {
        let bills = ReceiptBillBuilder.bills(
            from: [draft("A", 1.00, owers: [1]), draft("B", 2.00, owers: [2])],
            payerID: anna.id, date: referenceDate, members: members, backend: .cospend)

        var sent: [String] = []
        ReceiptBillBuilder.post(bills, using: { bill, done in
            sent.append(bill.what)
            done()
        }, completion: {})

        XCTAssertEqual(sent, ["A", "B"])
    }
}
