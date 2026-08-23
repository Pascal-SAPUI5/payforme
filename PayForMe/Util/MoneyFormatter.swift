//
//  MoneyFormatter.swift
//  PayForMe
//
//  Amounts were rendered with `String(format: "%.2f", …)`, which prints
//  "1234.50" to every user regardless of locale. A German user splitting a
//  holiday house sees a thousands separator where they expect a decimal comma,
//  which is exactly the kind of number people misread.
//
//  Pure Foundation, so it is unit-testable without a simulator.
//

import Foundation

enum MoneyFormatter {

    /// Cached: `NumberFormatter` construction is expensive and these are built
    /// once per row in a long bill list.
    private static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// "1.234,50" in de-DE, "1,234.50" in en-US. Always two decimals.
    ///
    /// The value is rounded before formatting rather than left to
    /// `maximumFractionDigits`: swift-corelibs-foundation stops honouring that
    /// property once `minimumFractionDigits` is set, so relying on it makes the
    /// output differ between Apple platforms and Linux. Rounding here keeps the
    /// result identical everywhere and testable off-device.
    static func plain(_ amount: Double) -> String {
        let rounded = (amount * 100).rounded() / 100
        return decimal.string(from: NSNumber(value: rounded)) ?? String(format: "%.2f", rounded)
    }

    /// Signed, for balances. Uses U+2212 MINUS SIGN rather than a hyphen: it is
    /// the same width as a digit, so a column of balances stays aligned.
    static func signed(_ amount: Double) -> String {
        let magnitude = plain(abs(amount))
        if amount > 0.005 { return "+" + magnitude }
        if amount < -0.005 { return "\u{2212}" + magnitude }
        // A settled balance is neither good news nor bad news, so it gets no sign.
        return magnitude
    }
}
