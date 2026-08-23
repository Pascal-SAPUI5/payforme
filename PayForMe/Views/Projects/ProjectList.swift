//
//  ServerList.swift
//  PayForMe
//
//  Created by Max Tharr on 22.01.20.
//

import AVFoundation
import SwiftUI

struct ProjectList: View {
    @Environment(\.pfmTheme) private var theme

    @ObservedObject
    var manager = ProjectManager.shared

    @State private var showAddProject = false
    @State private var shareProject: Project?

    var body: some View {
        NavigationView {
            ZStack {
                PFMBackground()

                List {
                    Section {
                        NavigationLink(destination: AppearanceSettingsView()) {
                            HStack(spacing: 12) {
                                Image(systemName: "paintbrush.pointed.fill")
                                    .font(.footnote.weight(.bold))
                                    .foregroundColor(theme.palette.accent)
                                    .frame(width: 32, height: 32)
                                    .background(theme.palette.accentMuted)
                                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("appearance_title")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(theme.palette.textPrimary)
                                    Text("appearance_row_subtitle")
                                        .font(.caption)
                                        .foregroundColor(theme.palette.textSecondary)
                                }
                            }
                        }
                        .pfmCard()
                        .pfmCardRow()
                    }

                    // The `Section { } header: { }` spelling maps to
                    // `init(content:header:)`; this older form is unambiguously
                    // available on the iOS 15 deployment target.
                    Section(header: PFMSectionHeader(titleKey: "Known Projects")
                        .padding(.bottom, 2)) {
                        ForEach(manager.projects) { project in
                            ProjectListEntry(project: project,
                                             currentProject: manager.currentProject,
                                             shareProject: self.$shareProject)
                                .pfmCard()
                                .pfmCardRow()
                        }
                        .onDelete(perform: deleteProject)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
                .sheet(item: $shareProject) { project in
                    PFMThemedContainer {
                        ShareProjectQRCode(project: project)
                    }
                }
            }
            .navigationTitle("Projects")
            .glassActionButton(systemImage: "folder",
                               accessibilityLabel: "Add project",
                               accessibilityIdentifier: "Add project") {
                showAddProject = true
            }
            .sheet(isPresented: $showAddProject) {
                PFMThemedContainer {
                    AddProjectManualView()
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    func deleteProject(at offsets: IndexSet) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500)) {
            for index in offsets {
                manager.deleteProject(manager.projects[index])
            }
        }
    }
}

struct ServerList_Previews: PreviewProvider {
    static var previews: some View {
        PFMThemedContainer {
            ProjectList()
        }
    }
}
