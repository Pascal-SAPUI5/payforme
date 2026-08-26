//
//  LocalizationTests.swift
//  DividoTests
//
//  A missing key does not crash — `NSLocalizedString` quietly returns the key
//  itself, so the screen ships reading "stats_settle_up_subtitle". That is
//  exactly the kind of bug nobody notices until a user in that language files
//  it, which is why it is asserted here instead.
//

import XCTest
@testable import Divido

final class LocalizationTests: XCTestCase {

    /// Every language the app claims to support.
    private let languages = ["en", "de", "fr", "es", "cs", "ru"]

    /// Keys introduced by the redesign. Enum-derived keys are pulled from the
    /// types themselves so adding a case without a string fails here too.
    private var requiredKeys: [String] {
        var keys = [
            "Statistics",
            "stats_total_spent", "stats_empty_title", "stats_empty_message",
            "stats_bills", "stats_average_bill", "stats_per_member", "stats_top_payer",
            "stats_balances", "stats_balances_subtitle",
            "stats_settle_up", "stats_settle_up_subtitle", "stats_all_settled",
            "stats_pays %@", "stats_monthly", "stats_peak_label %@ %@",
            "stats_who_paid", "stats_who_paid_subtitle",
            "stats_categories", "stats_uncategorized", "stats_other_categories",
            "stats_largest_bills", "stats_untitled_bill",
            "bill_share_each %@",
            "bills_total", "bills_empty_title", "bills_empty_message",
            "balances_outstanding", "balances_outstanding_hint",
            "balance_is_owed", "balance_owes", "balance_settled",
            "appearance_title", "appearance_row_subtitle",
            "appearance_mode", "appearance_mode_subtitle",
            "appearance_theme", "appearance_theme_subtitle",
            "onboarding_what_is_this", "onboarding_hide_info",
            "Unknown",
            "scan_title", "scan_empty_title", "scan_empty_message",
            "scan_start_camera", "scan_choose_photo", "scan_recognizing",
            "scan_failed_title", "scan_failed_message", "scan_retry",
            "scan_items", "scan_assign_hint", "scan_shared", "scan_remove_item",
            "scan_unaccounted %@", "scan_bills_preview %lld", "scan_create_bills",
            "scan_total",
        ]
        keys += PFMAppearance.allCases.map { $0.localizationKey }
        keys += PFMThemeID.allCases.map { $0.localizationKey }
        keys += PFMThemeID.allCases.map { $0.subtitleKey }
        keys += StatisticsRange.allCases.map { $0.localizationKey }
        return keys
    }

    /// Parses a `.strings` file into a dictionary. `PropertyListSerialization`
    /// reads the legacy format the app ships, which keeps this independent of
    /// however the bundle happens to be built.
    private func strings(for language: String) throws -> [String: String] {
        let bundle = Bundle(for: LocalizationTests.self)
        guard let url = bundle.url(forResource: "Localizable", withExtension: "strings",
                                   subdirectory: nil, localization: language)
                ?? Bundle(for: ProjectManager.self).url(forResource: "Localizable",
                                                        withExtension: "strings",
                                                        subdirectory: nil,
                                                        localization: language) else {
            throw XCTSkip("No Localizable.strings bundled for '\(language)' in the test host")
        }
        let data = try Data(contentsOf: url)
        let parsed = try PropertyListSerialization.propertyList(from: data, format: nil)
        return parsed as? [String: String] ?? [:]
    }

    func testEveryLanguageDefinesEveryKey() throws {
        for language in languages {
            let table = try strings(for: language)
            let missing = requiredKeys.filter { table[$0] == nil }.sorted()
            XCTAssertTrue(missing.isEmpty,
                          "\(language) is missing \(missing.count) key(s): \(missing.joined(separator: ", "))")
        }
    }

    func testNoTranslationIsEmpty() throws {
        for language in languages {
            let table = try strings(for: language)
            for key in requiredKeys {
                guard let value = table[key] else { continue }
                XCTAssertFalse(value.trimmingCharacters(in: .whitespaces).isEmpty,
                               "\(language): '\(key)' is present but empty")
            }
        }
    }

    /// A translation that drops a `%@` renders a sentence with a hole in it; one
    /// that adds an extra placeholder can crash `String(format:)`.
    func testFormatPlaceholdersSurviveTranslation() throws {
        let placeholderKeys = ["stats_pays %@", "bill_share_each %@", "stats_peak_label %@ %@"]

        for language in languages {
            let table = try strings(for: language)
            for key in placeholderKeys {
                guard let value = table[key] else { continue }
                let expected = key.components(separatedBy: "%@").count - 1
                // Both `%@` and the positional `%1$@` form count as one slot.
                let plain = value.components(separatedBy: "%@").count - 1
                let positional = value.components(separatedBy: "$@").count - 1
                XCTAssertEqual(max(plain, positional), expected,
                               "\(language): '\(key)' has \(max(plain, positional)) placeholder(s), expected \(expected) — got \"\(value)\"")
            }
        }
    }

    /// `member_error_generic` takes an integer, not a string; mixing the two up
    /// is a crash rather than a cosmetic bug.
    func testIntegerPlaceholderIsPreserved() throws {
        for language in languages {
            let table = try strings(for: language)
            guard let value = table["member_error_generic"] else { continue }
            XCTAssertTrue(value.contains("%d"),
                          "\(language): member_error_generic must keep its %d placeholder")
        }
    }
}
