//
//  BillCell.swift
//  Umlage
//
//  Created by Max Tharr on 22.01.20.
//

import SwiftUI

/// One expense in the bill list, drawn as a card rather than a table row.
///
/// The layout puts the two things people scan for — what it was and how much —
/// on the outer edges, with the payer's avatar anchoring the row and the owers
/// stacked underneath.
struct BillCell: View {
    @Environment(\.pfmTheme) private var theme

    @ObservedObject
    var viewModel: BillListViewModel

    let bill: Bill

    private var payer: Person {
        viewModel.currentProject.members[bill.payer_id]
            ?? Person(id: bill.payer_id, weight: 1, name: NSLocalizedString("Unknown", comment: "Unknown payer"), activated: true)
    }

    /// Owers resolved against the member list so they pick up server colours and
    /// current names rather than whatever was embedded in the bill payload.
    private var owers: [Person] {
        bill.owers.map { viewModel.currentProject.members[$0.id] ?? $0 }
    }

    private var currency: String? {
        viewModel.currentProject.currencyName.isEmpty ? nil : viewModel.currentProject.currencyName
    }

    private var perPersonShare: Double? {
        guard bill.owers.count > 1 else { return nil }
        return bill.amount / Double(bill.owers.count)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PFMAvatar(person: payer, size: 42)

            VStack(alignment: .leading, spacing: 6) {
                Text(bill.what.isEmpty
                     ? NSLocalizedString("stats_untitled_bill", comment: "Bill with an empty description")
                     : bill.what)
                    .font(.headline)
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(payer.name)
                        .font(.caption.weight(.medium))
                        .foregroundColor(theme.palette.textSecondary)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(theme.palette.textTertiary)
                    PFMAvatarStack(people: owers, size: 22, maxVisible: 5)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text(MoneyFormatter.string(bill.amount, currency: currency))
                    .font(Font.system(.headline, design: .rounded).monospacedDigit())
                    .foregroundColor(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(DateFormatter.cospendCompact.string(from: bill.date))
                    .font(.caption2)
                    .foregroundColor(theme.palette.textTertiary)

                if let share = perPersonShare {
                    Text("bill_share_each \(MoneyFormatter.string(share, currency: currency))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(theme.palette.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct BillCell_Previews: PreviewProvider {
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
