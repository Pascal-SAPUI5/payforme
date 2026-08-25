//
//  StatisticsViewModelTests.swift
//  DividoTests
//
//  Covers the presentation decisions the view model makes on top of the engine:
//  which members get a bar, how the category tail is folded, how rows are ranked.
//

import SwiftUI
import XCTest
@testable import Divido

final class StatisticsViewModelTests: XCTestCase {

    private let alice = Person(id: 1, weight: 1, name: "Alice", activated: true)
    private let bob = Person(id: 2, weight: 1, name: "Bob", activated: true)
    private let carla = Person(id: 3, weight: 1, name: "Carla", activated: true)

    private func date(_ string: String) -> Date {
        DateFormatter.cospend.date(from: string)!
    }

    private func makeProject(bills: [Bill],
                             members: [Person],
                             categories: [Int: ProjectCategory] = [:],
                             currency: String = "") -> Project {
        let project = Project(name: "test", password: "pw", token: "tok",
                              backend: .cospend, url: URL(string: "https://test.de")!,
                              projectId: "test")
        project.members = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0) })
        project.bills = bills
        project.categories = categories
        project.currencyName = currency
        return project
    }

    private func makeViewModel(_ project: Project) -> StatisticsViewModel {
        let viewModel = StatisticsViewModel()
        viewModel.currentProject = project
        viewModel.range = .allTime
        viewModel.recompute()
        return viewModel
    }

    private func bill(_ id: Int, _ amount: Double, payer: Int, owers: [Person],
                      category: Int? = nil) -> Bill {
        Bill(id: id, amount: amount, what: "bill \(id)", date: date("2026-05-10"),
             payer_id: payer, owers: owers, repeat: "n", lastchanged: nil,
             categoryid: category, paymentmode: nil)
    }

    // MARK: Currency

    func testCurrencyIsNilWhenServerReportsNone() {
        let viewModel = makeViewModel(makeProject(bills: [], members: [alice]))
        XCTAssertNil(viewModel.currency, "an empty currency must not become a blank suffix")
    }

    func testCurrencyIsPassedThroughWhenKnown() {
        let viewModel = makeViewModel(makeProject(bills: [], members: [alice], currency: "\u{20AC}"))
        XCTAssertEqual(viewModel.currency, "\u{20AC}")
    }

    // MARK: Paid rows

    func testPaidRowsAreRankedAndNormalised() {
        let project = makeProject(bills: [
            bill(1, 100, payer: alice.id, owers: [alice, bob]),
            bill(2, 50, payer: bob.id, owers: [alice, bob]),
        ], members: [alice, bob, carla])

        let rows = makeViewModel(project).paidRows
        XCTAssertEqual(rows.map { $0.person.id }, [alice.id, bob.id],
                       "ranked by amount paid, descending")
        XCTAssertEqual(rows[0].fraction, 1.0, accuracy: 0.001, "the top row fills the bar")
        XCTAssertEqual(rows[1].fraction, 0.5, accuracy: 0.001)
    }

    /// A row of empty bars is noise; members who paid nothing still show up in
    /// the balance section.
    func testMembersWhoPaidNothingAreOmittedFromPaidRows() {
        let project = makeProject(bills: [bill(1, 100, payer: alice.id, owers: [alice, carla])],
                                  members: [alice, bob, carla])
        let viewModel = makeViewModel(project)
        XCTAssertEqual(viewModel.paidRows.map { $0.person.id }, [alice.id])
        XCTAssertTrue(viewModel.balanceEntries.contains { $0.person.id == carla.id })
    }

    func testPaidRowsEmptyWithoutBills() {
        XCTAssertTrue(makeViewModel(makeProject(bills: [], members: [alice])).paidRows.isEmpty)
    }

    // MARK: Balances

    func testBalanceEntriesAreSortedCreditorsFirst() {
        let project = makeProject(bills: [
            bill(1, 90, payer: alice.id, owers: [alice, bob, carla]),
        ], members: [alice, bob, carla])
        let entries = makeViewModel(project).balanceEntries
        XCTAssertEqual(entries.first?.person.id, alice.id, "biggest creditor first")
        XCTAssertLessThan(entries.last!.balance, entries.first!.balance)
    }

    /// Someone who joined the project but appears in no bill has nothing to show.
    func testUninvolvedMembersAreExcludedFromBalances() {
        let project = makeProject(bills: [bill(1, 20, payer: alice.id, owers: [alice])],
                                  members: [alice, bob])
        XCTAssertFalse(makeViewModel(project).balanceEntries.contains { $0.person.id == bob.id })
    }

    // MARK: Categories

    private func categories(_ count: Int) -> [Int: ProjectCategory] {
        var result: [Int: ProjectCategory] = [:]
        for index in 1 ... count {
            result[-index] = ProjectCategory(id: -index, name: "Cat \(index)", icon: "")
        }
        return result
    }

    func testCategorySegmentsSumToOne() {
        let theme = PFMTheme.resolve(.aurora, colorScheme: .light)
        let project = makeProject(bills: [
            bill(1, 30, payer: alice.id, owers: [alice], category: -1),
            bill(2, 70, payer: alice.id, owers: [alice], category: -2),
        ], members: [alice], categories: categories(2))

        let segments = makeViewModel(project).categorySegments(theme: theme)
        XCTAssertEqual(segments.count, 2)
        XCTAssertEqual(segments.reduce(0) { $0 + $1.fraction }, 1.0, accuracy: 0.001)
        XCTAssertEqual(segments.first?.fraction ?? 0, 0.7, accuracy: 0.001, "largest slice first")
    }

    /// The palette tops out at eight hues and a ninth is never generated, so the
    /// tail has to collapse into a single "Other" slice.
    func testCategoryTailFoldsIntoOther() {
        let theme = PFMTheme.resolve(.aurora, colorScheme: .light)
        var bills: [Bill] = []
        for index in 1 ... 10 {
            // Descending amounts so the fold takes the smallest categories.
            bills.append(bill(index, Double(100 - index * 5), payer: alice.id,
                              owers: [alice], category: -index))
        }
        let project = makeProject(bills: bills, members: [alice], categories: categories(10))
        let segments = makeViewModel(project).categorySegments(theme: theme)

        XCTAssertEqual(segments.count, 8, "seven real slices plus one Other")
        XCTAssertEqual(segments.last?.color, theme.palette.textTertiary,
                       "Other takes a neutral, never a ninth hue")
        XCTAssertEqual(segments.reduce(0) { $0 + $1.fraction }, 1.0, accuracy: 0.001,
                       "folding must not lose money")
    }

    func testNoCategorySegmentsWithoutServerCategories() {
        let theme = PFMTheme.resolve(.mint, colorScheme: .dark)
        let project = makeProject(bills: [bill(1, 30, payer: alice.id, owers: [alice], category: -1)],
                                  members: [alice])
        XCTAssertTrue(makeViewModel(project).categorySegments(theme: theme).isEmpty)
    }

    // MARK: Largest bills

    func testLargestBillsAreCappedAndSorted() {
        var bills: [Bill] = []
        for index in 1 ... 9 {
            bills.append(bill(index, Double(index) * 10, payer: alice.id, owers: [alice]))
        }
        let largest = makeViewModel(makeProject(bills: bills, members: [alice])).largestBills
        XCTAssertEqual(largest.count, 5, "the list is capped at five")
        XCTAssertEqual(largest.map { $0.amount }, [90, 80, 70, 60, 50])
    }

    // MARK: Range switching

    func testSelectingARangeRecomputes() {
        let project = makeProject(bills: [
            Bill(id: 1, amount: 500, what: "old", date: date("2000-01-01"),
                 payer_id: alice.id, owers: [alice], repeat: "n"),
        ], members: [alice])
        let viewModel = makeViewModel(project)
        XCTAssertEqual(viewModel.statistics.totalSpent, 500, accuracy: 0.001)

        viewModel.select(range: .thisMonth)
        XCTAssertEqual(viewModel.range, .thisMonth)
        XCTAssertTrue(viewModel.statistics.isEmpty, "a bill from 2000 is not in this month")
    }

    func testSelectingTheSameRangeIsANoOp() {
        let viewModel = makeViewModel(makeProject(bills: [], members: [alice]))
        viewModel.select(range: .allTime)
        XCTAssertEqual(viewModel.range, .allTime)
    }

    func testPersonLookup() {
        let viewModel = makeViewModel(makeProject(bills: [], members: [alice, bob]))
        XCTAssertEqual(viewModel.person(id: alice.id)?.name, "Alice")
        XCTAssertNil(viewModel.person(id: 999))
    }
}
