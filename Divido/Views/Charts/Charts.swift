//
//  Charts.swift
//  Divido
//
//  The monthly trend uses Swift Charts. The other three are deliberately not
//  charts in the Swift Charts sense — see the note on each — and stay built from
//  SwiftUI primitives.
//
//  Form choices follow the data's job rather than what looks impressive:
//    · monthly spend  -> column chart, ONE hue (magnitude over time)
//    · who paid what  -> ranked horizontal bars, ONE hue (magnitude, not identity)
//    · balances       -> diverging bars around a zero baseline (polarity)
//    · categories     -> horizontal stacked share bar (part-to-whole), NOT a pie
//
//  Every chart carries visible direct labels: in light mode several of the
//  categorical hues sit below 3:1 against white, and a labelled value is the
//  documented relief for that.
//

import Charts
import SwiftUI

// MARK: - Column chart (monthly trend)

/// Spend per month. A single series, so it takes one hue and needs no legend —
/// the section title names it. The peak column is emphasised and labelled
/// directly, which is the one number a reader actually wants off this chart.
struct PFMColumnChart: View {
    @Environment(\.pfmTheme) private var theme

    let buckets: [PeriodBucket]
    let currency: String?
    var height: CGFloat = 168

    private static let monthYearLabel: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter
    }()

    /// The highest-spending month, ignoring a run of empty months.
    private var peak: PeriodBucket? {
        guard let candidate = buckets.max(by: { $0.total < $1.total }), candidate.total > 0 else { return nil }
        return candidate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let peak = peak {
                Text("stats_peak_label \(MoneyFormatter.string(peak.total, currency: currency)) \(Self.monthYearLabel.string(from: peak.start))")
                    .font(.caption)
                    .foregroundColor(theme.palette.textSecondary)
            }

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("month", bucket.start, unit: .month),
                    y: .value("total", bucket.total)
                )
                // Emphasis rather than categorical colour: one series, one hue,
                // with the peak carrying full saturation.
                .foregroundStyle(bucket.id == peak?.id
                                 ? theme.palette.accent
                                 : theme.palette.accent.opacity(0.42))
                .cornerRadius(4)
            }
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(theme.palette.separator)
                    AxisValueLabel {
                        if let amount = value.as(Double.self) {
                            Text(MoneyFormatter.abbreviated(amount, currency: currency))
                                .font(.system(size: 9))
                                .foregroundColor(theme.palette.textTertiary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .month)) { _ in
                    AxisValueLabel(format: .dateTime.month(.narrow))
                        .font(.system(size: 9))
                        .foregroundStyle(theme.palette.textTertiary)
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Ranked bars (who paid / who spent)

struct PFMRankedBarRow: Identifiable {
    let id: Int
    let person: Person
    let value: Double
    /// 0...1 relative to the largest row.
    let fraction: Double
}

/// Horizontal magnitude comparison. Deliberately one hue: the members already
/// carry identity through their avatars, and a 12-member project would blow past
/// any categorical palette's ceiling.
///
/// Not a `Chart`: the avatar per row is the point, and Swift Charts cannot put
/// arbitrary views on a category axis without giving up the list idiom.
struct PFMRankedBarList: View {
    @Environment(\.pfmTheme) private var theme

    let rows: [PFMRankedBarRow]
    let currency: String?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows) { row in
                HStack(spacing: 10) {
                    PFMAvatar(person: row.person, size: 30)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(row.person.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(theme.palette.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(MoneyFormatter.string(row.value, currency: currency))
                                .font(Font.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundColor(theme.palette.textPrimary)
                        }
                        PFMShareBar(fraction: row.fraction, tint: theme.palette.accent)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

// MARK: - Diverging bars (balances)

/// Who is up and who is down, around a shared zero line. Diverging colour: the
/// positive/negative status pair with the baseline as the neutral midpoint.
///
/// Not a `Chart`, for the same reason as the ranked bars: these are list rows
/// that happen to contain a bar, not a plot.
struct PFMDivergingBarList: View {
    @Environment(\.pfmTheme) private var theme

    let entries: [MemberStatistics]
    let currency: String?

    /// Both arms are scaled by the same magnitude so a +40 bar and a −40 bar are
    /// drawn the same length. Scaling each side to its own max would make small
    /// debts look like large ones.
    private var scale: Double {
        max(entries.map { abs($0.balance) }.max() ?? 0, 0.01)
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(entries) { entry in
                HStack(spacing: 10) {
                    PFMAvatar(person: entry.person, size: 30)

                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(entry.person.name)
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(theme.palette.textPrimary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(MoneyFormatter.signed(entry.balance, currency: currency))
                                .font(Font.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundColor(theme.moneyColor(entry.balance))
                        }
                        divergingBar(for: entry.balance)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(entry.person.name): \(MoneyFormatter.signed(entry.balance, currency: currency))"))
            }
        }
    }

    private func divergingBar(for balance: Double) -> some View {
        GeometryReader { geometry in
            let half = geometry.size.width / 2
            let length = CGFloat(min(1, abs(balance) / scale)) * half

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.palette.surfaceElevated)
                    .frame(height: 6)

                // The zero line is drawn on top of the track so it stays visible
                // when a bar is only a few points long.
                Rectangle()
                    .fill(theme.palette.separator)
                    .frame(width: 1, height: 12)
                    .offset(x: half - 0.5)

                Capsule()
                    .fill(balance >= 0 ? theme.palette.positive : theme.palette.negative)
                    .frame(width: max(length, balance == 0 ? 0 : 3), height: 6)
                    .offset(x: balance >= 0 ? half : half - max(length, 3))
            }
            .frame(height: 12)
        }
        .frame(height: 12)
    }
}

// MARK: - Stacked share bar (categories)

struct PFMShareSegment: Identifiable {
    let id: Int
    let label: String
    /// Emoji from the server; may be empty.
    let icon: String
    let value: Double
    let fraction: Double
    let color: Color
}

/// Part-to-whole as a horizontal stacked bar plus a labelled legend — the form
/// the reader can actually compare, unlike a pie. Segments are separated by a
/// 2 pt surface-coloured gap so neighbouring hues never touch.
///
/// Not a `Chart`: Swift Charts stacks marks flush against each other, and that
/// gap is what keeps two adjacent palette hues from reading as one block. The
/// legend also carries the server's category emoji, amount and share, which is
/// more than `chartLegend` can render.
struct PFMStackedShareBar: View {
    @Environment(\.pfmTheme) private var theme

    let segments: [PFMShareSegment]
    let currency: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    ForEach(segments) { segment in
                        // A hairline minimum keeps a 0.2 % category from
                        // vanishing entirely and leaving a gap in the bar.
                        Rectangle()
                            .fill(segment.color)
                            .frame(width: max(3, CGFloat(segment.fraction) * (geometry.size.width - CGFloat(max(0, segments.count - 1)) * 2)))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .frame(height: 14)

            VStack(spacing: 9) {
                ForEach(segments) { segment in
                    HStack(spacing: 9) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(segment.color)
                            .frame(width: 11, height: 11)

                        Text(segment.icon.isEmpty ? segment.label : "\(segment.icon)  \(segment.label)")
                            .font(.subheadline)
                            .foregroundColor(theme.palette.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text(MoneyFormatter.percent(segment.fraction))
                            .font(Font.caption.monospacedDigit())
                            .foregroundColor(theme.palette.textTertiary)

                        Text(MoneyFormatter.string(segment.value, currency: currency))
                            .font(Font.subheadline.weight(.medium).monospacedDigit())
                            .foregroundColor(theme.palette.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
