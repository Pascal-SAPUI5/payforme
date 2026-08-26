//
//  ReceiptTotalsTests.swift
//  DividoTests
//
//  Prueft die Suche nach dem Endbetrag an den Formen, die deutsche
//  Kassenzettel tatsaechlich verwenden.
//

import XCTest
@testable import Divido

final class ReceiptTotalsTests: XCTestCase {

    // MARK: - Die gaengigen Auszeichnungen

    func testSumme() {
        XCTAssertEqual(ReceiptTotals.total(in: ["Milch 1,29", "SUMME 31,90"]), 31.90)
    }

    func testGesamtbetrag() {
        XCTAssertEqual(ReceiptTotals.total(in: ["GESAMTBETRAG 12,34"]), 12.34)
    }

    func testZuZahlen() {
        XCTAssertEqual(ReceiptTotals.total(in: ["ZU ZAHLEN 8,50"]), 8.50)
    }

    func testTotal() {
        XCTAssertEqual(ReceiptTotals.total(in: ["TOTAL 5,00"]), 5.00)
    }

    func testCurrencyBetweenLabelAndAmount() {
        XCTAssertEqual(ReceiptTotals.total(in: ["SUMME EUR 31,90"]), 31.90)
    }

    func testLowercaseStillCounts() {
        XCTAssertEqual(ReceiptTotals.total(in: ["Gesamtbetrag 99,99"]), 99.99)
    }

    // MARK: - Die Fallen

    func testSubtotalDoesNotWin() {
        // ZWISCHENSUMME enthaelt SUMME. Wer nur auf das Schluesselwort schaut,
        // teilt den halben Einkauf.
        XCTAssertNil(ReceiptTotals.total(in: ["ZWISCHENSUMME 20,00"]))
    }

    func testSubtotalAboveTheRealTotalIsIgnored() {
        let lines = ["ZWISCHENSUMME 20,00", "Pfand 0,25", "SUMME 20,25"]

        XCTAssertEqual(ReceiptTotals.total(in: lines), 20.25)
    }

    func testChangeGivenDoesNotWin() {
        // Der gefaehrlichste Fall: Unter dem Endbetrag stehen die Zahlungszeilen,
        // und die Suche laeuft von unten. Gegeben und Rueckgeld sind fast immer
        // groesser oder kleiner als der Betrag, den man teilen will.
        let lines = ["SUMME 31,90", "GEGEBEN 50,00", "RÜCKGELD 18,10"]

        XCTAssertEqual(ReceiptTotals.total(in: lines), 31.90)
    }

    func testTaxLinesAreNotTotals() {
        XCTAssertNil(ReceiptTotals.total(in: ["MWST 19% 5,10", "Netto 26,80"]))
    }

    func testDepositLineIsNotATotal() {
        XCTAssertNil(ReceiptTotals.total(in: ["PFAND GESAMT 0,75"]))
    }

    func testTaxRateOnTheTotalLineIsNotMistakenForTheAmount() {
        // "SUMME 19% 31,90" — die Zahl links ist der Steuersatz, der Betrag
        // steht rechts.
        XCTAssertEqual(ReceiptTotals.total(in: ["SUMME 19,00% 31,90"]), 31.90)
    }

    // MARK: - Betragsformen

    func testThousandsSeparator() {
        // Stur jedes Komma zum Punkt zu machen ergaebe "1.234.56" und damit
        // keine Zahl mehr.
        XCTAssertEqual(ReceiptTotals.amount(from: "1.234,56"), 1234.56)
    }

    func testEnglishThousandsSeparator() {
        XCTAssertEqual(ReceiptTotals.amount(from: "1,234.56"), 1234.56)
    }

    func testPlainAmount() {
        XCTAssertEqual(ReceiptTotals.amount(from: "31,90"), 31.90)
    }

    func testLargeAmountWithoutSeparator() {
        XCTAssertEqual(ReceiptTotals.amount(from: "12345,67"), 12345.67)
    }

    func testZeroIsNotAnAmount() {
        XCTAssertNil(ReceiptTotals.amount(from: "0,00"))
    }

    func testThousandsAmountIsFoundInALine() {
        XCTAssertEqual(ReceiptTotals.total(in: ["SUMME 1.234,56"]), 1234.56)
    }

    // MARK: - Nichts gefunden

    func testReceiptWithoutATotalLine() {
        XCTAssertNil(ReceiptTotals.total(in: ["REWE Markt", "Milch 1,29", "Brot 2,49"]))
    }

    func testEmptyInput() {
        XCTAssertNil(ReceiptTotals.total(in: []))
    }

    func testMarkerWithoutAnAmount() {
        XCTAssertNil(ReceiptTotals.total(in: ["SUMME"]))
    }

    // MARK: - Wenn Modell und Text sich uneinig sind

    func testTextFillsInWhatTheModelMissed() {
        XCTAssertEqual(ReceiptTotals.preferred(model: nil, fromText: 31.90, sumOfItems: 31.90), 31.90)
    }

    func testModelWinsWhenTheTextFoundNothing() {
        XCTAssertEqual(ReceiptTotals.preferred(model: 31.90, fromText: nil, sumOfItems: 31.90), 31.90)
    }

    func testTheOneThatMatchesTheItemsWins() {
        // Das Modell hat die Zwischensumme erwischt, die Suche den Endbetrag.
        // Die Summe der Positionen entscheidet.
        XCTAssertEqual(ReceiptTotals.preferred(model: 20.00, fromText: 31.90, sumOfItems: 31.90), 31.90)
    }

    func testModelKeepsThePointWhenItMatches() {
        XCTAssertEqual(ReceiptTotals.preferred(model: 31.90, fromText: 20.00, sumOfItems: 31.90), 31.90)
    }

    func testModelStaysWhenNeitherMatches() {
        // Eine verschluckte Zeile heisst nicht, dass die Suche recht hat. Das
        // Modell hat den ganzen Zettel gesehen, die Suche nur die Zeilen mit
        // Schluesselwort.
        XCTAssertEqual(ReceiptTotals.preferred(model: 31.90, fromText: 25.00, sumOfItems: 10.00), 31.90)
    }

    func testNothingAtAllStaysNothing() {
        XCTAssertNil(ReceiptTotals.preferred(model: nil, fromText: nil, sumOfItems: 0))
    }
}
