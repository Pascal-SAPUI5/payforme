//
//  Theme.swift
//  Divido
//
//  The single source of truth for colour, elevation and shape.
//
//  Everything visual resolves through `PFMTheme`, which is handed down the view
//  tree via `@Environment(\.pfmTheme)`. A screen never hardcodes a colour: it
//  asks the theme. That is what makes three interchangeable visual identities —
//  and a light/dark variant of each — possible without touching a single screen.
//
//  Deployment target is iOS 15, so nothing in here may use iOS 16+ API.
//

import SwiftUI

// MARK: - Theme identity

/// The three visual directions. Users switch between them at runtime in
/// Projects ▸ Appearance.
enum PFMThemeID: String, CaseIterable, Identifiable, Codable {
    /// Deep indigo, saturated gradients, glassy surfaces. Premium fintech.
    case aurora
    /// Near-monochrome, editorial, hairline rules. Money colour is the only colour.
    case graphite
    /// Warm paper / deep espresso, mint + coral, generous rounding. Friendly.
    case mint

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .aurora: return "theme_aurora"
        case .graphite: return "theme_graphite"
        case .mint: return "theme_mint"
        }
    }

    var subtitleKey: String {
        switch self {
        case .aurora: return "theme_aurora_subtitle"
        case .graphite: return "theme_graphite_subtitle"
        case .mint: return "theme_mint_subtitle"
        }
    }
}

/// Light/dark override. `.system` follows the device setting.
enum PFMAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .system: return "appearance_system"
        case .light: return "appearance_light"
        case .dark: return "appearance_dark"
        }
    }

    /// `nil` means "don't override", which is what `.preferredColorScheme`
    /// expects for "follow the system".
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Palette

/// A fully resolved set of colours for one theme in one colour scheme.
struct PFMPalette {
    /// Page background, behind everything.
    let background: Color
    /// A second background tone used for grouped areas and the tab bar.
    let backgroundSecondary: Color
    /// Card / sheet fill.
    let surface: Color
    /// A raised element inside a card (chips, chart tracks).
    let surfaceElevated: Color
    /// Hairline rules and card borders.
    let separator: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color

    let accent: Color
    /// A low-opacity accent for chip and icon backgrounds.
    let accentMuted: Color
    /// Text/icon colour that is legible *on top of* `accent`.
    let onAccent: Color

    /// "You are owed" / income.
    let positive: Color
    /// "You owe" / expense.
    let negative: Color

    /// The hero gradient behind the balance header.
    let heroGradient: [Color]
    /// Text colour legible on `heroGradient`.
    let onHero: Color

    /// Categorical series colours for charts and member avatars, in draw order.
    /// Ordered so neighbours stay distinguishable and none of them collides with
    /// `positive`/`negative`, which carry meaning of their own.
    let chartSeries: [Color]

    let shadow: Color
    let shadowRadius: CGFloat
    let shadowY: CGFloat
}

/// Shape and rhythm. Split from the palette because it does not change between
/// light and dark — only between themes.
struct PFMMetrics {
    let cardRadius: CGFloat
    let controlRadius: CGFloat
    let cardPadding: CGFloat
    let sectionSpacing: CGFloat
    /// Width of card borders. `0` for themes that rely on shadow alone.
    let borderWidth: CGFloat
    /// Graphite draws rules instead of shadows; the card style checks this.
    let prefersFlatSurfaces: Bool
}

// MARK: - Theme

struct PFMTheme {
    let id: PFMThemeID
    let colorScheme: ColorScheme
    let palette: PFMPalette
    let metrics: PFMMetrics

    var isDark: Bool { colorScheme == .dark }

    static func resolve(_ id: PFMThemeID, colorScheme: ColorScheme) -> PFMTheme {
        PFMTheme(id: id,
                 colorScheme: colorScheme,
                 palette: palette(for: id, colorScheme: colorScheme),
                 metrics: metrics(for: id))
    }

    /// A stable colour for a member, used for avatars and for their series in
    /// every chart. Keyed by id so the same person keeps the same colour across
    /// screens and app launches.
    func color(for person: Person) -> Color {
        if let personColor = person.color {
            return Color(personColor)
        }
        let series = palette.chartSeries
        // `abs` guards against a negative id from a malformed payload, which
        // would otherwise make the modulo negative and crash the subscript.
        return series[abs(person.id) % series.count]
    }

    /// Series colour by position, for charts that are not member-keyed.
    func seriesColor(_ index: Int) -> Color {
        let series = palette.chartSeries
        return series[abs(index) % series.count]
    }

    /// Green above zero, red below, muted at exactly zero — a settled balance is
    /// not good news or bad news.
    func moneyColor(_ amount: Double) -> Color {
        if amount > 0.005 { return palette.positive }
        if amount < -0.005 { return palette.negative }
        return palette.textSecondary
    }
}

// MARK: - Palette definitions

extension PFMTheme {

    // MARK: Categorical chart palette
    //
    // Shared by all three themes rather than hand-picked per theme. These eight
    // hues (and this exact order) were validated with the data-viz palette
    // checker against every theme surface in both modes: lightness band, chroma
    // floor, adjacent CVD separation (worst dE 9.1 light / 8.4 dark, target 8),
    // normal-vision separation (19.6 / 19.3, floor 15) and contrast all pass.
    //
    // Re-ordering them is not a cosmetic change — the ordering *is* the
    // colour-blind-safety mechanism, because only neighbouring series are
    // required to be separable. Re-run the checker before touching this.
    //
    // In light mode three of the eight fall below 3:1 against white, which the
    // checker flags as "relief required": every chart that uses them ships
    // visible direct labels, so identity never rests on colour alone.
    static let categoricalLight: [Color] = [
        Color(hex: 0x2A78D6), Color(hex: 0xEB6834), Color(hex: 0x1BAF7A), Color(hex: 0xEDA100),
        Color(hex: 0xE87BA4), Color(hex: 0x008300), Color(hex: 0x4A3AA7), Color(hex: 0xE34948),
    ]

    static let categoricalDark: [Color] = [
        Color(hex: 0x3987E5), Color(hex: 0xD95926), Color(hex: 0x199E70), Color(hex: 0xC98500),
        Color(hex: 0xD55181), Color(hex: 0x008300), Color(hex: 0x9085E9), Color(hex: 0xE66767),
    ]

    static func metrics(for id: PFMThemeID) -> PFMMetrics {
        switch id {
        case .aurora:
            return PFMMetrics(cardRadius: 22, controlRadius: 14, cardPadding: 16,
                              sectionSpacing: 20, borderWidth: 0, prefersFlatSurfaces: false)
        case .graphite:
            return PFMMetrics(cardRadius: 10, controlRadius: 8, cardPadding: 16,
                              sectionSpacing: 24, borderWidth: 1, prefersFlatSurfaces: true)
        case .mint:
            return PFMMetrics(cardRadius: 28, controlRadius: 18, cardPadding: 18,
                              sectionSpacing: 20, borderWidth: 0, prefersFlatSurfaces: false)
        }
    }

    static func palette(for id: PFMThemeID, colorScheme: ColorScheme) -> PFMPalette {
        switch (id, colorScheme) {
        case (.aurora, .light): return auroraLight
        case (.aurora, _): return auroraDark
        case (.graphite, .light): return graphiteLight
        case (.graphite, _): return graphiteDark
        case (.mint, .light): return mintLight
        case (.mint, _): return mintDark
        }
    }

    // MARK: Aurora — deep indigo, saturated, glassy

    static let auroraLight = PFMPalette(
        background: Color(hex: 0xF4F5FB),
        backgroundSecondary: Color(hex: 0xEAECF7),
        surface: Color(hex: 0xFFFFFF),
        surfaceElevated: Color(hex: 0xF2F3FA),
        separator: Color(hex: 0x1A1B4B).opacity(0.08),
        textPrimary: Color(hex: 0x14152E),
        textSecondary: Color(hex: 0x5B5D80),
        textTertiary: Color(hex: 0x9698B4),
        accent: Color(hex: 0x5B4BE8),
        accentMuted: Color(hex: 0x5B4BE8).opacity(0.12),
        onAccent: .white,
        positive: Color(hex: 0x18A97B),
        negative: Color(hex: 0xE0455E),
        heroGradient: [Color(hex: 0x6A5AF9), Color(hex: 0x8E5AF0), Color(hex: 0xC65AE0)],
        onHero: .white,
        chartSeries: PFMTheme.categoricalLight,
        shadow: Color(hex: 0x2A2166).opacity(0.10),
        shadowRadius: 18,
        shadowY: 8
    )

    static let auroraDark = PFMPalette(
        background: Color(hex: 0x0B0B1A),
        backgroundSecondary: Color(hex: 0x121228),
        surface: Color(hex: 0x171733),
        surfaceElevated: Color(hex: 0x21214A),
        separator: Color.white.opacity(0.10),
        textPrimary: Color(hex: 0xF2F2FA),
        textSecondary: Color(hex: 0xA0A2C4),
        textTertiary: Color(hex: 0x6C6E92),
        accent: Color(hex: 0x8C7CFF),
        accentMuted: Color(hex: 0x8C7CFF).opacity(0.20),
        onAccent: Color(hex: 0x0B0B1A),
        positive: Color(hex: 0x3FD9A4),
        negative: Color(hex: 0xFF6E85),
        heroGradient: [Color(hex: 0x4A3DD1), Color(hex: 0x7B45D9), Color(hex: 0xA845C4)],
        onHero: .white,
        chartSeries: PFMTheme.categoricalDark,
        shadow: Color.black.opacity(0.55),
        shadowRadius: 20,
        shadowY: 10
    )

    // MARK: Graphite — editorial monochrome, money is the only colour

    static let graphiteLight = PFMPalette(
        background: Color(hex: 0xFBFBFA),
        backgroundSecondary: Color(hex: 0xF4F4F2),
        surface: Color(hex: 0xFFFFFF),
        surfaceElevated: Color(hex: 0xF2F2F0),
        separator: Color(hex: 0x1B1B18).opacity(0.12),
        textPrimary: Color(hex: 0x14140F),
        textSecondary: Color(hex: 0x5E5E56),
        textTertiary: Color(hex: 0x9A9A90),
        accent: Color(hex: 0x1B1B18),
        accentMuted: Color(hex: 0x1B1B18).opacity(0.07),
        onAccent: Color(hex: 0xFBFBFA),
        positive: Color(hex: 0x0F7B52),
        negative: Color(hex: 0xB3202F),
        heroGradient: [Color(hex: 0x24241F), Color(hex: 0x14140F)],
        onHero: Color(hex: 0xFBFBFA),
        chartSeries: PFMTheme.categoricalLight,
        shadow: Color.black.opacity(0.05),
        shadowRadius: 6,
        shadowY: 2
    )

    static let graphiteDark = PFMPalette(
        background: Color(hex: 0x0E0E0C),
        backgroundSecondary: Color(hex: 0x151513),
        surface: Color(hex: 0x1A1A17),
        surfaceElevated: Color(hex: 0x242420),
        separator: Color.white.opacity(0.14),
        textPrimary: Color(hex: 0xF5F5F0),
        textSecondary: Color(hex: 0xA5A59B),
        textTertiary: Color(hex: 0x6E6E66),
        accent: Color(hex: 0xF5F5F0),
        accentMuted: Color.white.opacity(0.10),
        onAccent: Color(hex: 0x0E0E0C),
        positive: Color(hex: 0x4FCB90),
        negative: Color(hex: 0xF06A78),
        heroGradient: [Color(hex: 0x2A2A25), Color(hex: 0x151513)],
        onHero: Color(hex: 0xF5F5F0),
        chartSeries: PFMTheme.categoricalDark,
        shadow: Color.black.opacity(0.6),
        shadowRadius: 8,
        shadowY: 3
    )

    // MARK: Mint — warm paper, soft mint + coral, generous rounding

    static let mintLight = PFMPalette(
        background: Color(hex: 0xFAF7F2),
        backgroundSecondary: Color(hex: 0xF2EDE4),
        surface: Color(hex: 0xFFFFFF),
        surfaceElevated: Color(hex: 0xF6F2EB),
        separator: Color(hex: 0x2E2A24).opacity(0.09),
        textPrimary: Color(hex: 0x231F1A),
        textSecondary: Color(hex: 0x6A6157),
        textTertiary: Color(hex: 0xA39A8D),
        accent: Color(hex: 0x0E9E7E),
        accentMuted: Color(hex: 0x0E9E7E).opacity(0.14),
        onAccent: .white,
        positive: Color(hex: 0x0E9E7E),
        negative: Color(hex: 0xE0644B),
        heroGradient: [Color(hex: 0x14B892), Color(hex: 0x0E9E7E), Color(hex: 0x0B7D77)],
        onHero: .white,
        chartSeries: PFMTheme.categoricalLight,
        shadow: Color(hex: 0x3A2E1E).opacity(0.10),
        shadowRadius: 16,
        shadowY: 8
    )

    static let mintDark = PFMPalette(
        background: Color(hex: 0x14120F),
        backgroundSecondary: Color(hex: 0x1B1815),
        surface: Color(hex: 0x211E1A),
        surfaceElevated: Color(hex: 0x2C2823),
        separator: Color.white.opacity(0.10),
        textPrimary: Color(hex: 0xF6F1E9),
        textSecondary: Color(hex: 0xB0A698),
        textTertiary: Color(hex: 0x7A7166),
        accent: Color(hex: 0x3ED3AC),
        accentMuted: Color(hex: 0x3ED3AC).opacity(0.18),
        onAccent: Color(hex: 0x0B1512),
        positive: Color(hex: 0x3ED3AC),
        negative: Color(hex: 0xFF8163),
        heroGradient: [Color(hex: 0x11785F), Color(hex: 0x0E5F58), Color(hex: 0x123F46)],
        onHero: Color(hex: 0xEFFBF6),
        chartSeries: PFMTheme.categoricalDark,
        shadow: Color.black.opacity(0.6),
        shadowRadius: 18,
        shadowY: 9
    )
}

// MARK: - Environment plumbing

private struct PFMThemeKey: EnvironmentKey {
    static let defaultValue = PFMTheme.resolve(.aurora, colorScheme: .light)
}

extension EnvironmentValues {
    var pfmTheme: PFMTheme {
        get { self[PFMThemeKey.self] }
        set { self[PFMThemeKey.self] = newValue }
    }
}

/// Persists the user's theme + appearance choice and republishes it so the whole
/// app restyles instantly when either changes.
final class ThemeController: ObservableObject {
    static let shared = ThemeController()

    private enum Keys {
        static let theme = "pfm.theme"
        static let appearance = "pfm.appearance"
    }

    @Published var themeID: PFMThemeID {
        didSet { UserDefaults.standard.set(themeID.rawValue, forKey: Keys.theme) }
    }

    @Published var appearance: PFMAppearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    private init() {
        let defaults = UserDefaults.standard
        themeID = PFMThemeID(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .aurora
        appearance = PFMAppearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
    }
}

/// Resolves the active theme for the current colour scheme and injects it, plus
/// applies the light/dark override and the accent tint in one place.
struct PFMThemedContainer<Content: View>: View {
    @ObservedObject private var controller = ThemeController.shared
    @Environment(\.colorScheme) private var systemColorScheme

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    /// The override wins when set; otherwise we follow the environment.
    private var effectiveScheme: ColorScheme {
        controller.appearance.colorScheme ?? systemColorScheme
    }

    private var theme: PFMTheme {
        PFMTheme.resolve(controller.themeID, colorScheme: effectiveScheme)
    }

    var body: some View {
        content
            .environment(\.pfmTheme, theme)
            .environmentObject(controller)
            .tint(theme.palette.accent)
            .preferredColorScheme(controller.appearance.colorScheme)
    }
}

// MARK: - Color helper

extension Color {
    /// `Color(hex: 0x5B4BE8)` — shorter and less error-prone at 60-odd call
    /// sites than spelling out three `Double` divisions each time.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Parses the `#rrggbb` strings Cospend uses for category colours.
    init?(cospendHex: String) {
        var string = cospendHex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt32(string, radix: 16) else { return nil }
        self.init(hex: value)
    }
}
