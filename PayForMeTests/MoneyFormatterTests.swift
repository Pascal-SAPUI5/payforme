//
//  MoneyFormatterTests.swift
//  PayForMeTests
//
//  These assert *structure* — sign, decimal count, which minus character —
//  rather than exact separators, because grouping and decimal characters
//  legitimately differ between the locales the app ships in. Asserting
//  "1.234,50" would just make the suite fail on an English machine.
//

import XCTest
@testable import PayForMe

final class MoneyFormatterTests: XCTestCase {

    func testAlwaysTwoDecimals() {
        XCTAssertTrue(MoneyFormatter.plain(5).hasSuffix("00"), "got \(MoneyFormatter.plain(5))")
        XCTAssertTrue(MoneyFormatter.plain(5.5).hasSuffix("50"), "got \(MoneyFormatter.plain(5.5))")
        XCTAssertTrue(MoneyFormatter.plain(5.499).hasSuffix("50"),
                      "rounds to two places, got \(MoneyFormatter.plain(5.499))")
        XCTAssertTrue(MoneyFormatter.plain(5.991).hasSuffix("99"),
                      "rounds down, got \(MoneyFormatter.plain(5.991))")
    }

    /// The whole point of the change: the output must not be the C-locale form.
    func testUsesLocaleSeparators() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        XCTAssertEqual(MoneyFormatter.plain(1234.5),
                       formatter.string(from: NSNumber(value: 1234.5)))
    }

    func testSignedPrefixes() {
        XCTAssertTrue(MoneyFormatter.signed(12.5).hasPrefix("+"))
        XCTAssertTrue(MoneyFormatter.signed(-12.5).hasPrefix("\u{2212}"),
                      "balances use U+2212 MINUS SIGN, which is digit-width")
        XCTAssertFalse(MoneyFormatter.signed(-12.5).contains("-"),
                       "an ASCII hyphen would break column alignment")
    }

    /// A settled balance is neither good news nor bad news.
    func testSignedZeroCarriesNoSign() {
        let zero = MoneyFormatter.signed(0)
        XCTAssertFalse(zero.hasPrefix("+"))
        XCTAssertFalse(zero.hasPrefix("\u{2212}"))
    }

    /// Floating-point balances rarely land on exactly zero; sub-cent noise must
    /// not be presented as a debt.
    func testSubCentNoiseIsUnsigned() {
        XCTAssertFalse(MoneyFormatter.signed(0.004).hasPrefix("+"))
        XCTAssertFalse(MoneyFormatter.signed(-0.004).hasPrefix("\u{2212}"))
    }

    func testDisplayDateIsNotTheWireFormat() {
        let date = DateFormatter.cospend.date(from: "2026-05-14")!
        XCTAssertEqual(DateFormatter.cospend.string(from: date), "2026-05-14",
                       "the wire format must not change — both backends parse it")
        XCTAssertNotEqual(DateFormatter.cospendDisplay.string(from: date), "2026-05-14",
                          "the bill list must not show users the ISO wire format")
    }
}
