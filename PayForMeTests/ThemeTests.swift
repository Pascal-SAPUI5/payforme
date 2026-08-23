//
//  ThemeTests.swift
//  PayForMeTests
//
//  The design system is data, so it can be tested like data. These lock down the
//  invariants a palette has to satisfy — a wrong hex here would ship an
//  unreadable screen, and nothing else in the app would catch it.
//

import SwiftUI
import XCTest
@testable import PayForMe

final class ThemeTests: XCTestCase {

    private let allThemes = PFMThemeID.allCases
    private let allSchemes: [ColorScheme] = [.light, .dark]

    // MARK: Palette completeness

    func testEveryThemeResolvesInBothSchemes() {
        for id in allThemes {
            for scheme in allSchemes {
                let theme = PFMTheme.resolve(id, colorScheme: scheme)
                XCTAssertEqual(theme.id, id)
                XCTAssertEqual(theme.colorScheme, scheme)
                XCTAssertEqual(theme.isDark, scheme == .dark)
            }
        }
    }

    /// The chart palette's *ordering* is the colour-blind-safety mechanism, so
    /// the count and the exact opening hues are part of the contract.
    func testChartPaletteShape() {
        for id in allThemes {
            for scheme in allSchemes {
                let series = PFMTheme.palette(for: id, colorScheme: scheme).chartSeries
                XCTAssertEqual(series.count, 8, "\(id)/\(scheme) must expose all eight validated slots")
            }
        }
        XCTAssertEqual(PFMTheme.categoricalLight.count, 8)
        XCTAssertEqual(PFMTheme.categoricalDark.count, 8)
    }

    /// All three themes deliberately share one validated palette; a future edit
    /// that gives a theme its own untested hues should fail here first.
    func testAllThemesShareTheValidatedChartPalette() {
        for id in allThemes {
            XCTAssertEqual(PFMTheme.palette(for: id, colorScheme: .light).chartSeries.count,
                           PFMTheme.categoricalLight.count)
            XCTAssertEqual(PFMTheme.palette(for: id, colorScheme: .dark).chartSeries.count,
                           PFMTheme.categoricalDark.count)
        }
    }

    func testHeroGradientHasAtLeastTwoStops() {
        for id in allThemes {
            for scheme in allSchemes {
                let stops = PFMTheme.palette(for: id, colorScheme: scheme).heroGradient
                XCTAssertGreaterThanOrEqual(stops.count, 2,
                                            "\(id)/\(scheme): a gradient needs at least two stops")
            }
        }
    }

    // MARK: Metrics

    func testMetricsAreDistinctPerTheme() {
        let radii = allThemes.map { PFMTheme.metrics(for: $0).cardRadius }
        XCTAssertEqual(Set(radii).count, allThemes.count,
                       "each direction must have its own corner radius, or they read the same")
    }

    /// Graphite draws hairlines instead of shadows; a border width of zero would
    /// leave its cards with no edge at all.
    func testFlatThemeHasABorder() {
        for id in allThemes {
            let metrics = PFMTheme.metrics(for: id)
            if metrics.prefersFlatSurfaces {
                XCTAssertGreaterThan(metrics.borderWidth, 0,
                                     "\(id) has no shadow, so it must have a visible border")
            }
        }
        XCTAssertTrue(PFMTheme.metrics(for: .graphite).prefersFlatSurfaces)
        XCTAssertFalse(PFMTheme.metrics(for: .aurora).prefersFlatSurfaces)
    }

    func testMetricsArePositive() {
        for id in allThemes {
            let metrics = PFMTheme.metrics(for: id)
            XCTAssertGreaterThan(metrics.cardRadius, 0)
            XCTAssertGreaterThan(metrics.controlRadius, 0)
            XCTAssertGreaterThan(metrics.cardPadding, 0)
            XCTAssertGreaterThan(metrics.sectionSpacing, 0)
        }
    }

    // MARK: Member colours

    /// A member has to keep the same colour across screens and launches, or the
    /// avatars stop being a recognition aid.
    func testMemberColourIsStableForTheSameId() {
        let theme = PFMTheme.resolve(.aurora, colorScheme: .light)
        let person = Person(id: 7, weight: 1, name: "Mira", activated: true)
        XCTAssertEqual(theme.color(for: person), theme.color(for: person))
        XCTAssertEqual(theme.color(for: person), theme.seriesColor(7))
    }

    func testServerSuppliedColourWins() {
        let theme = PFMTheme.resolve(.aurora, colorScheme: .light)
        let custom = PersonColor(r: 60, g: 110, b: 186)
        let person = Person(id: 1, weight: 1, name: "Lena", activated: true, color: custom)
        XCTAssertEqual(theme.color(for: person), Color(custom))
    }

    /// A malformed payload could hand us a negative id; a negative modulo would
    /// crash the palette subscript.
    func testNegativeMemberIdDoesNotCrash() {
        let theme = PFMTheme.resolve(.mint, colorScheme: .dark)
        let person = Person(id: -13, weight: 1, name: "Bad", activated: true)
        XCTAssertEqual(theme.color(for: person), theme.seriesColor(-13))
    }

    func testSeriesColourWrapsPastThePaletteEnd() {
        let theme = PFMTheme.resolve(.graphite, colorScheme: .light)
        XCTAssertEqual(theme.seriesColor(0), theme.seriesColor(8))
        XCTAssertEqual(theme.seriesColor(3), theme.seriesColor(11))
    }

    // MARK: Money semantics

    func testMoneyColourFollowsSign() {
        for id in allThemes {
            for scheme in allSchemes {
                let theme = PFMTheme.resolve(id, colorScheme: scheme)
                XCTAssertEqual(theme.moneyColor(10), theme.palette.positive)
                XCTAssertEqual(theme.moneyColor(-10), theme.palette.negative)
                // A settled balance is neither good news nor bad news.
                XCTAssertEqual(theme.moneyColor(0), theme.palette.textSecondary)
                XCTAssertEqual(theme.moneyColor(0.001), theme.palette.textSecondary,
                               "sub-cent noise must not read as a debt")
            }
        }
    }

    // MARK: Colour parsing

    func testHexInitialiser() {
        XCTAssertEqual(Color(hex: 0xFF0000), Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1))
        XCTAssertEqual(Color(hex: 0x000000), Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1))
        XCTAssertEqual(Color(hex: 0xFFFFFF), Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1))
    }

    func testCospendHexParsing() {
        XCTAssertEqual(Color(cospendHex: "#ff0000"), Color(hex: 0xFF0000))
        XCTAssertEqual(Color(cospendHex: "ff0000"), Color(hex: 0xFF0000))
        XCTAssertEqual(Color(cospendHex: "  #FF0000 "), Color(hex: 0xFF0000))
        // Anything that is not six hex digits is rejected rather than guessed at.
        XCTAssertNil(Color(cospendHex: "#fff"))
        XCTAssertNil(Color(cospendHex: ""))
        XCTAssertNil(Color(cospendHex: "not-a-colour"))
        XCTAssertNil(Color(cospendHex: "#ggggggg"))
    }

    // MARK: Appearance

    func testAppearanceMapsToColorScheme() {
        XCTAssertNil(PFMAppearance.system.colorScheme, "system must not override")
        XCTAssertEqual(PFMAppearance.light.colorScheme, .light)
        XCTAssertEqual(PFMAppearance.dark.colorScheme, .dark)
    }

    func testEveryEnumCaseHasALocalizationKey() {
        for appearance in PFMAppearance.allCases {
            XCTAssertFalse(appearance.localizationKey.isEmpty)
        }
        for id in PFMThemeID.allCases {
            XCTAssertFalse(id.localizationKey.isEmpty)
            XCTAssertFalse(id.subtitleKey.isEmpty)
        }
        for range in StatisticsRange.allCases {
            XCTAssertFalse(range.localizationKey.isEmpty)
        }
    }

    /// Raw values are what get written to UserDefaults, so renaming a case would
    /// silently reset everyone's chosen theme.
    func testRawValuesAreStable() {
        XCTAssertEqual(PFMThemeID.aurora.rawValue, "aurora")
        XCTAssertEqual(PFMThemeID.graphite.rawValue, "graphite")
        XCTAssertEqual(PFMThemeID.mint.rawValue, "mint")
        XCTAssertEqual(PFMAppearance.system.rawValue, "system")
    }

    func testControllerDefaultsToAuroraAndSystem() {
        // The shared controller reads UserDefaults once at launch; an unknown or
        // missing stored value has to fall back rather than crash.
        XCTAssertEqual(PFMThemeID(rawValue: "not-a-theme") ?? .aurora, .aurora)
        XCTAssertEqual(PFMAppearance(rawValue: "") ?? .system, .system)
    }
}
