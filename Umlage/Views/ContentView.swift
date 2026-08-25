//
//  ContentView.swift
//  Umlage
//
//  Created by Max Tharr on 21.01.20.
//

import Foundation
import SwiftUI

struct ContentView: View {
    @ObservedObject
    var manager = ProjectManager.shared

    @StateObject
    private var billListViewModel = BillListViewModel()

    @StateObject
    private var balanceViewModel = BalanceViewModel()

    @StateObject
    private var statisticsViewModel = StatisticsViewModel()

    @Environment(\.scenePhase)
    private var scenePhase

    @State
    var tabBarIndex = tabBarItems.BillList

    @State
    var showModal = false

    @State
    var hidePlusButton = false

    var body: some View {
        // Everything below resolves its colours from the theme this container
        // injects, so a theme or light/dark change restyles the whole app.
        PFMThemedContainer {
            ZStack {
                if !manager.projects.isEmpty {
                    tabBar
                } else {
                    OnboardingView()
                }
            }
            .sheet(item: $manager.openedByURL) { url in
                PFMThemedContainer {
                    AddFromURLView(viewmodel: AddProjectQRViewModel(openedByURL: url))
                }
            }
            .onChange(of: scenePhase) { newPhase in
                if newPhase == .active && !manager.projects.isEmpty {
                    manager.loadBillsAndMembers()
                }
            }
        }
    }

    var tabBar: some View {
        TabView(selection: $tabBarIndex) {
            BillList(viewModel: billListViewModel)
                .tabItem {
                    Label("Bills", systemImage: "rectangle.stack")
                }
                .tag(tabBarItems.BillList)
            StatisticsView(viewModel: statisticsViewModel)
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.xaxis")
                }
                .tag(tabBarItems.Statistics)
            BalanceList(viewModel: balanceViewModel)
                .tabItem {
                    Label("Members", systemImage: "arrow.right.arrow.left")
                }
                .tag(tabBarItems.Balance)
            ProjectList()
                .tabItem {
                    Label("Projects", systemImage: "gear")
                }
                .tag(tabBarItems.ServerList)
        }
        .glassTabBarMinimize()
        // The statistics screen keeps its own snapshot of the project, so it has
        // to recompute when bills arrive from a refresh on another tab.
        .onReceive(manager.$currentProject) { _ in
            statisticsViewModel.recompute()
        }
    }
}

enum tabBarItems: Int {
    case ServerList
    case BillList
    case Balance
    case Statistics
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        previewProjects.forEach {
            try! ProjectManager.shared.addProject($0)
        }
        ProjectManager.shared.currentProject = previewProject
        return ContentView()
    }
}
