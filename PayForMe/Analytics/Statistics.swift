//
//  Statistics.swift
//  PayForMe
//
//  Cospend-style project analytics.
//
//  This file is deliberately free of SwiftUI/UIKit imports: everything in here is
//  pure value-type arithmetic over `Bill` and `Person`, which keeps it unit
//  testable in isolation and cheap to call from a view model.
//
//  SPLIT CONVENTION
//  ----------------
//  A bill's cost is split *equally* between everyone in `bill.owers`, ignoring
//  `Person.weight`. That is exactly what `BalanceViewModel.setBalances()` does,
//  and the two must agree — a "Statistics" balance that contradicts the
//  "Members" tab would be worse than no statistics at all.
//

import Foundation

// MARK: - Time range

/// The period a statistic is computed over. Mirrors the date filter in Cospend's
/// statistics page, but with fixed presets instead of two free-form date fields.
enum StatisticsRange: String, CaseIterable, Identifiable, Hashable {
    case thisMonth
    case last3Months
    case last6Months
    case thisYear
    case allTime

    var id: String { rawValue }

    /// Key into `Localizable.strings`.
    var localizationKey: String {
        switch self {
        case .thisMonth: return "stats_range_this_month"
        case .last3Months: return "stats_range_3_months"
        case .last6Months: return "stats_range_6_months"
        case .thisYear: return "stats_range_this_year"
        case .allTime: return "stats_range_all_time"
        }
    }

    /// The half-open interval `[start, end)` a bill's date must fall into.
    /// `nil` means "no filtering at all".
    func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .allTime:
            return nil
        case .thisMonth:
            guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
                  let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        case .last3Months:
            return trailingMonths(3, now: now, calendar: calendar)
        case .last6Months:
            return trailingMonths(6, now: now, calendar: calendar)
        case .thisYear:
            guard let start = calendar.date(from: calendar.dateComponents([.year], from: now)),
                  let end = calendar.date(byAdding: .year, value: 1, to: start) else { return nil }
            return DateInterval(start: start, end: end)
        }
    }

    /// `count` whole months back, including the current one. "Last 3 months" in
    /// March therefore starts on January 1st, not on the 1st of three 30-day
    /// periods ago — which is what users expect from a month-labelled filter.
    private func trailingMonths(_ count: Int, now: Date, calendar: Calendar) -> DateInterval? {
        guard let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let start = calendar.date(byAdding: .month, value: -(count - 1), to: currentMonthStart),
              let end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) else { return nil }
        return DateInterval(start: start, end: end)
    }

    /// A bill on the exact `end` boundary belongs to the *next* period, so the
    /// interval is treated as half-open. `DateInterval.contains` is closed on
    /// both ends, which would double-count a midnight bill.
    func contains(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let interval = interval(now: now, calendar: calendar) else { return true }
        return date >= interval.start && date < interval.end
    }
}

// MARK: - Result types

/// Everything the statistics screen knows about one project member.
struct MemberStatistics: Identifiable, Hashable {
    let person: Person
    /// Sum of every bill this member picked up the tab for.
    let paid: Double
    /// This member's share of every bill they were an ower on.
    let spent: Double
    /// Number of bills this member paid.
    let billsPaid: Int
    /// Number of bills this member owes a share of.
    let billsInvolved: Int

    var id: Int { person.id }

    /// Positive: the member is owed money. Negative: the member owes money.
    var balance: Double { paid - spent }
}

/// One month on the trend chart.
struct PeriodBucket: Identifiable, Hashable {
    /// Sortable `yyyy-MM` key.
    let id: String
    /// First instant of the month, for axis labelling.
    let start: Date
    let total: Double
    let billCount: Int
}

/// One slice of the category donut. Only populated for Cospend projects whose
/// server actually reports categories.
struct CategoryBreakdown: Identifiable, Hashable {
    let id: Int
    let name: String
    /// Emoji supplied by the Cospend server, e.g. "🛒". Empty when unknown.
    let icon: String
    let total: Double
    let billCount: Int
}

/// A single "X pays Y" instruction from the settlement plan.
struct Settlement: Identifiable, Hashable {
    let from: Person
    let to: Person
    let amount: Double

    var id: String { "\(from.id)->\(to.id)" }
}

/// The full analytics snapshot rendered by the Statistics tab.
struct ProjectStatistics {
    let range: StatisticsRange
    let bills: [Bill]
    let totalSpent: Double
    let averageBill: Double
    let largestBill: Bill?
    let memberStatistics: [MemberStatistics]
    let monthly: [PeriodBucket]
    let categories: [CategoryBreakdown]
    let settlements: [Settlement]

    var billCount: Int { bills.count }
    var isEmpty: Bool { bills.isEmpty }

    /// Member with the highest `paid` total, ignoring members who paid nothing.
    var topPayer: MemberStatistics? {
        memberStatistics.filter { $0.paid > 0 }.max { $0.paid < $1.paid }
    }

    /// Member with the highest `spent` total, ignoring members who spent nothing.
    var topSpender: MemberStatistics? {
        memberStatistics.filter { $0.spent > 0 }.max { $0.spent < $1.spent }
    }

    /// Average spend per member that actually took part in at least one bill.
    var averagePerMember: Double {
        let participating = memberStatistics.filter { $0.billsInvolved > 0 }
        guard !participating.isEmpty else { return 0 }
        return participating.reduce(0) { $0 + $1.spent } / Double(participating.count)
    }

    static func empty(range: StatisticsRange) -> ProjectStatistics {
        ProjectStatistics(range: range, bills: [], totalSpent: 0, averageBill: 0,
                          largestBill: nil, memberStatistics: [], monthly: [],
                          categories: [], settlements: [])
    }
}

// MARK: - Engine

enum StatisticsEngine {

    /// Builds the complete snapshot for one project.
    ///
    /// - Parameters:
    ///   - now: injectable so tests are not tied to the wall clock.
    ///   - calendar: injectable so tests are not tied to the device time zone.
    static func statistics(bills: [Bill],
                           members: [Int: Person],
                           categories: [Int: ProjectCategory] = [:],
                           range: StatisticsRange,
                           now: Date = Date(),
                           calendar: Calendar = .current) -> ProjectStatistics {

        let filtered = bills.filter { range.contains($0.date, now: now, calendar: calendar) }

        guard !filtered.isEmpty else {
            // Members still deserve a row (all zeroes) so the screen does not
            // flicker between "has members" and "has none" as the filter changes.
            return ProjectStatistics(
                range: range,
                bills: [],
                totalSpent: 0,
                averageBill: 0,
                largestBill: nil,
                memberStatistics: memberStatistics(bills: [], members: members),
                monthly: [],
                categories: [],
                settlements: []
            )
        }

        let total = filtered.reduce(0) { $0 + $1.amount }
        let stats = memberStatistics(bills: filtered, members: members)

        return ProjectStatistics(
            range: range,
            bills: filtered,
            totalSpent: total,
            averageBill: total / Double(filtered.count),
            largestBill: filtered.max { $0.amount < $1.amount },
            memberStatistics: stats,
            monthly: monthlyBuckets(bills: filtered, calendar: calendar),
            categories: categoryBreakdown(bills: filtered, categories: categories),
            settlements: settlements(for: stats)
        )
    }

    // MARK: Per member

    static func memberStatistics(bills: [Bill], members: [Int: Person]) -> [MemberStatistics] {
        var paid: [Int: Double] = [:]
        var spent: [Int: Double] = [:]
        var billsPaid: [Int: Int] = [:]
        var billsInvolved: [Int: Int] = [:]

        for bill in bills {
            paid[bill.payer_id, default: 0] += bill.amount
            billsPaid[bill.payer_id, default: 0] += 1

            guard !bill.owers.isEmpty else { continue }
            let share = bill.amount / Double(bill.owers.count)
            // A malformed bill could list the same ower twice; charging the share
            // once per member keeps the split consistent with `owers.count`.
            for ower in Set(bill.owers.map { $0.id }) {
                spent[ower, default: 0] += share
                billsInvolved[ower, default: 0] += 1
            }
        }

        return members.values
            .map { person in
                MemberStatistics(person: person,
                                 paid: paid[person.id] ?? 0,
                                 spent: spent[person.id] ?? 0,
                                 billsPaid: billsPaid[person.id] ?? 0,
                                 billsInvolved: billsInvolved[person.id] ?? 0)
            }
            .sorted { lhs, rhs in
                if lhs.paid != rhs.paid { return lhs.paid > rhs.paid }
                return lhs.person.name.localizedCaseInsensitiveCompare(rhs.person.name) == .orderedAscending
            }
    }

    // MARK: Monthly trend

    /// One bucket per month between the first and last bill, including months
    /// with no spending at all — a trend line with holes in it reads as a data
    /// bug rather than as "nobody spent anything in April".
    static func monthlyBuckets(bills: [Bill], calendar: Calendar = .current) -> [PeriodBucket] {
        guard !bills.isEmpty else { return [] }

        var totals: [Date: (total: Double, count: Int)] = [:]
        for bill in bills {
            guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: bill.date)) else { continue }
            let existing = totals[monthStart] ?? (0, 0)
            totals[monthStart] = (existing.total + bill.amount, existing.count + 1)
        }

        guard let first = totals.keys.min(), let last = totals.keys.max() else { return [] }

        var buckets: [PeriodBucket] = []
        var cursor = first
        // Hard stop so a corrupt date can never spin this loop forever.
        var guardCounter = 0
        while cursor <= last, guardCounter < 600 {
            let entry = totals[cursor] ?? (0, 0)
            buckets.append(PeriodBucket(id: monthKey(for: cursor, calendar: calendar),
                                        start: cursor,
                                        total: entry.total,
                                        billCount: entry.count))
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
            guardCounter += 1
        }
        return buckets
    }

    static func monthKey(for date: Date, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 0, components.month ?? 0)
    }

    // MARK: Categories

    /// Groups by the Cospend `categoryid`. Names and icons come from the server —
    /// nothing is guessed here, so an unmapped id shows up as "uncategorised"
    /// rather than under a wrong label.
    static func categoryBreakdown(bills: [Bill], categories: [Int: ProjectCategory]) -> [CategoryBreakdown] {
        guard !categories.isEmpty else { return [] }

        var totals: [Int: (total: Double, count: Int)] = [:]
        for bill in bills {
            let id = bill.categoryid ?? 0
            let existing = totals[id] ?? (0, 0)
            totals[id] = (existing.total + bill.amount, existing.count + 1)
        }

        return totals
            .map { id, value in
                let category = categories[id]
                return CategoryBreakdown(id: id,
                                         name: category?.name ?? ProjectCategory.uncategorizedName,
                                         icon: category?.icon ?? "",
                                         total: value.total,
                                         billCount: value.count)
            }
            .sorted { lhs, rhs in
                if lhs.total != rhs.total { return lhs.total > rhs.total }
                return lhs.id < rhs.id
            }
    }

    // MARK: Settlement plan

    /// Greedy debt simplification: repeatedly settle the largest debtor against
    /// the largest creditor. For n members this produces at most n-1 transfers,
    /// which is the minimum achievable without solving an NP-hard subset-sum —
    /// the same trade-off Cospend's "settle project" makes.
    static func settlements(for stats: [MemberStatistics], epsilon: Double = 0.01) -> [Settlement] {
        var creditors = stats.filter { $0.balance > epsilon }
            .map { (person: $0.person, amount: $0.balance) }
            .sorted { $0.amount > $1.amount }
        var debtors = stats.filter { $0.balance < -epsilon }
            .map { (person: $0.person, amount: -$0.balance) }
            .sorted { $0.amount > $1.amount }

        var result: [Settlement] = []
        var creditorIndex = 0
        var debtorIndex = 0

        while creditorIndex < creditors.count, debtorIndex < debtors.count {
            let transfer = min(creditors[creditorIndex].amount, debtors[debtorIndex].amount)

            if transfer > epsilon {
                result.append(Settlement(from: debtors[debtorIndex].person,
                                         to: creditors[creditorIndex].person,
                                         amount: transfer))
            }

            creditors[creditorIndex].amount -= transfer
            debtors[debtorIndex].amount -= transfer

            if creditors[creditorIndex].amount <= epsilon { creditorIndex += 1 }
            if debtors[debtorIndex].amount <= epsilon { debtorIndex += 1 }
        }

        return result
    }
}
