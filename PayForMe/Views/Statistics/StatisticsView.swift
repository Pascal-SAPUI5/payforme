//
//  StatisticsView.swift
//  PayForMe
//
//  The Statistics tab — PayForMe's answer to Cospend's statistics page:
//  totals, per-member paid/spent/balance, a monthly trend, a category
//  breakdown, and a concrete "who should pay whom" settlement plan.
//

import SwiftUI

struct StatisticsView: View {
    @Environment(\.pfmTheme) private var theme

    @ObservedObject var viewModel: StatisticsViewModel

    var body: some View {
        NavigationView {
            ZStack {
                PFMBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: theme.metrics.sectionSpacing) {
                        hero
                        rangePicker

                        if viewModel.statistics.isEmpty {
                            PFMEmptyState(systemImage: "chart.bar.xaxis",
                                          titleKey: "stats_empty_title",
                                          messageKey: "stats_empty_message")
                                .pfmCard()
                        } else {
                            kpiRow
                            balanceSection
                            settlementSection
                            trendSection
                            paidSection
                            categorySection
                            largestBillsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    // Clears the floating action button and the tab bar.
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await ProjectManager.shared.refresh()
                    viewModel.recompute()
                }
            }
            .navigationTitle("Statistics")
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("stats_total_spent")
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundColor(theme.palette.onHero.opacity(0.75))

            Text(MoneyFormatter.string(viewModel.statistics.totalSpent, currency: viewModel.currency))
                .font(Font.system(size: 40, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundColor(theme.palette.onHero)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            HStack(spacing: 6) {
                Image(systemName: "folder.fill").font(.caption2)
                Text(viewModel.currentProject.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
            }
            .foregroundColor(theme.palette.onHero.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(gradient: Gradient(colors: theme.palette.heroGradient),
                           startPoint: .topLeading,
                           endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: theme.metrics.cardRadius, style: .continuous))
        .shadow(color: theme.metrics.prefersFlatSurfaces ? .clear : theme.palette.shadow,
                radius: theme.palette.shadowRadius, x: 0, y: theme.palette.shadowY)
    }

    private var rangePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(StatisticsRange.allCases) { range in
                    let isSelected = viewModel.range == range
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { viewModel.select(range: range) }
                    } label: {
                        Text(LocalizedStringKey(range.localizationKey))
                            .font(.footnote.weight(isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? theme.palette.onAccent : theme.palette.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule().fill(isSelected ? theme.palette.accent : theme.palette.surface)
                            )
                            .overlay(
                                Capsule().strokeBorder(theme.palette.separator,
                                                       lineWidth: isSelected ? 0 : theme.metrics.borderWidth)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                }
            }
            // The horizontal scroll view would otherwise clip the chips' shadows
            // and cut the first one flush against the screen edge.
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
    }

    // MARK: KPIs

    private var kpiRow: some View {
        let stats = viewModel.statistics
        return VStack(spacing: 12) {
            HStack(spacing: 12) {
                PFMStatTile(titleKey: "stats_bills",
                            value: "\(stats.billCount)",
                            systemImage: "rectangle.stack.fill")
                PFMStatTile(titleKey: "stats_average_bill",
                            value: MoneyFormatter.string(stats.averageBill, currency: viewModel.currency),
                            systemImage: "divide.circle.fill")
            }
            HStack(spacing: 12) {
                PFMStatTile(titleKey: "stats_per_member",
                            value: MoneyFormatter.string(stats.averagePerMember, currency: viewModel.currency),
                            systemImage: "person.2.fill")
                PFMStatTile(titleKey: "stats_top_payer",
                            value: stats.topPayer?.person.name ?? "\u{2014}",
                            systemImage: "crown.fill",
                            accent: theme.palette.positive,
                            caption: stats.topPayer.map {
                                MoneyFormatter.string($0.paid, currency: viewModel.currency)
                            })
            }
        }
    }

    // MARK: Sections

    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PFMSectionHeader(titleKey: "stats_balances",
                             subtitleKey: "stats_balances_subtitle",
                             systemImage: "arrow.left.arrow.right")
            PFMDivergingBarList(entries: viewModel.balanceEntries, currency: viewModel.currency)
        }
        .pfmCard()
    }

    @ViewBuilder
    private var settlementSection: some View {
        let settlements = viewModel.statistics.settlements
        if settlements.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                PFMSectionHeader(titleKey: "stats_settle_up", systemImage: "checkmark.seal.fill")
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(theme.palette.positive)
                    Text("stats_all_settled")
                        .font(.subheadline)
                        .foregroundColor(theme.palette.textSecondary)
                }
            }
            .pfmCard()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                PFMSectionHeader(titleKey: "stats_settle_up",
                                 subtitleKey: "stats_settle_up_subtitle",
                                 systemImage: "arrow.triangle.swap")
                VStack(spacing: 12) {
                    ForEach(settlements) { settlement in
                        settlementRow(settlement)
                    }
                }
            }
            .pfmCard()
        }
    }

    private func settlementRow(_ settlement: Settlement) -> some View {
        HStack(spacing: 10) {
            PFMAvatar(person: settlement.from, size: 30)
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundColor(theme.palette.textTertiary)
            PFMAvatar(person: settlement.to, size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text(settlement.from.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)
                Text("stats_pays \(settlement.to.name)")
                    .font(.caption)
                    .foregroundColor(theme.palette.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(MoneyFormatter.string(settlement.amount, currency: viewModel.currency))
                .font(Font.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(theme.palette.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(settlement.from.name) \u{2192} \(settlement.to.name): \(MoneyFormatter.string(settlement.amount, currency: viewModel.currency))"))
    }

    @ViewBuilder
    private var trendSection: some View {
        let buckets = viewModel.statistics.monthly
        // One column is not a trend; the total is already in the hero.
        if buckets.count > 1 {
            VStack(alignment: .leading, spacing: 14) {
                PFMSectionHeader(titleKey: "stats_monthly", systemImage: "calendar")
                PFMColumnChart(buckets: buckets, currency: viewModel.currency)
            }
            .pfmCard()
        }
    }

    @ViewBuilder
    private var paidSection: some View {
        let rows = viewModel.paidRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                PFMSectionHeader(titleKey: "stats_who_paid",
                                 subtitleKey: "stats_who_paid_subtitle",
                                 systemImage: "creditcard.fill")
                PFMRankedBarList(rows: rows, currency: viewModel.currency)
            }
            .pfmCard()
        }
    }

    @ViewBuilder
    private var categorySection: some View {
        let segments = viewModel.categorySegments(theme: theme)
        // Hidden entirely for iHateMoney and for Cospend projects that never
        // configured categories, rather than showing an empty frame.
        if segments.count > 1 {
            VStack(alignment: .leading, spacing: 14) {
                PFMSectionHeader(titleKey: "stats_categories", systemImage: "tag.fill")
                PFMStackedShareBar(segments: segments, currency: viewModel.currency)
            }
            .pfmCard()
        }
    }

    @ViewBuilder
    private var largestBillsSection: some View {
        let bills = viewModel.largestBills
        if bills.count > 1 {
            VStack(alignment: .leading, spacing: 14) {
                PFMSectionHeader(titleKey: "stats_largest_bills", systemImage: "flame.fill")
                VStack(spacing: 12) {
                    ForEach(bills) { bill in
                        HStack(spacing: 10) {
                            if let payer = viewModel.person(id: bill.payer_id) {
                                PFMAvatar(person: payer, size: 30)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(bill.what.isEmpty ? NSLocalizedString("stats_untitled_bill", comment: "Bill with an empty description") : bill.what)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(theme.palette.textPrimary)
                                    .lineLimit(1)
                                Text(DateFormatter.cospendDisplay.string(from: bill.date))
                                    .font(.caption)
                                    .foregroundColor(theme.palette.textTertiary)
                            }
                            Spacer(minLength: 8)
                            Text(MoneyFormatter.string(bill.amount, currency: viewModel.currency))
                                .font(Font.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundColor(theme.palette.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .pfmCard()
        }
    }
}

struct StatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        previewProject.bills = previewBills
        previewProject.members = previewPersons
        let viewModel = StatisticsViewModel()
        viewModel.currentProject = previewProject
        viewModel.recompute()
        return PFMThemedContainer {
            StatisticsView(viewModel: viewModel)
        }
    }
}
