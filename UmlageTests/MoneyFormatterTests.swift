//
//  MoneyFormatterTests.swift
//  UmlageTests
//
//  These assert *structure* (sign, suffix, presence of the currency) rather than
//  exact separators, because grouping and decimal characters legitimately differ
//  between the locales the app ships in.
//

import XCTest
@testable import Umlage

final class MoneyFormatterTests: XCTestCase {

    func testPlainAlwaysHasTwoDecimals() {
        XCTAssertTrue(MoneyFormatter.plain(5).hasSuffix("00"), "got \(MoneyFormatter.plain(5))")
        XCTAssertTrue(MoneyFormatter.plain(5.5).hasSuffix("50"), "got \(MoneyFormatter.plain(5.5))")
        XCTAssertTrue(MoneyFormatter.plain(5.499).hasSuffix("50"),
                      "rounds up, got \(MoneyFormatter.plain(5.499))")
        XCTAssertTrue(MoneyFormatter.plain(5.991).hasSuffix("99"),
                      "rounds down, got \(MoneyFormatter.plain(5.991))")
    }

    func testCurrencyAppendedOnlyWhenKnown() {
        XCTAssertTrue(MoneyFormatter.string(5, currency: "\u{20AC}").hasSuffix("\u{20AC}"))
        XCTAssertFalse(MoneyFormatter.string(5, currency: nil).contains("\u{20AC}"))
        // An empty or whitespace-only currency is treated as "unknown", not as a
        // suffix made of spaces.
        XCTAssertEqual(MoneyFormatter.string(5, currency: ""), MoneyFormatter.string(5, currency: nil))
        XCTAssertEqual(MoneyFormatter.string(5, currency: "   "), MoneyFormatter.string(5, currency: nil))
    }

    func testSignedUsesRealMinusSign() {
        XCTAssertTrue(MoneyFormatter.signed(12.5).hasPrefix("+"))
        XCTAssertTrue(MoneyFormatter.signed(-12.5).hasPrefix("\u{2212}"),
                      "balances use U+2212, not a hyphen")
        XCTAssertFalse(MoneyFormatter.signed(-12.5).contains("-"))
    }

    /// A settled balance is neither good news nor bad news, so it carries no sign.
    func testSignedZeroHasNoSign() {
        let zero = MoneyFormatter.signed(0)
        XCTAssertFalse(zero.hasPrefix("+"))
        XCTAssertFalse(zero.hasPrefix("\u{2212}"))
    }

    func testAbbreviatedScales() {
        XCTAssertTrue(MoneyFormatter.abbreviated(1500).hasSuffix("k"))
        XCTAssertTrue(MoneyFormatter.abbreviated(15000).hasSuffix("k"))
        XCTAssertTrue(MoneyFormatter.abbreviated(1_500_000).hasSuffix("M"))
        XCTAssertFalse(MoneyFormatter.abbreviated(999).hasSuffix("k"))
        XCTAssertTrue(MoneyFormatter.abbreviated(-1500).hasPrefix("\u{2212}"))
    }

    func testPercentIsClamped() {
        XCTAssertTrue(MoneyFormatter.percent(0.5).contains("50"))
        XCTAssertTrue(MoneyFormatter.percent(1.4).contains("100"), "fractions above 1 are clamped")
        XCTAssertTrue(MoneyFormatter.percent(-0.2).contains("0"), "negative fractions are clamped")
    }

    func testAvatarInitials() {
        XCTAssertEqual(PFMAvatar.initials(for: "Anna Lee"), "AL")
        XCTAssertEqual(PFMAvatar.initials(for: "pikachu"), "PI")
        XCTAssertEqual(PFMAvatar.initials(for: "jean-luc"), "JL")
        XCTAssertEqual(PFMAvatar.initials(for: ""), "?")
        XCTAssertEqual(PFMAvatar.initials(for: "   "), "?")
    }
}
