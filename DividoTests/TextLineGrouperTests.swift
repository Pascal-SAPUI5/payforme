//
//  TextLineGrouperTests.swift
//  DividoTests
//
//  Prueft das Zusammensetzen der Zeilen an den Geometrien, die eine
//  Texterkennung auf einem Kassenbon tatsaechlich liefert.
//

import XCTest
@testable import Divido

final class TextLineGrouperTests: XCTestCase {

    /// Baut ein Bruchstueck mit der Zeilenhoehe, die eine Bonzeile im Foto hat.
    private func fragment(_ text: String, y: Double, x: Double, height: Double = 0.02) -> TextFragment {
        TextFragment(text: text, midY: y, minX: x, height: height)
    }

    // MARK: - Der Kernfall

    func testNameAndPriceOfTheSameRowBecomeOneLine() {
        let lines = TextLineGrouper.lines(from: [
            fragment("Milch 3,5%", y: 0.800, x: 0.08),
            fragment("1,29", y: 0.799, x: 0.78)
        ])

        XCTAssertEqual(lines, ["Milch 3,5% 1,29"])
    }

    func testPriceComesAfterTheNameEvenIfVisionReportsItFirst() {
        let lines = TextLineGrouper.lines(from: [
            fragment("1,29", y: 0.800, x: 0.78),
            fragment("Milch 3,5%", y: 0.800, x: 0.08)
        ])

        XCTAssertEqual(lines, ["Milch 3,5% 1,29"])
    }

    func testRowsStayApart() {
        let lines = TextLineGrouper.lines(from: [
            fragment("Milch 3,5%", y: 0.800, x: 0.08),
            fragment("1,29", y: 0.800, x: 0.78),
            fragment("Brot", y: 0.760, x: 0.08),
            fragment("2,49", y: 0.760, x: 0.78)
        ])

        XCTAssertEqual(lines, ["Milch 3,5% 1,29", "Brot 2,49"])
    }

    // MARK: - Reihenfolge

    func testLinesAreOrderedTopToBottom() {
        // Vision liefert die Regionen nicht sortiert. Der Bon steht mit dem
        // Haendler oben und der Summe unten, und genau so muss der Text
        // beim Modell ankommen.
        let lines = TextLineGrouper.lines(from: [
            fragment("SUMME 3,78", y: 0.20, x: 0.08),
            fragment("REWE Markt", y: 0.95, x: 0.08),
            fragment("Brot 2,49", y: 0.60, x: 0.08)
        ])

        XCTAssertEqual(lines, ["REWE Markt", "Brot 2,49", "SUMME 3,78"])
    }

    // MARK: - Toleranz

    func testSlightlyTiltedReceiptStillGroupsCorrectly() {
        // Ein von Hand fotografierter Bon liegt nie exakt waagerecht. Ueber die
        // Breite einer Zeile darf die Mitte etwas wandern.
        let lines = TextLineGrouper.lines(from: [
            fragment("Bananen", y: 0.500, x: 0.08),
            fragment("1kg", y: 0.4955, x: 0.45),
            fragment("2,19", y: 0.491, x: 0.78)
        ])

        XCTAssertEqual(lines, ["Bananen 1kg 2,19"])
    }

    func testTightlySetRowsDoNotMerge() {
        // Der Abstand betraegt eine volle Texthoehe. Wuerde die Toleranz hier
        // greifen, verschmelzen auf einem eng gedruckten Bon alle Zeilen.
        let lines = TextLineGrouper.lines(from: [
            fragment("Kaese", y: 0.500, x: 0.08, height: 0.02),
            fragment("Wurst", y: 0.480, x: 0.08, height: 0.02)
        ])

        XCTAssertEqual(lines, ["Kaese", "Wurst"])
    }

    func testLineDoesNotDriftIntoTheNextOne() {
        // Vier Stuecke, jedes leicht tiefer als das vorige. Verglichen wird
        // gegen den Mittelwert der Zeile, nicht gegen ihr letztes Stueck,
        // sonst wandert die Gruppe mit und schluckt die naechste Zeile.
        let lines = TextLineGrouper.lines(from: [
            fragment("A", y: 0.5000, x: 0.10, height: 0.02),
            fragment("B", y: 0.4940, x: 0.20, height: 0.02),
            fragment("C", y: 0.4880, x: 0.30, height: 0.02),
            fragment("D", y: 0.4820, x: 0.40, height: 0.02),
            fragment("E", y: 0.4760, x: 0.50, height: 0.02)
        ])

        XCTAssertGreaterThan(lines.count, 1, "Die Gruppe ist ueber fuenf Stuecke mitgewandert")
    }

    // MARK: - Randfaelle

    func testEmptyInputGivesNoLines() {
        XCTAssertEqual(TextLineGrouper.lines(from: []), [])
    }

    func testBlankFragmentsAreDropped() {
        let lines = TextLineGrouper.lines(from: [
            fragment("Brot", y: 0.5, x: 0.08),
            fragment("   ", y: 0.5, x: 0.40),
            fragment("2,49", y: 0.5, x: 0.78)
        ])

        XCTAssertEqual(lines, ["Brot 2,49"])
    }

    func testWhitespaceAroundFragmentsIsTrimmed() {
        let lines = TextLineGrouper.lines(from: [
            fragment("  Brot ", y: 0.5, x: 0.08),
            fragment(" 2,49\n", y: 0.5, x: 0.78)
        ])

        XCTAssertEqual(lines, ["Brot 2,49"])
    }

    // MARK: - Zusammenspiel mit dem Parser

    func testGroupedTextIsWhatTheParserExpects() {
        // Der Grouper liefert genau die Form, die als Prompt beim Modell landet.
        let text = TextLineGrouper.text(from: [
            fragment("REWE", y: 0.95, x: 0.08),
            fragment("Milch", y: 0.80, x: 0.08),
            fragment("1,29", y: 0.80, x: 0.78),
            fragment("SUMME", y: 0.60, x: 0.08),
            fragment("1,29", y: 0.60, x: 0.78)
        ])

        XCTAssertEqual(text, "REWE\nMilch 1,29\nSUMME 1,29")
    }
}
