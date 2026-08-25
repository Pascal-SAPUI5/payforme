//
//  AppearanceSettingsView.swift
//  Umlage
//
//  Lets people pick one of the three visual directions and force light or dark.
//  Each theme is shown as a live miniature built from that theme's own palette,
//  so the choice is made by looking rather than by reading three adjectives.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.pfmTheme) private var theme
    @EnvironmentObject private var controller: ThemeController

    var body: some View {
        ZStack {
            PFMBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: theme.metrics.sectionSpacing) {
                    VStack(alignment: .leading, spacing: 14) {
                        PFMSectionHeader(titleKey: "appearance_mode",
                                         subtitleKey: "appearance_mode_subtitle",
                                         systemImage: "circle.lefthalf.filled")
                        PFMSegmentedControl(selection: $controller.appearance,
                                            options: PFMAppearance.allCases) { option in
                            LocalizedStringKey(option.localizationKey)
                        }
                    }
                    .pfmCard()

                    VStack(alignment: .leading, spacing: 14) {
                        PFMSectionHeader(titleKey: "appearance_theme",
                                         subtitleKey: "appearance_theme_subtitle",
                                         systemImage: "paintpalette.fill")
                        VStack(spacing: 12) {
                            ForEach(PFMThemeID.allCases) { candidate in
                                themeRow(candidate)
                            }
                        }
                    }
                    .pfmCard()
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("appearance_title")
    }

    private func themeRow(_ candidate: PFMThemeID) -> some View {
        let isSelected = controller.themeID == candidate
        return Button {
            withAnimation(.easeOut(duration: 0.22)) { controller.themeID = candidate }
        } label: {
            HStack(spacing: 14) {
                ThemeSwatch(themeID: candidate, colorScheme: theme.colorScheme)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(candidate.localizationKey))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.palette.textPrimary)
                    Text(LocalizedStringKey(candidate.subtitleKey))
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? theme.palette.accent : theme.palette.textTertiary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous)
                    .fill(isSelected ? theme.palette.accentMuted : theme.palette.surfaceElevated.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous)
                    .strokeBorder(isSelected ? theme.palette.accent : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// A miniature of what the theme looks like: its page colour, a card, its accent
/// and the first three chart hues. Rendered from the candidate theme's palette,
/// not the active one — that is the whole point of a swatch.
private struct ThemeSwatch: View {
    let themeID: PFMThemeID
    let colorScheme: ColorScheme

    var body: some View {
        let palette = PFMTheme.palette(for: themeID, colorScheme: colorScheme)
        let metrics = PFMTheme.metrics(for: themeID)

        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(palette.background)

            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(LinearGradient(gradient: Gradient(colors: palette.heroGradient),
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: 14)

                RoundedRectangle(cornerRadius: metrics.cardRadius / 4, style: .continuous)
                    .fill(palette.surface)
                    .frame(height: 16)
                    .overlay(
                        HStack(spacing: 3) {
                            ForEach(0 ..< 3, id: \.self) { index in
                                Circle()
                                    .fill(palette.chartSeries[index])
                                    .frame(width: 6, height: 6)
                            }
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(palette.textTertiary)
                                .frame(width: 14, height: 3)
                        }
                        .padding(.horizontal, 5)
                    )

                HStack(spacing: 4) {
                    Capsule().fill(palette.accent).frame(width: 22, height: 7)
                    Capsule().fill(palette.positive).frame(width: 12, height: 7)
                    Capsule().fill(palette.negative).frame(width: 12, height: 7)
                }
            }
            .padding(7)
        }
        .frame(width: 74, height: 66)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(palette.separator, lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        PFMThemedContainer {
            NavigationView {
                AppearanceSettingsView()
            }
        }
    }
}
