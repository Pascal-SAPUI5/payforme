//
//  Views+Extensions.swift
//  Umlage
//
//  Created by Max Tharr on 03.10.20.
//

import Foundation
import SwiftUI

extension View {
    /// Legacy call sites still reach for this; it now defers to the design
    /// system so the colour follows the selected theme instead of the asset
    /// catalogue's fixed accent.
    func fancyStyle(active: Bool = true) -> some View {
        modifier(PFMLegacyFancyStyle(active: active))
    }

    /// The system glass style picks up the `.tint` the themed container sets,
    /// so it is already theme-aware.
    ///
    /// `active` used to be dropped on iOS 26 — the availability branch that
    /// applied it only existed below that — so every caller passing
    /// `active: false` got a button that still responded to taps. Applying it
    /// here restores what the call sites always meant.
    func prominentActionStyle(active: Bool = true) -> some View {
        buttonStyle(.glassProminent).disabled(!active)
    }

    func glassTabBarMinimize() -> some View {
        tabBarMinimizeBehavior(.onScrollDown)
    }

    func eraseToAnyView() -> AnyView {
        AnyView(self)
    }

    func glassCircleStyle() -> some View {
        buttonStyle(.glassProminent).buttonBorderShape(.circle)
    }

    func glassActionButton(systemImage: String,
                           accessibilityLabel: LocalizedStringKey,
                           accessibilityIdentifier: String? = nil,
                           action: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            GlassActionButton(systemImage: systemImage,
                              accessibilityLabel: accessibilityLabel,
                              accessibilityIdentifier: accessibilityIdentifier,
                              action: action)
                .padding(.trailing, 20)
                .padding(.bottom, 20)
        }
    }
}

/// The plus is composited as a separate badge rather than using the `.badge.plus` symbol variant,
/// which sits in a different spot per symbol.
struct GlassActionButton: View {
    @Environment(\.pfmTheme) private var theme

    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var accessibilityIdentifier: String?
    let action: () -> Void

    var body: some View {
        let button = Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .overlay(alignment: .bottomLeading) { plusBadge }
                .frame(width: 56, height: 56)
        }
        .glassCircleStyle()
        .accessibilityLabel(Text(accessibilityLabel))

        if let accessibilityIdentifier {
            button.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            button
        }
    }

    private var plusBadge: some View {
        Image(systemName: "plus")
            .font(.system(size: 8, weight: .black))
            .foregroundStyle(theme.palette.accent)
            .padding(3)
            .background(theme.palette.onAccent, in: Circle())
            .offset(x: -4, y: 4)
    }
}

// MARK: - Themed styling

private struct PFMLegacyFancyStyle: ViewModifier {
    @Environment(\.pfmTheme) private var theme

    let active: Bool

    func body(content: Content) -> some View {
        let fill = active ? theme.palette.accent : theme.palette.surfaceElevated
        return content
            .padding(10)
            .background(fill)
            .foregroundColor(active ? theme.palette.onAccent : theme.palette.textTertiary)
            .cornerRadius(theme.metrics.controlRadius)
            .shadow(color: theme.metrics.prefersFlatSurfaces ? .clear : fill.opacity(0.45),
                    radius: 8, x: 0, y: 4)
    }
}
