import Charts
import DesignSystem
import SwiftUI

struct StatisticsBarChart: View {
    let buckets: [StatisticsSummary.Bucket]
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let maximum = max(1, buckets.map(\.count).max() ?? 0)
        Chart(buckets) { bucket in
            BarMark(x: .value("Day", String(bucket.id)), y: .value("Completions", bucket.count), width: .ratio(0.65))
                .cornerRadius(5)
                .foregroundStyle(bucket.count == maximum ? DWColor.accent(colorScheme) : DWColor.accent(colorScheme).opacity(0.65))
                .annotation(position: .top) {
                    Text(bucket.count, format: .number)
                        .font(.caption2)
                        .foregroundStyle(DWColor.secondary(colorScheme))
                }
                .accessibilityLabel(bucket.accessibilityLabel)
                .accessibilityValue("\(bucket.count) completed tasks")
        }
        .chartXScale(domain: buckets.map { String($0.id) })
        .chartYScale(domain: 0...(Double(maximum) * 1.5))
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: buckets.map { String($0.id) }) { value in
                AxisValueLabel {
                    if let id = value.as(String.self), let bucket = buckets.first(where: { String($0.id) == id }) {
                        Text(bucket.label).font(.caption2)
                    }
                }
            }
        }
        .frame(height: dynamicTypeSize.isAccessibilitySize ? 160 : 88)
        .accessibilityLabel("Completed tasks by day")
    }
}

/// Read-only receipts for overview cards. Task editing remains in its own feature.
struct StatisticsDetailView: View {
    let destination: StatisticsDestination
    let summary: StatisticsSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        switch destination {
        case .about: "How insights work"
        case .hour: "Your top hour"
        case .weekday: "Your daily activity"
        case .habits: "Your habits"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if destination != .about {
                        Text(summary.rangeLabel).font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
                    }
                    switch destination {
                    case .about: about
                    case .hour:
                        Text("\(summary.timedCompletionCount) same-day check-ins").font(.title2.bold())
                        Text("Check-in times in your current time zone. Only tasks marked done on their scheduled day are included; retrospective marks have no known completion hour. Each bar represents one hour, not time spent working.")
                        Chart(summary.hours) { hour in
                            BarMark(x: .value("Hour", hour.id), y: .value("Completions", hour.count))
                                .foregroundStyle(DWColor.accent(colorScheme))
                                .accessibilityLabel(hour.label)
                                .accessibilityValue("\(hour.count) completions")
                        }
                        .chartXScale(domain: -0.5...23.5)
                        .chartXAxis { AxisMarks(values: [0, 6, 12, 18, 23]) }
                        .frame(height: 220)
                        ForEach(summary.hours.filter { $0.count > 0 }) { hour in
                            LabeledContent(hour.label, value: "\(hour.count)")
                        }
                    case .weekday:
                        StatisticsBarChart(buckets: summary.bars).frame(minHeight: 160)
                        ForEach(summary.bars) { day in
                            LabeledContent(day.accessibilityLabel, value: "\(day.count)")
                        }
                        if summary.hasWeekdayPattern {
                            Text("Average per weekday").font(.title2.bold())
                            Text("Includes days with no check-ins.").font(.subheadline)
                            ForEach(summary.weekdays) { day in
                                LabeledContent(day.accessibilityLabel,
                                               value: summary.weekdayAverage(day.id).formatted(.number.precision(.fractionLength(1))))
                            }
                        }
                    case .habits:
                        Text("Recorded completions through yesterday. All time counts include the full saved history of each active habit.")
                            .font(.subheadline)
                        ForEach(summary.habits) { habit in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(habit.title).font(.headline)
                                Text("\(habit.count) in this period · \(habit.lifetimeCount) all time")
                                    .font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
                            }
                            .statisticsCard()
                        }
                    }
                }
                .padding(20)
            }
            .background(DWColor.bg(colorScheme))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(DWColor.accent(colorScheme))
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 24) {
            explanation("Facts with context", icon: "chart.bar", text: "Every insight shows its time period and the activity behind it. Tap a card to see the numbers.")
            explanation("The right window", icon: "calendar", text: "Totals and daily patterns use the day each task belongs to, ending yesterday. Marking a past task done updates that day, even when you check it off later. Today’s tasks appear tomorrow. Hour patterns use same-day check-in times in your current time zone; retrospective marks are excluded.")
            explanation("Each check-in counts once", icon: "checkmark.circle", text: "Skipped tasks do not count as completions. Undoing a check-in removes it. Habit cards show completion counts; consistency rates need a reliable history of planned sessions.")
            explanation("Private by design", icon: "lock", text: "Your statistics are calculated on device and work offline.")
            Text("“Marked done” is not a measure of your worth, effort, or time spent working.")
                .font(.footnote).foregroundStyle(DWColor.secondary(colorScheme))
        }
    }

    private func explanation(_ title: String, icon: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon).font(.headline)
            Text(text).font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
        }
    }
}
