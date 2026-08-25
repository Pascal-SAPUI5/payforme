//
//  BalanceList.swift
//  Umlage
//
//  Created by Max Tharr on 29.01.20.
//

import SwiftUI

struct BalanceList: View {
    @Environment(\.pfmTheme) private var theme

    @ObservedObject
    var viewModel: BalanceViewModel

    @State
    var addingUser = false

    @State
    var memberName = ""

    @State
    private var memberAddError: MemberAddError?

    var body: some View {
        NavigationView {
            ZStack {
                PFMBackground()
                list
            }
                .navigationTitle("Members")
                .glassActionButton(systemImage: "person.fill",
                                   accessibilityLabel: "Add member",
                                   accessibilityIdentifier: "Add member") {
                    showAddUser()
                }
                .sheet(isPresented: $addingUser) {
                    PFMThemedContainer {
                        AddMemberView(memberName: $memberName,
                                      addMemberAction: submitUser,
                                      cancelButtonAction: cancelAddUser)
                            .alert(item: $memberAddError) { error in
                                Alert(title: Text("Could not add member"),
                                      message: Text(memberErrorMessage(for: error.code)),
                                      dismissButton: .default(Text("OK")))
                            }
                    }
                }
        }.navigationViewStyle(StackNavigationViewStyle())
    }

    /// Sum of everything owed, i.e. how far the project is from settled.
    private var outstanding: Double {
        viewModel.balances.filter { $0.amount > 0 }.reduce(0) { $0 + $1.amount }
    }

    private var currency: String? {
        viewModel.currentProject.currencyName.isEmpty ? nil : viewModel.currentProject.currencyName
    }

    @ViewBuilder
    var list: some View {
        List {
            summaryHeader

            ForEach(viewModel.balances.sorted(by: balanceSort(_:_:))) {
                balance in
                if balance.amount < 0 {
                    // Only debtors get a tappable row: tapping one opens a
                    // prefilled bill that settles them up.
                    ZStack {
                        BalanceCell(balance: balance, currency: currency)
                        NavigationLink(destination: BillDetailView(showModal: .constant(false), viewModel: BillDetailViewModel(currentBill: self.createSettlingBill(balance: balance)))) {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .pfmCard()
                    .pfmCardRow()
                } else {
                    BalanceCell(balance: balance, currency: currency)
                        .pfmCard()
                        .pfmCardRow()
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
        .refreshable {
            await ProjectManager.shared.refresh()
        }
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("balances_outstanding")
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.6)
                .foregroundColor(theme.palette.textSecondary)
            Text(MoneyFormatter.string(outstanding, currency: currency))
                .font(Font.system(.title2, design: .rounded).weight(.bold).monospacedDigit())
                // Outstanding debt is shown as a negative signal even though the
                // number itself is positive, so it reads red until it hits zero.
                .foregroundColor(outstanding > 0.005 ? theme.palette.negative : theme.palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(outstanding > 0.005
                 ? LocalizedStringKey("balances_outstanding_hint")
                 : LocalizedStringKey("stats_all_settled"))
                .font(.caption)
                .foregroundColor(theme.palette.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .pfmCard()
        .pfmCardRow()
    }

    func balanceSort(_ a: Balance, _ b: Balance) -> Bool {
        (a.amount > b.amount) || ((a.amount == b.amount) && (a.person.name < b.person.name))
    }

    func showAddUser() {
        addingUser = true
    }

    func submitUser() {
        ProjectManager.shared.addMember(memberName) { statusCode in
            if (200 ... 299).contains(statusCode) {
                self.addingUser = false
                self.memberName = ""
                ProjectManager.shared.loadBillsAndMembers()
            } else {
                // Keep the sheet open so the user keeps their input and can retry.
                self.memberAddError = MemberAddError(code: statusCode)
            }
        }
    }

    private func memberErrorMessage(for code: Int) -> String {
        switch code {
        case 401, 403:
            return NSLocalizedString("member_error_forbidden", comment: "Member add failed due to insufficient rights")
        case -1:
            return NSLocalizedString("member_error_network", comment: "Member add failed due to a network error")
        default:
            return String(format: NSLocalizedString("member_error_generic", comment: "Member add failed with HTTP status code"), code)
        }
    }

    func cancelAddUser() {
        memberName = ""
        addingUser = false
    }

    func createSettlingBill(balance: Balance) -> Bill {
        let ower = viewModel.balances.sorted(by: { $0.amount > $1.amount })[0]
        let payer = balance.person
        let topic = "Settling balance for \(balance.person.name)"
        let amount = ower.amount.magnitude < balance.amount.magnitude ? ower.amount : balance.amount.magnitude
        return Bill(id: -1, amount: amount, what: topic, date: Date(), payer_id: payer.id, owers: [ower.person], repeat: "n")
    }
}

struct MemberAddError: Identifiable {
    let code: Int
    var id: Int { code }
}

struct BalanceList_Previews: PreviewProvider {
    static var previews: some View {
        let vm = BalanceViewModel()
        vm.currentProject = previewProject
        vm.setBalances()
        return PFMThemedContainer {
            BalanceList(viewModel: vm, addingUser: false)
        }
    }
}

struct BalanceCell: View {
    @Environment(\.pfmTheme) private var theme

    let balance: Balance
    var currency: String?

    private var balanceCaption: LocalizedStringKey {
        if balance.amount > 0.005 { return "balance_is_owed" }
        if balance.amount < -0.005 { return "balance_owes" }
        return "balance_settled"
    }

    var body: some View {
        HStack(spacing: 12) {
            PFMAvatar(person: balance.person, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(balance.person.name)
                    .font(.headline)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)
                Text(balanceCaption)
                    .font(.caption)
                    .foregroundColor(theme.palette.textTertiary)
            }

            Spacer(minLength: 8)

            Text(MoneyFormatter.signed(balance.amount, currency: currency))
                .font(Font.system(.headline, design: .rounded).monospacedDigit())
                .foregroundColor(theme.moneyColor(balance.amount))
        }
        .accessibilityElement(children: .combine)
    }
}
