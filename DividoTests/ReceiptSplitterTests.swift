//
//  ReceiptSplitterTests.swift
//  DividoTests
//
//  Prueft die Arithmetik, die aus einem zugeordneten Bon Rechnungen macht.
//  Die Beispiele sind ein echter Einkauf zu dritt.
//

import XCTest
@testable import Divido

final class ReceiptSplitterTests: XCTestCase {

    private let anna = 1, ben = 2, clara = 3
    private var everyone: [Int] { [anna, ben, clara] }

    private var referenceDate: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 26
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func receipt(_ items: [ScannedItem], total: Double? = nil) -> ScannedReceipt {
        ScannedReceipt(retailer: "REWE", date: referenceDate, total: total, items: items)
    }

    private func item(_ name: String, _ price: Double, quantity: Int = 1, to owners: Set<Int> = []) -> ScannedItem {
        ScannedItem(name: name, quantity: quantity, price: price, assignedTo: owners)
    }

    // MARK: - Gruppierung

    func testUnassignedItemsBecomeOneBillForEveryone() {
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Milch", 1.29), item("Brot", 2.49)]),
            participants: everyone
        )

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.owerIDs, everyone)
        XCTAssertEqual(drafts.first?.amount, 3.78)
    }

    func testItemsForDifferentPeopleBecomeSeparateBills() {
        // Der Alltagsfall: Der gemeinsame Einkauf, und das Shampoo gehoert Ben.
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Milch", 1.29),
                          item("Brot", 2.49),
                          item("Shampoo", 7.40, to: [ben])]),
            participants: everyone
        )

        XCTAssertEqual(drafts.count, 2)
        let shared = drafts.first { $0.owerIDs == everyone }
        let bensOwn = drafts.first { $0.owerIDs == [ben] }
        XCTAssertEqual(shared?.amount, 3.78)
        XCTAssertEqual(bensOwn?.amount, 7.40)
        XCTAssertEqual(bensOwn?.what, "Shampoo")
    }

    func testSameAssignmentInAnyOrderIsOneGroup() {
        // Die Zuordnung ist eine Menge. {Ben, Anna} und {Anna, Ben} duerfen
        // nicht zu zwei Rechnungen fuehren.
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Wein", 8.99, to: [ben, anna]),
                          item("Käse", 4.50, to: [anna, ben])]),
            participants: everyone
        )

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.owerIDs, [anna, ben])
        XCTAssertEqual(drafts.first?.amount, 13.49)
    }

    func testOrderOfBillsDoesNotDependOnADictionary() {
        // Zweimal derselbe Bon muss zweimal dieselbe Reihenfolge ergeben,
        // sonst springt die Oberflaeche bei jedem Aufbau.
        let bon = receipt([item("A", 1.00, to: [clara]),
                           item("B", 2.00, to: [anna]),
                           item("C", 3.00, to: [ben])])

        let first = ReceiptSplitter.drafts(for: bon, participants: everyone).map(\.owerIDs)
        let second = ReceiptSplitter.drafts(for: bon, participants: everyone).map(\.owerIDs)

        XCTAssertEqual(first, second)
        XCTAssertEqual(first, [[anna], [ben], [clara]])
    }

    // MARK: - Betraege

    func testQuantityMultipliesThePrice() {
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Butter", 2.29, quantity: 2)]),
            participants: everyone
        )

        XCTAssertEqual(drafts.first?.amount, 4.58)
    }

    func testBillsTogetherCoverTheWholeReceipt() {
        let bon = receipt([item("Milch", 1.29),
                           item("Brot", 2.49),
                           item("Shampoo", 7.40, to: [ben]),
                           item("Wein", 8.99, to: [anna, ben])])

        let drafts = ReceiptSplitter.drafts(for: bon, participants: everyone)
        let sum = drafts.reduce(0) { $0 + $1.amount }

        XCTAssertEqual(sum, bon.sumOfItems, accuracy: 0.001,
                       "kein Cent darf beim Aufteilen verloren gehen")
    }

    // MARK: - Randfaelle

    func testAssignmentToSomeoneWhoLeftFallsBackToEveryone() {
        // Person 99 ist nicht mehr im Projekt. Eine Rechnung ohne Schuldner
        // nimmt der Server nicht an, also traegt sie wieder die Gruppe.
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Milch", 1.29, to: [99])]),
            participants: everyone
        )

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts.first?.owerIDs, everyone)
    }

    func testPartiallyUnknownAssignmentKeepsThePeopleWhoRemain() {
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Milch", 1.29, to: [anna, 99])]),
            participants: everyone
        )

        XCTAssertEqual(drafts.first?.owerIDs, [anna])
    }

    func testWithoutParticipantsThereIsNothingToSplit() {
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Milch", 1.29)]),
            participants: []
        )

        XCTAssertTrue(drafts.isEmpty)
    }

    func testEmptyReceiptGivesNoBills() {
        XCTAssertTrue(ReceiptSplitter.drafts(for: receipt([]), participants: everyone).isEmpty)
    }

    // MARK: - Bezeichnung

    func testDescriptionListsTheItems() {
        let drafts = ReceiptSplitter.drafts(
            for: receipt([item("Milch", 1.29), item("Brot", 2.49)]),
            participants: everyone
        )

        XCTAssertEqual(drafts.first?.what, "Milch, Brot")
    }

    func testLongDescriptionIsShortened() {
        // Ein Wocheneinkauf hat dreissig Positionen. Die alle in den
        // Verwendungszweck zu schreiben macht die Liste unlesbar.
        let items = (1...10).map { item("Artikel \($0)", 1.00) }
        let drafts = ReceiptSplitter.drafts(for: receipt(items), participants: everyone)

        XCTAssertEqual(drafts.first?.what, "Artikel 1, Artikel 2, Artikel 3 und 7 weitere")
    }

    // MARK: - Fehlbetrag

    func testMissedLineIsReportedNotInvented() {
        // Der Bon weist 12.00 aus, erkannt sind 10.00. Die fehlenden zwei Euro
        // werden gemeldet. Sie still auf die Gruppe zu buchen wuerde eine
        // Position erfinden, die niemand geprueft hat.
        let bon = receipt([item("Milch", 4.00), item("Brot", 6.00)], total: 12.00)

        XCTAssertEqual(ReceiptSplitter.unaccounted(in: bon), 2.00, accuracy: 0.001)
        XCTAssertFalse(bon.matchesTotal)
    }

    func testNothingIsUnaccountedWhenTheSumFits() {
        let bon = receipt([item("Milch", 4.00), item("Brot", 6.00)], total: 10.00)

        XCTAssertEqual(ReceiptSplitter.unaccounted(in: bon), 0, accuracy: 0.001)
        XCTAssertTrue(bon.matchesTotal)
    }

    func testWithoutATotalNothingIsMissing() {
        let bon = receipt([item("Milch", 4.00)], total: nil)

        XCTAssertEqual(ReceiptSplitter.unaccounted(in: bon), 0, accuracy: 0.001)
    }
}
