//
//  MoneyFormatter.swift
//  Divido
//
//  Amounts used to be rendered with `String(format: "%.2f", …)`, which prints
//  "1234.50" to every user on earth regardless of locale. This formats with the
//  user's own grouping and decimal separators ("1.234,50" in de-DE) and appends
//  the project's currency only when the server actually told us what it is.
//
//  Pure Foundation, so it is unit-testable without a simulator.
//

import Foundation

enum MoneyFormatter {

    /// Cached because `NumberFormatter` construction is expensive and these are
    /// built once per cell in long lists.
    private static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let compact: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let oneDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    /// "1.234,50" — always two decimals, no currency.
    ///
    /// The value is rounded before formatting rather than left to
    /// `maximumFractionDigits`: swift-corelibs-foundation stops honouring that
    /// property once `minimumFractionDigits` is set, so relying on it makes the
    /// output differ between Apple platforms and Linux and untestable off-device.
    static func plain(_ amount: Double) -> String {
        let rounded = (amount * 100).rounded() / 100
        return decimal.string(from: NSNumber(value: rounded)) ?? String(format: "%.2f", rounded)
    }

    /// "1.234,50 €". `currency` is whatever Cospend reports; when it is nil or
    /// empty we fall back to the bare number rather than guessing a symbol from
    /// the device locale, which would be wrong for anyone splitting costs abroad.
    static func string(_ amount: Double, currency: String?) -> String {
        let number = plain(amount)
        guard let currency = currency?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currency.isEmpty else { return number }
        return "\(number) \(currency)"
    }

    /// Signed, for balances: "+12,50" / "−12,50". Uses U+2212 MINUS SIGN, which
    /// lines up with digits far better than a hyphen at large point sizes.
    static func signed(_ amount: Double, currency: String? = nil) -> String {
        let magnitude = string(abs(amount), currency: currency)
        if amount > 0.005 { return "+" + magnitude }
        if amount < -0.005 { return "\u{2212}" + magnitude }
        return magnitude
    }

    /// Space-constrained rendering for chart axes and stat tiles:
    /// 1.234 → "1,2k", 1.234.567 → "1,2M".
    static func abbreviated(_ amount: Double, currency: String? = nil) -> String {
        let magnitude = abs(amount)
        let sign = amount < 0 ? "\u{2212}" : ""

        let body: String
        switch magnitude {
        case 1_000_000...:
            body = (oneDecimal.string(from: NSNumber(value: magnitude / 1_000_000)) ?? "") + "M"
        case 10_000...:
            body = (compact.string(from: NSNumber(value: magnitude / 1_000)) ?? "") + "k"
        case 1_000...:
            body = (oneDecimal.string(from: NSNumber(value: magnitude / 1_000)) ?? "") + "k"
        default:
            body = compact.string(from: NSNumber(value: magnitude.rounded())) ?? "0"
        }

        guard let currency = currency?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currency.isEmpty else { return sign + body }
        return "\(sign)\(body) \(currency)"
    }

    /// "48 %" for donut legends and share bars.
    static func percent(_ fraction: Double) -> String {
        let clamped = max(0, min(1, fraction))
        let value = (clamped * 100).rounded()
        return (compact.string(from: NSNumber(value: value)) ?? "0") + "\u{00A0}%"
    }
}
