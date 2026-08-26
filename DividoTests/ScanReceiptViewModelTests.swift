//
//  ScanReceiptViewModelTests.swift
//  DividoTests
//
//  Prueft den Zustandsautomaten und die Zuordnung des Bonscans.
//
//  Moeglich ist das nur, weil die Erkennung hereingereicht wird. Die echte
//  braucht Kamera und Sprachmodell; hier steht ein Doppelgaenger an ihrer
//  Stelle, und alles davor und dahinter wird geprueft.
//

import UIKit
import XCTest
@testable import Divido

@MainActor
final class ScanReceiptViewModelTests: XCTestCase {

    private let anna = Person(id: 1, weight: 1, name: "Anna", activated: true, color: nil)
    private let ben = Person(id: 2, weight: 1, name: "Ben", activated: true, color: nil)
    private let gone = Person(id: 3, weight: 1, name: "Ehemalig", activated: false, color: nil)

    private var referenceDate: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 26
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func receipt(_ items: [ScannedItem], total: Double? = nil) -> ScannedReceipt {
        ScannedReceipt(retailer: "REWE", date: referenceDate, total: total, items: items)
    }

    private func model(returning result: ScannedReceipt,
                       participants: [Person]? = nil) -> ScanReceiptViewModel {
        ScanReceiptViewModel(participants: participants ?? [anna, ben],
                             recognizer: { _ in result })
    }

    private func failingModel(_ error: Error) -> ScanReceiptViewModel {
        ScanReceiptViewModel(participants: [anna, ben], recognizer: { _ in throw error })
    }

    private let anyImage = UIImage()

    // MARK: - Zustaende

    func testStartsIdle() {
        XCTAssertEqual(model(returning: receipt([])).phase, .idle)
    }

    func testSuccessfulScanBecomesReady() async {
        let sut = model(returning: receipt([ScannedItem(name: "Milch", quantity: 1, price: 1.29)]))

        await sut.scan(anyImage)

        XCTAssertEqual(sut.phase, .ready)
        XCTAssertEqual(sut.receipt?.items.count, 1)
    }

    func testFailedRecognitionKeepsTheReason() async {
        let sut = failingModel(ReceiptRecognizerError.noTextFound)

        await sut.scan(anyImage)

        guard case .failed(let message) = sut.phase else {
            return XCTFail("erwartet wurde .failed, war \(sut.phase)")
        }
        XCTAssertFalse(message.isEmpty, "der Nutzer braucht einen Grund, keinen leeren Hinweis")
        XCTAssertNil(sut.receipt)
    }

    func testEmptyReceiptCountsAsFailure() async {
        // Ein Bon ohne Positionen und ohne Summe ist kein Ergebnis, auch wenn
        // die Erkennung technisch nicht geworfen hat.
        let sut = model(returning: receipt([]))

        await sut.scan(anyImage)

        guard case .failed = sut.phase else {
            return XCTFail("ein leerer Bon darf nicht als Ergebnis durchgehen")
        }
    }

    func testResetGoesBackToTheStart() async {
        let sut = model(returning: receipt([ScannedItem(name: "Milch", quantity: 1, price: 1.29)]))
        await sut.scan(anyImage)

        sut.reset()

        XCTAssertEqual(sut.phase, .idle)
        XCTAssertNil(sut.receipt)
    }

    // MARK: - Zuordnung

    func testTappingAssignsAndTappingAgainReleases() async throws {
        let sut = model(returning: receipt([ScannedItem(name: "Shampoo", quantity: 1, price: 7.40)]))
        await sut.scan(anyImage)
        let item = try XCTUnwrap(sut.receipt?.items.first)

        sut.toggle(ben, on: item)
        XCTAssertTrue(sut.isAssigned(ben, to: try XCTUnwrap(sut.receipt?.items.first)))

        sut.toggle(ben, on: try XCTUnwrap(sut.receipt?.items.first))
        XCTAssertFalse(sut.isAssigned(ben, to: try XCTUnwrap(sut.receipt?.items.first)))
    }

    func testAnItemNobodyClaimedIsShared() async throws {
        let sut = model(returning: receipt([ScannedItem(name: "Milch", quantity: 1, price: 1.29)]))
        await sut.scan(anyImage)

        XCTAssertTrue(sut.isShared(try XCTUnwrap(sut.receipt?.items.first)))
    }

    func testReleasingTheLastPersonSharesAgain() async throws {
        // Der Rueckweg muss ohne eigenen Griff gehen: Wer alle wieder abwaehlt,
        // landet beim haeufigsten Fall.
        let sut = model(returning: receipt([ScannedItem(name: "Wein", quantity: 1, price: 8.99)]))
        await sut.scan(anyImage)
        sut.toggle(anna, on: try XCTUnwrap(sut.receipt?.items.first))
        sut.toggle(anna, on: try XCTUnwrap(sut.receipt?.items.first))

        XCTAssertTrue(sut.isShared(try XCTUnwrap(sut.receipt?.items.first)))
    }

    func testRemovingAnInventedLineDropsIt() async throws {
        let sut = model(returning: receipt([ScannedItem(name: "Milch", quantity: 1, price: 1.29),
                                            ScannedItem(name: "ZWISCHENSUMME", quantity: 1, price: 3.78)]))
        await sut.scan(anyImage)
        let wrong = try XCTUnwrap(sut.receipt?.items.last)

        sut.remove(wrong)

        XCTAssertEqual(sut.receipt?.items.count, 1)
        XCTAssertEqual(sut.receipt?.items.first?.name, "Milch")
    }

    // MARK: - Teilnehmer

    func testDeactivatedMembersAreNotOffered() {
        let sut = model(returning: receipt([]), participants: [anna, ben, gone])

        XCTAssertEqual(sut.participants.map(\.id), [anna.id, ben.id],
                       "wer das Projekt verlassen hat, taucht in der Zuordnung nicht auf")
    }

    // MARK: - Ergebnis

    func testAssignmentShowsUpInTheBills() async throws {
        let sut = model(returning: receipt([ScannedItem(name: "Milch", quantity: 1, price: 1.29),
                                            ScannedItem(name: "Shampoo", quantity: 1, price: 7.40)]))
        await sut.scan(anyImage)
        sut.toggle(ben, on: try XCTUnwrap(sut.receipt?.items.last))

        XCTAssertEqual(sut.drafts.count, 2)
        XCTAssertEqual(sut.drafts.first { $0.owerIDs == [ben.id] }?.amount, 7.40)
        XCTAssertTrue(sut.canCreateBills)
    }

    func testWithoutAScanThereIsNothingToCreate() {
        let sut = model(returning: receipt([]))

        XCTAssertTrue(sut.drafts.isEmpty)
        XCTAssertFalse(sut.canCreateBills)
        XCTAssertEqual(sut.unaccounted, 0, accuracy: 0.001)
    }

    func testMissingLineIsCarriedThrough() async {
        let sut = model(returning: receipt([ScannedItem(name: "Milch", quantity: 1, price: 4.00)],
                                           total: 6.00))
        await sut.scan(anyImage)

        XCTAssertEqual(sut.unaccounted, 2.00, accuracy: 0.001)
    }
}
