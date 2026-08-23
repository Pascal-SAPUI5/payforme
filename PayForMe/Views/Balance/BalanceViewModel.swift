//
//  BalanceViewModel.swift
//  iWontPayAnyway
//
//  Created by Max Tharr on 29.01.20.
//

import Combine
import Foundation
import SwiftUI

class BalanceViewModel: ObservableObject {
    var manager = ProjectManager.shared
    var cancellable: Cancellable?

    @Published
    var currentProject: Project

    @Published
    var balances = [Balance]()

    init() {
        currentProject = manager.currentProject
        setBalances()

        cancellable = currentProjectChanged
    }

    var currentProjectChanged: AnyCancellable {
        manager.$currentProject
            .sink {
                self.currentProject = $0
                self.setBalances()
            }
    }

    /// Delegates to `StatisticsEngine` so this screen and the Statistics tab can
    /// never disagree about what someone owes. The formula is unchanged: a bill
    /// is split equally between its owers, and balance = paid − owed.
    func setBalances() {
        balances = StatisticsEngine
            .memberStatistics(bills: currentProject.bills, members: currentProject.members)
            .map { Balance(id: $0.person.id, amount: $0.balance, person: $0.person) }
    }
}

struct Balance: Identifiable {
    let id: Int
    var amount: Double
    let person: Person
}
