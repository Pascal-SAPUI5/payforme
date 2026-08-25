//
//  AddProjectView.swift
//  Umlage
//
//  Created by Camille Mainz on 14.02.20.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.pfmTheme) private var theme

    @State private var moreInfo = false

    var body: some View {
        NavigationView {
            ZStack {
                PFMBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 26) {
                        Spacer(minLength: 24)

                        logo

                        VStack(spacing: 10) {
                            Text("Welcome to PayForMe!")
                                .font(Font.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundColor(theme.palette.textPrimary)
                                .multilineTextAlignment(.center)

                            Text("To get started sharing expenses with friends, you must add a project from Cospend or iHateMoney. To do this, scan the QR code or click the link for the project that was shared with you.")
                                .font(.subheadline)
                                .foregroundColor(theme.palette.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        NavigationLink(destination: AddProjectManualView()) {
                            Label("Add project", systemImage: "plus")
                        }
                        .buttonStyle(PFMPrimaryButtonStyle())

                        Button {
                            withAnimation(.easeOut(duration: 0.22)) { self.moreInfo.toggle() }
                        } label: {
                            Label(moreInfo ? "onboarding_hide_info" : "onboarding_what_is_this",
                                  systemImage: moreInfo ? "chevron.up" : "questionmark.circle")
                        }
                        .buttonStyle(PFMSecondaryButtonStyle())

                        if moreInfo {
                            backendCards
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var logo: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(gradient: Gradient(colors: theme.palette.heroGradient),
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 96, height: 96)
                .shadow(color: theme.metrics.prefersFlatSurfaces ? .clear : theme.palette.accent.opacity(0.35),
                        radius: 22, x: 0, y: 10)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(theme.palette.onHero)
        }
        .accessibilityHidden(true)
    }

    private var backendCards: some View {
        VStack(spacing: 12) {
            backendCard(titleKey: "Cospend is a NextCloud app",
                        linkTitle: "nextcloud.com",
                        url: "https://nextcloud.com/",
                        systemImage: "cloud.fill")
            backendCard(titleKey: "To use iHateMoney, host an own instance or register at",
                        linkTitle: "iHateMoney.org",
                        url: "https://ihatemoney.org/",
                        systemImage: "globe")
        }
    }

    private func backendCard(titleKey: LocalizedStringKey,
                             linkTitle: String,
                             url: String,
                             systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.footnote.weight(.bold))
                    .foregroundColor(theme.palette.accent)
                Text(titleKey)
                    .font(.subheadline)
                    .foregroundColor(theme.palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            Button(linkTitle) {
                if let target = URL(string: url), UIApplication.shared.canOpenURL(target) {
                    UIApplication.shared.open(target)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundColor(theme.palette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pfmCard()
    }
}

struct OnboardingViewView_Previews: PreviewProvider {
    static var previews: some View {
        PFMThemedContainer {
            OnboardingView()
        }
        .environment(\.locale, .init(identifier: "de"))
    }
}
