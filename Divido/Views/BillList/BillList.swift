//
//  BillsList.swift
//  Divido
//
//  Created by Max Tharr on 26.01.20.
//

import SwiftUI

struct BillList: View {
    @Environment(\.pfmTheme) private var theme

    @ObservedObject
    var viewModel: BillListViewModel

    @State
    var deleteAlert: IndexSet?

    @State
    private var showAddBill = false

    @State
    private var showScan = false

    private var currency: String? {
        viewModel.currentProject.currencyName.isEmpty ? nil : viewModel.currentProject.currencyName
    }

    /// Total of everything currently listed — the number people open the tab for.
    private var total: Double {
        viewModel.sortedBills.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationView {
            ZStack {
                PFMBackground()

                // `List` is kept (rather than a LazyVStack) because swipe-to-delete
                // and its confirmation flow come for free and are already covered
                // by the delete tests.
                List {
                    header
                    billRows
                }
                .listStyle(InsetGroupedListStyle())
                .scrollContentBackground(.hidden)
                .refreshable {
                    await ProjectManager.shared.refresh()
                }
            }
            .navigationTitle("Bills")
            .glassActionButton(systemImage: "bag",
                               accessibilityLabel: "Add Bill",
                               accessibilityIdentifier: "Add Bill") {
                showAddBill = true
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showScan = true }) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.title3.weight(.semibold))
                        .frame(width: 48, height: 48)
                }
                .glassCircleStyle()
                .accessibilityLabel(Text("scan_title"))
                .accessibilityIdentifier("Scan Receipt")
                .padding(.trailing, 24)
                .padding(.bottom, 88)
            }
            .sheet(isPresented: $showAddBill) {
                PFMThemedContainer {
                    AddBillView(showModal: $showAddBill)
                }
            }
            .sheet(isPresented: $showScan) {
                PFMThemedContainer {
                    ScanReceiptView(participants: sortedMembers, currency: currency) { drafts, date in
                        createBills(from: drafts, on: date)
                    }
                }
            }
            .alert(item: $deleteAlert) { index in
                Alert(title: Text("Delete Bill"),
                      message: Text("Do you really want to erase the bill from the server?"),
                      primaryButton: .destructive(Text("Sure")) {
                          self.deleteBill(at: index)
                      },
                      secondaryButton: .cancel())
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    private var header: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("bills_total")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.6)
                        .foregroundColor(theme.palette.textSecondary)
                    Text(MoneyFormatter.string(total, currency: currency))
                        .font(Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                        .foregroundColor(theme.palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Spacer()
                PFMChip(text: viewModel.currentProject.name, systemImage: "folder.fill")
            }

            PFMSegmentedControl(selection: $viewModel.sortBy,
                                options: [.expenseDate, .changedDate]) { option in
                option == .expenseDate ? "Expense date" : "Changed date"
            }
        }
        .pfmCard()
        .pfmCardRow()
    }

    @ViewBuilder
    private var billRows: some View {
        if viewModel.sortedBills.isEmpty {
            PFMEmptyState(systemImage: "tray",
                          titleKey: "bills_empty_title",
                          messageKey: "bills_empty_message")
                .pfmCard()
                .pfmCardRow()
        } else {
            ForEach(viewModel.sortedBills) { bill in
                ZStack {
                    BillCell(viewModel: self.viewModel, bill: bill)
                    // A plain NavigationLink would paint its own disclosure
                    // chevron and highlight over the card; hiding it behind the
                    // cell keeps the tap target without the chrome.
                    NavigationLink(destination:
                        BillDetailView(showModal: .constant(false),
                                       viewModel: BillDetailViewModel(currentBill: bill),
                                       navBarTitle: "Edit Bill",
                                       sendButtonTitle: "Update Bill")) {
                        EmptyView()
                    }
                    .opacity(0)
                }
                .pfmCard()
                .pfmCardRow()
            }
            .onDelete(perform: { offset in
                self.deleteAlert = offset
            })
        }
    }

    func deleteBill(at offsets: IndexSet) {
        for offset in offsets {
            guard let bill = viewModel.sortedBills[safe: offset] else {
                return
            }
            ProjectManager.shared.deleteBill(bill, completion: {
                ProjectManager.shared.loadBillsAndMembers()
            })
        }
    }

    private var sortedMembers: [Person] {
        Array(viewModel.currentProject.members.values)
            .sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Legt die Rechnungen des Bons an.
    ///
    /// Streng nacheinander, weil ProjectManager genau eine Cancellable haelt
    /// und ein zweiter Aufruf den ersten abbricht. Parallel abgeschickt ginge
    /// alles ausser der letzten Rechnung still verloren.
    private func createBills(from drafts: [BillDraft], on date: Date) {
        let project = viewModel.currentProject
        let bills = ReceiptBillBuilder.bills(from: drafts,
                                             payerID: project.me ?? 0,
                                             date: date,
                                             members: sortedMembers,
                                             backend: project.backend)

        ReceiptBillBuilder.post(bills, using: { bill, done in
            ProjectManager.shared.saveBill(bill, completion: done)
        }, completion: {
            Task { await ProjectManager.shared.refresh() }
        })
    }
}

extension IndexSet: Identifiable {
    public var id: Int {
        hashValue
    }
}

struct BillList_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = BillListViewModel()
        previewProject.bills = previewBills
        previewProject.members = previewPersons
        viewModel.currentProject = previewProject
        return PFMThemedContainer {
            BillList(viewModel: viewModel)
        }
    }
}
