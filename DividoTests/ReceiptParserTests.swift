//
//  ReceiptParserTests.swift
//  DividoTests
//
//  Die Erkennung selbst braucht ein Gerät — Vision und Foundation Models laufen
//  nicht im Simulator-Test. Das Parsen der Modellantwort dagegen ist reine
//  Logik, und dort sitzen die Fehler: Komma statt Punkt, deutsche Daten,
//  Antworten die mitten in der Positionsliste abbrechen.
//
//  Die Beispiele unten sind echte Antwortformen, keine erfundenen.
//

import XCTest
@testable import Divido

final class ReceiptParserTests: XCTestCase {

    private var referenceDate: Date {
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 26
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    private func day(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // MARK: Preise

    func testPriceAcceptsBothDecimalSeparators() {
        XCTAssertEqual(ReceiptParser.price(from: "1.29"), 1.29)
        XCTAssertEqual(ReceiptParser.price(from: "1,29"), 1.29, "deutsche Bons schreiben Komma")
        XCTAssertEqual(ReceiptParser.price(from: 2.5), 2.5)
        XCTAssertEqual(ReceiptParser.price(from: "3,00 €"), 3.0, "Währungszeichen kommen vor")
    }

    func testPriceRejectsNonPositions() {
        XCTAssertNil(ReceiptParser.price(from: "0,00"), "Nullzeilen sind keine Position")
        XCTAssertNil(ReceiptParser.price(from: "-1,50"), "Rabattzeilen sind keine Position")
        XCTAssertNil(ReceiptParser.price(from: nil))
        XCTAssertNil(ReceiptParser.price(from: "keine Zahl"))
    }

    // MARK: Datum

    func testDateAcceptsIsoAndGermanFormats() {
        XCTAssertEqual(day(ReceiptParser.date(from: "2026-08-16")), "2026-08-16")
        XCTAssertEqual(day(ReceiptParser.date(from: "16.08.2026")), "2026-08-16")
        XCTAssertEqual(day(ReceiptParser.date(from: "16.08.26")), "2026-08-16")
        XCTAssertEqual(day(ReceiptParser.date(from: "16/08/2026")), "2026-08-16")
    }

    func testTimeAfterTheDateIsIgnored() {
        // Manche Modelle haengen die Uhrzeit an, obwohl der Prompt nur nach dem
        // Tag fragt. Der Tag davor bleibt lesbar.
        XCTAssertEqual(day(ReceiptParser.date(from: "2026-08-16T10:22:00")), "2026-08-16")
    }

    func testTwoDigitYearIsNotMistakenForAFullYear() {
        // Der Fehler, den dieser Test festhaelt: Ein DateFormatter mit
        // "yyyy-MM-dd" nimmt auch "16.08.26" an und macht daraus das Jahr 16.
        XCTAssertNotEqual(day(ReceiptParser.date(from: "16.08.26")), "0016-08-26")
    }

    func testDateFallsBackWhenUnreadable() {
        XCTAssertEqual(day(ReceiptParser.date(from: "gestern", fallback: referenceDate)),
                       "2026-08-26",
                       "lieber das heutige Datum als gar keine Rechnung")
    }

    // MARK: Vollständige Antwort

    func testParsesACleanAnswer() throws {
        let answer = """
        {"retailer":"REWE","date":"2026-08-26","total":12.47,
         "items":[{"name":"Milch","quantity":2,"price":1.29},
                  {"name":"Brot","quantity":1,"price":2.49},
                  {"name":"Shampoo","quantity":1,"price":7.40}]}
        """
        let receipt = try XCTUnwrap(ReceiptParser.parse(answer, now: referenceDate))
        XCTAssertEqual(receipt.retailer, "REWE")
        XCTAssertEqual(day(receipt.date), "2026-08-26")
        XCTAssertEqual(receipt.total, 12.47)
        XCTAssertEqual(receipt.items.count, 3)
        XCTAssertEqual(receipt.items[0].quantity, 2)
    }

    /// Modelle stellen gern einen Satz voran, obwohl der Prompt es verbietet.
    func testIgnoresTextAroundTheJson() throws {
        let answer = """
        Gerne! Hier sind die erkannten Daten:
        {"retailer":"ALDI","date":"16.08.2026","total":"5,98","items":[{"name":"Eier","quantity":1,"price":"2,99"}]}
        Ich hoffe, das hilft.
        """
        let receipt = try XCTUnwrap(ReceiptParser.parse(answer, now: referenceDate))
        XCTAssertEqual(receipt.retailer, "ALDI")
        XCTAssertEqual(receipt.total, 5.98)
        XCTAssertEqual(receipt.items.first?.price, 2.99)
    }

    // MARK: Abgeschnittene Antwort

    /// Der häufigste Fehlerfall bei einem Wocheneinkauf: Die Antwort läuft ins
    /// Token-Limit und bricht mitten in der Positionsliste ab. Was schon
    /// gelesen wurde, ist trotzdem brauchbar.
    func testSalvagesATruncatedAnswer() throws {
        let answer = """
        {"retailer":"EDEKA","date":"2026-08-26","total":31.90,"items":[
         {"name":"Kaffee","quantity":1,"price":8.99},
         {"name":"Butter","quantity":2,"price":2.29},
         {"name":"Nudel
        """
        let receipt = try XCTUnwrap(ReceiptParser.parse(answer, now: referenceDate))
        XCTAssertEqual(receipt.retailer, "EDEKA", "die Kopfdaten stehen vorne und sind lesbar")
        XCTAssertEqual(receipt.total, 31.90)
        XCTAssertEqual(receipt.items.count, 2, "die beiden vollständigen Positionen bleiben erhalten")
    }

    func testReturnsNilWhenNothingIsReadable() {
        XCTAssertNil(ReceiptParser.parse("Ich kann auf diesem Bild keinen Bon erkennen.", now: referenceDate))
        XCTAssertNil(ReceiptParser.parse("", now: referenceDate))
    }

    // MARK: Plausibilität

    func testSumMatchesTotalWithinRounding() {
        let receipt = ScannedReceipt(
            retailer: "REWE", date: referenceDate, total: 5.07,
            items: [ScannedItem(name: "Milch", quantity: 2, price: 1.29),
                    ScannedItem(name: "Brot", quantity: 1, price: 2.49)]
        )
        XCTAssertEqual(receipt.sumOfItems, 5.07, accuracy: 0.001)
        XCTAssertTrue(receipt.matchesTotal)
    }

    /// Wenn eine Zeile fehlt, muss das sichtbar werden statt still zu stimmen.
    func testMismatchIsReportedWhenALineIsMissing() {
        let receipt = ScannedReceipt(
            retailer: "REWE", date: referenceDate, total: 12.47,
            items: [ScannedItem(name: "Milch", quantity: 1, price: 1.29)]
        )
        XCTAssertFalse(receipt.matchesTotal)
        XCTAssertEqual(receipt.effectiveTotal, 12.47,
                       "der abgelesene Gesamtbetrag zählt, nicht die unvollständige Summe")
    }

    func testFallsBackToItemSumWithoutATotal() {
        let receipt = ScannedReceipt(
            retailer: nil, date: referenceDate, total: nil,
            items: [ScannedItem(name: "Kaffee", quantity: 1, price: 8.99)]
        )
        XCTAssertEqual(receipt.effectiveTotal, 8.99)
        XCTAssertFalse(receipt.matchesTotal, "ohne Gesamtbetrag gibt es nichts zu bestätigen")
    }

    // MARK: - Menge

    // Diese vier Faelle decken den Zweig ab, in dem die Menge keine ganze Zahl
    // ist. Genau dort steckte ein Fehler, den kein Test bemerkt hat, weil alle
    // Beispiele die Menge als Zahl geliefert haben.

    func testQuantityGivenAsStringIsRead() {
        let json = #"{"retailer":"REWE","date":"2026-08-16","total":2.58,"items":[{"name":"Milch","quantity":"2","price":1.29}]}"#

        let receipt = ReceiptParser.parse(json, now: referenceDate)

        XCTAssertEqual(receipt?.items.first?.quantity, 2)
    }

    func testMissingQuantityCountsAsOne() {
        let json = #"{"retailer":"REWE","date":"2026-08-16","total":1.29,"items":[{"name":"Milch","price":1.29}]}"#

        let receipt = ReceiptParser.parse(json, now: referenceDate)

        XCTAssertEqual(receipt?.items.first?.quantity, 1)
    }

    func testZeroQuantityCountsAsOne() {
        // Eine Position mit Menge null gibt es auf einem Bon nicht. Wer sie
        // durchlaesst, bekommt eine Rechnung, in der der Artikel nichts kostet.
        let json = #"{"retailer":"REWE","date":"2026-08-16","total":1.29,"items":[{"name":"Milch","quantity":0,"price":1.29}]}"#

        let receipt = ReceiptParser.parse(json, now: referenceDate)

        XCTAssertEqual(receipt?.items.first?.quantity, 1)
    }

    func testWeighedGoodsCountAsOnePosition() {
        // Obst wird nach Gewicht abgerechnet, das Modell schreibt dann 0.384.
        // Der Preis auf dem Bon gilt bereits fuer diese Menge, die Position
        // darf also nicht mit null multipliziert werden.
        let json = #"{"retailer":"REWE","date":"2026-08-16","total":0.92,"items":[{"name":"Bananen","quantity":0.384,"price":0.92}]}"#

        let receipt = ReceiptParser.parse(json, now: referenceDate)

        XCTAssertEqual(receipt?.items.first?.quantity, 1)
        XCTAssertEqual(receipt?.sumOfItems ?? 0, 0.92, accuracy: 0.001)
    }
}
