//
//  Components.swift
//  PayForMe
//
//  The shared building blocks every redesigned screen is assembled from.
//  All of them read their colours from `@Environment(\.pfmTheme)`, so a theme
//  switch restyles the whole app without any screen knowing about it.
//
//  Deployment target is iOS 17, so the whole modern SwiftUI surface is
//  available without availability gates.
//

import SwiftUI

// MARK: - Screen background

/// Paints the themed page background edge to edge.
///
/// Aurora and Mint get a very soft radial wash in the top corner so large empty
/// areas don't read as flat grey; Graphite deliberately stays flat — its whole
/// point is that paper is paper.
struct PFMBackground: View {
    @Environment(\.pfmTheme) private var theme

    var body: some View {
        ZStack {
            theme.palette.background
            if !theme.metrics.prefersFlatSurfaces {
                RadialGradient(
                    gradient: Gradient(colors: [
                        theme.palette.accent.opacity(theme.isDark ? 0.22 : 0.12),
                        theme.palette.background.opacity(0),
                    ]),
                    center: .init(x: 0.15, y: 0.0),
                    startRadius: 0,
                    endRadius: 420
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Card

/// The standard raised surface. Shadow-based for Aurora/Mint, border-based for
/// Graphite — a drop shadow under a hairline rule looks like a mistake.
struct PFMCardModifier: ViewModifier {
    @Environment(\.pfmTheme) private var theme

    var padding: CGFloat?
    var fill: Color?

    func body(content: Content) -> some View {
        let metrics = theme.metrics
        let palette = theme.palette
        let shape = RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous)

        return content
            .padding(padding ?? metrics.cardPadding)
            .background(fill ?? palette.surface)
            .clipShape(shape)
            .overlay(
                shape.strokeBorder(palette.separator, lineWidth: metrics.borderWidth)
            )
            .shadow(color: metrics.prefersFlatSurfaces ? .clear : palette.shadow,
                    radius: palette.shadowRadius,
                    x: 0,
                    y: palette.shadowY)
    }
}

extension View {
    func pfmCard(padding: CGFloat? = nil, fill: Color? = nil) -> some View {
        modifier(PFMCardModifier(padding: padding, fill: fill))
    }

    /// Rows that should look like free-floating cards rather than table cells.
    func pfmCardRow() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }
}

// MARK: - Typography

extension View {
    /// Numbers that sit in a column must not jitter as digits change.
    func pfmTabularNumbers() -> some View {
        font(Font.body.monospacedDigit())
    }
}

/// Small all-caps label above a group of content.
struct PFMSectionHeader: View {
    @Environment(\.pfmTheme) private var theme

    let titleKey: LocalizedStringKey
    var subtitleKey: LocalizedStringKey?
    var systemImage: String?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(theme.palette.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(titleKey)
                    .font(.footnote.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(0.8)
                    .foregroundColor(theme.palette.textSecondary)
                if let subtitleKey = subtitleKey {
                    Text(subtitleKey)
                        .font(.caption)
                        .foregroundColor(theme.palette.textTertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Avatar

/// A member's initials on their own colour. Used everywhere a person appears so
/// they become recognisable at a glance without reading the name.
struct PFMAvatar: View {
    @Environment(\.pfmTheme) private var theme

    let person: Person
    var size: CGFloat = 34
    /// Draws a ring in the surface colour so stacked avatars read as separate.
    var ringed: Bool = false

    var body: some View {
        let color = theme.color(for: person)
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Text(PFMAvatar.initials(for: person.name))
                    .font(.system(size: size * 0.40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    // A member colour supplied by the server can be arbitrarily
                    // light, so the white initials get a shadow rather than a
                    // guessed contrast flip.
                    .shadow(color: .black.opacity(0.28), radius: 1, x: 0, y: 0.5)
            )
            .overlay(
                Circle().strokeBorder(theme.palette.surface, lineWidth: ringed ? 2 : 0)
            )
    }

    /// "Anna Lee" → "AL", "pikachu" → "PI". Falls back to "?" for an empty name.
    static func initials(for name: String) -> String {
        let words = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == " " || $0 == "-" || $0 == "_" })
            .prefix(2)

        if words.count >= 2 {
            return words.compactMap { $0.first }.map(String.init).joined().uppercased()
        }
        guard let first = words.first else { return "?" }
        return String(first.prefix(2)).uppercased()
    }
}

/// Overlapping avatars with a "+n" cap, for the ower list on a bill row.
struct PFMAvatarStack: View {
    @Environment(\.pfmTheme) private var theme

    let people: [Person]
    var size: CGFloat = 26
    var maxVisible: Int = 4

    var body: some View {
        let visible = Array(people.prefix(maxVisible))
        let overflow = people.count - visible.count

        HStack(spacing: -size * 0.32) {
            ForEach(visible) { person in
                PFMAvatar(person: person, size: size, ringed: true)
            }
            if overflow > 0 {
                Circle()
                    .fill(theme.palette.surfaceElevated)
                    .frame(width: size, height: size)
                    .overlay(
                        Text("+\(overflow)")
                            .font(.system(size: size * 0.36, weight: .bold, design: .rounded))
                            .foregroundColor(theme.palette.textSecondary)
                    )
                    .overlay(Circle().strokeBorder(theme.palette.surface, lineWidth: 2))
            }
        }
        // Without this the stack keeps VoiceOver reading N separate images.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(people.map { $0.name }.joined(separator: ", ")))
    }
}

// MARK: - Chip

/// A small rounded label. `tint` nil means "use the accent".
struct PFMChip: View {
    @Environment(\.pfmTheme) private var theme

    let text: String
    var systemImage: String?
    var tint: Color?

    var body: some View {
        let color = tint ?? theme.palette.accent
        HStack(spacing: 4) {
            if let systemImage = systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.bold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(theme.isDark ? 0.22 : 0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Stat tile

/// One number with a caption. The workhorse of the statistics screen.
struct PFMStatTile: View {
    @Environment(\.pfmTheme) private var theme

    let titleKey: LocalizedStringKey
    let value: String
    var systemImage: String?
    var accent: Color?
    var caption: String?

    var body: some View {
        let color = accent ?? theme.palette.accent
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.bold))
                        .foregroundColor(color)
                        .frame(width: 24, height: 24)
                        .background(color.opacity(theme.isDark ? 0.20 : 0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                Text(titleKey)
                    .font(.caption.weight(.medium))
                    .foregroundColor(theme.palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Text(value)
                .font(Font.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundColor(theme.palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let caption = caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundColor(theme.palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pfmCard(padding: 14)
    }
}

// MARK: - Segmented control

/// A themed replacement for `Picker(.segmented)`, which ignores our palette and
/// looks out of place on a coloured background.
struct PFMSegmentedControl<Value: Hashable>: View {
    @Environment(\.pfmTheme) private var theme

    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.footnote.weight(isSelected ? .semibold : .medium))
                        .foregroundColor(isSelected ? theme.palette.onAccent : theme.palette.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: theme.metrics.controlRadius - 3, style: .continuous)
                                .fill(isSelected ? theme.palette.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(theme.palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous))
    }
}

// MARK: - Buttons

struct PFMPrimaryButtonStyle: ButtonStyle {
    @Environment(\.pfmTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let palette = theme.palette
        configuration.label
            .font(.headline)
            .foregroundColor(isEnabled ? palette.onAccent : palette.textTertiary)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous)
                    .fill(isEnabled ? palette.accent : palette.surfaceElevated)
            )
            .shadow(color: isEnabled && !theme.metrics.prefersFlatSurfaces ? palette.accent.opacity(0.32) : .clear,
                    radius: 14, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct PFMSecondaryButtonStyle: ButtonStyle {
    @Environment(\.pfmTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(theme.palette.accent)
            .padding(.vertical, 11)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: theme.metrics.controlRadius, style: .continuous)
                    .fill(theme.palette.accentMuted)
            )
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - Empty state

struct PFMEmptyState: View {
    @Environment(\.pfmTheme) private var theme

    let systemImage: String
    let titleKey: LocalizedStringKey
    var messageKey: LocalizedStringKey?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(theme.palette.accent)
                .frame(width: 72, height: 72)
                .background(theme.palette.accentMuted)
                .clipShape(Circle())
            Text(titleKey)
                .font(.headline)
                .foregroundColor(theme.palette.textPrimary)
                .multilineTextAlignment(.center)
            if let messageKey = messageKey {
                Text(messageKey)
                    .font(.subheadline)
                    .foregroundColor(theme.palette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
    }
}

// MARK: - Progress bar

/// A single horizontal share bar. Used for the per-member breakdown, where a
/// full bar chart would be more chrome than the number deserves.
struct PFMShareBar: View {
    @Environment(\.pfmTheme) private var theme

    /// 0...1. Values outside that range are clamped rather than drawn overflowing.
    let fraction: Double
    var tint: Color?
    var height: CGFloat = 6

    var body: some View {
        let color = tint ?? theme.palette.accent
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.palette.surfaceElevated)
                Capsule()
                    .fill(color)
                    .frame(width: max(0, min(1, fraction)) * geometry.size.width)
            }
        }
        .frame(height: height)
    }
}
