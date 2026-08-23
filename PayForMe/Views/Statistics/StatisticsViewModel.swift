//
//  StatisticsViewModel.swift
//  PayForMe
//
//  Adapts the pure `StatisticsEngine` output into exactly what the Statistics
//  screen draws. Presentation decisions (how many categories before folding into
//  "Other", how many members to rank) live here, not in the engine.
//

import Combine
import Foundation
import SwiftUI

final class StatisticsViewModel: ObservableObject {
    private let manager = ProjectManager.shared
    private var cancellable: AnyCancellable?

    @Published var currentProject: Project

    @Published var range: StatisticsRange = .allTime

    @Published private(set) var statistics: ProjectStatistics = .empty(range: .allTime)

    /// The categorical palette tops out at eight hues, and the skill's own rule
    /// is that a ninth series is never a generated colour — so the tail folds
    /// into a single "Other" slice instead.
    private let maxCategorySlices = 7

    /// Cospend's currency label, or nil when the server did not report one.
    var currency: String? {
        currentProject.currencyName.isEmpty ? nil : currentProject.currencyName
    }

    init() {
        currentProject = manager.currentProject
        cancellable = manager.$currentProject
            .sink { [weak self] project in
                guard let self = self else { return }
                self.currentProject = project
                self.recompute()
            }
        recompute()
    }

    func select(range newRange: StatisticsRange) {
        guard newRange != range else { return }
        range = newRange
        recompute()
    }

    func recompute() {
        statistics = StatisticsEngine.statistics(
            bills: currentProject.bills,
            members: currentProject.members,
            categories: currentProject.categories,
            range: range
        )
    }

    // MARK: Derived view data

    /// Members ranked by what they paid, largest first. Members who paid nothing
    /// are dropped — a row of empty bars is noise, and they still appear in the
    /// balance section.
    var paidRows: [PFMRankedBarRow] {
        let entries = statistics.memberStatistics.filter { $0.paid > 0 }
        guard let maximum = entries.map({ $0.paid }).max(), maximum > 0 else { return [] }
        return entries.map { entry in
            PFMRankedBarRow(id: entry.person.id,
                            person: entry.person,
                            value: entry.paid,
                            fraction: entry.paid / maximum)
        }
    }

    /// Balances, biggest creditor first, biggest debtor last.
    var balanceEntries: [MemberStatistics] {
        statistics.memberStatistics
            .filter { $0.billsInvolved > 0 || $0.billsPaid > 0 }
            .sorted { $0.balance > $1.balance }
    }

    /// Category slices with the tail folded into "Other" and the "Other" colour
    /// deliberately taken from the neutral text ramp, not a ninth hue.
    func categorySegments(theme: PFMTheme) -> [PFMShareSegment] {
        let breakdown = statistics.categories
        guard !breakdown.isEmpty, statistics.totalSpent > 0 else { return [] }

        var segments: [PFMShareSegment] = []
        let head = breakdown.prefix(maxCategorySlices)

        for (index, entry) in head.enumerated() {
            segments.append(PFMShareSegment(id: entry.id,
                                            label: entry.name,
                                            icon: entry.icon,
                                            value: entry.total,
                                            fraction: entry.total / statistics.totalSpent,
                                            color: theme.seriesColor(index)))
        }

        let tail = breakdown.dropFirst(maxCategorySlices)
        if !tail.isEmpty {
            let total = tail.reduce(0) { $0 + $1.total }
            segments.append(PFMShareSegment(id: Int.min,
                                            label: NSLocalizedString("stats_other_categories", comment: "Folded tail of the category breakdown"),
                                            icon: "",
                                            value: total,
                                            fraction: total / statistics.totalSpent,
                                            color: theme.palette.textTertiary))
        }
        return segments
    }

    /// The five biggest single expenses in the selected period.
    var largestBills: [Bill] {
        Array(statistics.bills.sorted { $0.amount > $1.amount }.prefix(5))
    }

    func person(id: Int) -> Person? {
        currentProject.members[id]
    }
}
