//
//  StatisticsTests.swift
//  UmlageTests
//
//  Tests for `StatisticsEngine`, which backs the Statistics tab AND — since the
//  two must never disagree — the balances on the Members tab.
//
//  Dates and the calendar are injected everywhere so these do not break when run
//  in a different time zone or in a different month.
//

import XCTest
@testable import Umlage

final class StatisticsTests: XCTestCase {

    private let alice = Person(id: 1, weight: 1, name: "Alice", activated: true)
    private let bob = Person(id: 2, weight: 1, name: "Bob", activated: true)
    private let carla = Person(id: 3, weight: 1, name: "Carla", activated: true)

    private var members: [Int: Person] { [1: alice, 2: bob, 3: carla] }

    /// UTC so a bill dated "2026-05-31" cannot slide into June for a tester in
    /// Auckland.
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ string: String) -> Date {
        DateFormatter.cospend.date(from: string)!
    }

    private func bill(_ id: Int, _ amount: Double, payer: Int, owers: [Person],
                      _ day: String, category: Int? = nil) -> Bill {
        Bill(id: id, amount: amount, what: "bill \(id)", date: date(day),
             payer_id: payer, owers: owers, repeat: "n", lastchanged: nil,
             categoryid: category, paymentmode: nil)
    }

    private func stats(_ bills: [Bill], range: StatisticsRange = .allTime,
                       now: String = "2026-05-15",
                       categories: [Int: ProjectCategory] = [:]) -> ProjectStatistics {
        StatisticsEngine.statistics(bills: bills, members: members, categories: categories,
                                    range: range, now: date(now), calendar: calendar)
    }

    private func member(_ person: Person, _ statistics: ProjectStatistics) -> MemberStatistics {
        statistics.memberStatistics.first { $0.person.id == person.id }!
    }

    // MARK: Member totals

    func testPaidSpentAndBalance() {
        // Alice pays 30 for all three; Bob pays 15 for Bob + Carla.
        let result = stats([
            bill(1, 30, payer: alice.id, owers: [alice, bob, carla], "2026-05-14"),
            bill(2, 15, payer: bob.id, owers: [bob, carla], "2026-05-14"),
        ])

        XCTAssertEqual(member(alice, result).paid, 30, accuracy: 0.001)
        XCTAssertEqual(member(alice, result).spent, 10, accuracy: 0.001)
        XCTAssertEqual(member(alice, result).balance, 20, accuracy: 0.001)
        XCTAssertEqual(member(bob, result).balance, -2.5, accuracy: 0.001)
        XCTAssertEqual(member(carla, result).balance, -17.5, accuracy: 0.001)
    }

    func testBalancesAlwaysSumToZero() {
        let result = stats([
            bill(1, 30, payer: alice.id, owers: [alice, bob, carla], "2026-05-01"),
            bill(2, 15, payer: bob.id, owers: [bob, carla], "2026-05-02"),
            bill(3, 9, payer: carla.id, owers: [alice, carla], "2026-05-03"),
        ])
        let total = result.memberStatistics.reduce(0) { $0 + $1.balance }
        XCTAssertEqual(total, 0, accuracy: 0.001)
    }

    /// The Members tab and the Statistics tab must show identical numbers.
    func testBalanceViewModelAgreesWithEngine() {
        let project = Project(name: "t", password: "p", token: "t",
                              backend: .cospend, url: URL(string: "https://t.de")!,
                              projectId: "t")
        project.members = members
        project.bills = [
            bill(1, 30, payer: alice.id, owers: [alice, bob, carla], "2026-05-14"),
            bill(2, 15, payer: bob.id, owers: [bob, carla], "2026-05-14"),
        ]

        let viewModel = BalanceViewModel()
        viewModel.currentProject = project
        viewModel.setBalances()

        let fromViewModel = Dictionary(uniqueKeysWithValues: viewModel.balances.map { ($0.id, $0.amount) })
        for entry in stats(project.bills).memberStatistics {
            XCTAssertEqual(fromViewModel[entry.person.id] ?? .nan, entry.balance, accuracy: 0.001,
                           "Members tab and Statistics disagree for \(entry.person.name)")
        }
    }

    func testDuplicateOwerIsChargedOnlyOnce() {
        let result = stats([bill(1, 30, payer: alice.id, owers: [alice, bob, bob], "2026-05-02")])
        XCTAssertEqual(member(bob, result).spent, 10, accuracy: 0.001)
        XCTAssertEqual(member(bob, result).billsInvolved, 1)
    }

    func testBillWithNoOwersDoesNotDivideByZero() {
        let result = stats([bill(1, 50, payer: alice.id, owers: [], "2026-05-02")])
        XCTAssertEqual(result.totalSpent, 50, accuracy: 0.001)
        XCTAssertEqual(member(alice, result).paid, 50, accuracy: 0.001)
        XCTAssertEqual(member(alice, result).spent, 0, accuracy: 0.001)
    }

    // MARK: Ranges

    func testRangeFiltering() {
        let bills = [
            bill(1, 100, payer: alice.id, owers: [alice, bob], "2026-05-10"),
            bill(2, 200, payer: alice.id, owers: [alice, bob], "2026-03-10"),
            bill(3, 400, payer: alice.id, owers: [alice, bob], "2025-11-10"),
        ]
        XCTAssertEqual(stats(bills, range: .thisMonth).totalSpent, 100, accuracy: 0.001)
        XCTAssertEqual(stats(bills, range: .last3Months).totalSpent, 300, accuracy: 0.001)
        XCTAssertEqual(stats(bills, range: .last6Months).totalSpent, 300, accuracy: 0.001)
        XCTAssertEqual(stats(bills, range: .thisYear).totalSpent, 300, accuracy: 0.001)
        XCTAssertEqual(stats(bills, range: .allTime).totalSpent, 700, accuracy: 0.001)
    }

    /// The end of a range is exclusive, or a bill at midnight on the 1st would be
    /// counted in both months.
    func testRangeBoundariesAreHalfOpen() {
        let now = date("2026-05-15")
        XCTAssertTrue(StatisticsRange.thisMonth.contains(date("2026-05-01"), now: now, calendar: calendar))
        XCTAssertTrue(StatisticsRange.thisMonth.contains(date("2026-05-31"), now: now, calendar: calendar))
        XCTAssertFalse(StatisticsRange.thisMonth.contains(date("2026-06-01"), now: now, calendar: calendar))
        XCTAssertFalse(StatisticsRange.thisMonth.contains(date("2026-04-30"), now: now, calendar: calendar))
    }

    func testAllTimeRangeHasNoInterval() {
        XCTAssertNil(StatisticsRange.allTime.interval(now: date("2026-05-15"), calendar: calendar))
    }

    // MARK: Monthly buckets

    func testMonthlyBucketsFillEmptyMonths() {
        let buckets = StatisticsEngine.monthlyBuckets(bills: [
            bill(1, 10, payer: alice.id, owers: [alice], "2026-01-05"),
            bill(2, 20, payer: alice.id, owers: [alice], "2026-04-05"),
        ], calendar: calendar)

        XCTAssertEqual(buckets.count, 4, "January through April, gaps included")
        XCTAssertEqual(buckets.map { $0.id }, ["2026-01", "2026-02", "2026-03", "2026-04"])
        XCTAssertEqual(buckets[1].total, 0, accuracy: 0.001)
        XCTAssertEqual(buckets[3].total, 20, accuracy: 0.001)
    }

    func testMonthlyBucketsSpanYearBoundary() {
        let buckets = StatisticsEngine.monthlyBuckets(bills: [
            bill(1, 10, payer: alice.id, owers: [alice], "2025-12-20"),
            bill(2, 20, payer: alice.id, owers: [alice], "2026-02-02"),
        ], calendar: calendar)
        XCTAssertEqual(buckets.map { $0.id }, ["2025-12", "2026-01", "2026-02"])
    }

    // MARK: Settlements

    func testSettlementPlanClearsEveryBalance() {
        let result = stats([
            bill(1, 30, payer: alice.id, owers: [alice, bob, carla], "2026-05-14"),
            bill(2, 15, payer: bob.id, owers: [bob, carla], "2026-05-14"),
        ])

        var balances = Dictionary(uniqueKeysWithValues: result.memberStatistics.map { ($0.person.id, $0.balance) })
        for transfer in result.settlements {
            balances[transfer.from.id, default: 0] += transfer.amount
            balances[transfer.to.id, default: 0] -= transfer.amount
        }

        for (id, balance) in balances {
            XCTAssertEqual(balance, 0, accuracy: 0.01, "member \(id) not settled by the plan")
        }
    }

    func testSettlementNeedsAtMostOneTransferPerMemberMinusOne() {
        let result = stats([
            bill(1, 30, payer: alice.id, owers: [alice, bob, carla], "2026-05-14"),
            bill(2, 15, payer: bob.id, owers: [bob, carla], "2026-05-14"),
        ])
        XCTAssertLessThanOrEqual(result.settlements.count, members.count - 1)
        XCTAssertEqual(result.settlements.count, 2)
    }

    func testNothingToSettleProducesNoTransfers() {
        // One member paying for only themselves leaves everyone square.
        let result = stats([bill(1, 10, payer: alice.id, owers: [alice], "2026-05-01")])
        XCTAssertTrue(result.settlements.isEmpty)
    }

    /// Rounding noise below a cent must not generate a "pay 0.00" instruction.
    func testSubCentImbalanceIsIgnored() {
        let stats = [
            MemberStatistics(person: alice, paid: 0.004, spent: 0, billsPaid: 1, billsInvolved: 0),
            MemberStatistics(person: bob, paid: 0, spent: 0.004, billsPaid: 0, billsInvolved: 1),
        ]
        XCTAssertTrue(StatisticsEngine.settlements(for: stats).isEmpty)
    }

    // MARK: Categories

    func testCategoryBreakdownSumsToTotal() {
        let categories = [
            -1: ProjectCategory(id: -1, name: "Grocery", icon: "\u{1F6D2}"),
            -3: ProjectCategory(id: -3, name: "Rent", icon: "\u{1F3E0}"),
        ]
        let result = stats([
            bill(1, 30, payer: alice.id, owers: [alice], "2026-05-01", category: -1),
            bill(2, 70, payer: alice.id, owers: [alice], "2026-05-02", category: -3),
            bill(3, 10, payer: alice.id, owers: [alice], "2026-05-03"),
        ], categories: categories)

        XCTAssertEqual(result.categories.count, 3, "two named categories plus uncategorised")
        XCTAssertEqual(result.categories.first?.name, "Rent", "sorted by total, descending")
        XCTAssertEqual(result.categories.reduce(0) { $0 + $1.total }, result.totalSpent, accuracy: 0.001)
    }

    /// Without server-supplied categories we show no breakdown at all rather
    /// than a list of meaningless numeric ids.
    func testNoCategoriesWithoutServerData() {
        let result = stats([bill(1, 30, payer: alice.id, owers: [alice], "2026-05-01", category: -1)])
        XCTAssertTrue(result.categories.isEmpty)
    }

    // MARK: Empty state

    func testEmptyRangeStillListsMembers() {
        let result = stats([bill(1, 10, payer: alice.id, owers: [alice], "2020-01-01")], range: .thisMonth)
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.totalSpent, 0, accuracy: 0.001)
        XCTAssertEqual(result.memberStatistics.count, 3)
        XCTAssertTrue(result.settlements.isEmpty)
    }

    func testAveragesAndExtremes() {
        let result = stats([
            bill(1, 10, payer: alice.id, owers: [alice, bob], "2026-05-01"),
            bill(2, 40, payer: bob.id, owers: [alice, bob], "2026-05-02"),
        ])
        XCTAssertEqual(result.averageBill, 25, accuracy: 0.001)
        XCTAssertEqual(result.largestBill?.id, 2)
        XCTAssertEqual(result.topPayer?.person.id, bob.id)
        // Alice and Bob each carry half of both bills; Carla took part in neither
        // and is excluded from the per-member average.
        XCTAssertEqual(result.averagePerMember, 25, accuracy: 0.001)
    }
}
