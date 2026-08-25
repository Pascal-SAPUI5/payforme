//
//  ProjectListEntry.swift
//  Divido
//
//  Created by Max Tharr on 08.02.23.
//  Copyright © 2023 Mayflower GmbH. All rights reserved.
//

import SwiftUI

struct ProjectListEntry: View {
    @Environment(\.pfmTheme) private var theme

    let project: Project
    let manager = ProjectManager.shared
    let currentProject: Project

    @Binding var shareProject: Project?

    @State var edit = false
    @State var me = 0

    private var isCurrent: Bool { project == currentProject }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Tapping the row body activates the project; the trailing
                // buttons keep their own tap targets, which is why this is a
                // button around the label rather than around the whole row.
                Button {
                    manager.setCurrentProject(project)
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isCurrent ? theme.palette.accent : theme.palette.surfaceElevated)
                                .frame(width: 36, height: 36)
                            Image(systemName: isCurrent ? "checkmark" : "folder.fill")
                                .font(.footnote.weight(.bold))
                                .foregroundColor(isCurrent ? theme.palette.onAccent : theme.palette.textSecondary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(project.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(isCurrent ? theme.palette.accent : theme.palette.textPrimary)
                                .lineLimit(1)
                            Text(project.backend == .cospend ? "Cospend" : "iHateMoney")
                                .font(.caption)
                                .foregroundColor(theme.palette.textTertiary)
                        }

                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isCurrent {
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { self.edit.toggle() }
                    } label: {
                        Image(systemName: "pencil")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(theme.palette.accent)
                            .frame(width: 30, height: 30)
                            .background(theme.palette.accentMuted)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Add a default payer for new bills (e.g. yourself)"))
                }

                if project.backend == .cospend {
                    Button {
                        self.shareProject = project
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.footnote.weight(.bold))
                            .foregroundColor(theme.palette.textSecondary)
                            .frame(width: 30, height: 30)
                            .background(theme.palette.surfaceElevated)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Invite Link"))
                }
            }

            if edit {
                VStack(alignment: .leading, spacing: 8) {
                    Divider().background(theme.palette.separator)
                    Text("Add a default payer for new bills (e.g. yourself)")
                        .font(.caption)
                        .foregroundColor(theme.palette.textSecondary)
                    WhoPaidView(members: Array(project.members.values), selectedPayer: self.$me)
                }
            }
        }
        .onAppear {
            me = project.me ?? 0
        }
        .onChange(of: me) { newValue in
            project.me = newValue
            manager.updateProject(project: project)
            edit = false
        }
    }
}

struct ProjectListEntry_Previews: PreviewProvider {
    static var previews: some View {
        previewProject.members = previewManyPersons
        return PFMThemedContainer {
            List {
                ProjectListEntry(project: previewProject, currentProject: previewProject, shareProject: .constant(nil))
            }
        }
    }
}
