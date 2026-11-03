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

/// Every insight links to the recorded activity behind it and an optional reviewed action.
struct StatisticsDetailView: View {
    let destination: StatisticsDestination
    let summary: StatisticsSummary
    var planTask: (Int) -> Void = { _ in }
    var editHabit: (UUID) -> Void = { _ in }
    @Environment(\.colorScheme) private var colorScheme

    private var title: String {
        switch destination {
        case .about: "How insights work"
        case .hour: "Your top hour"
        case .weekday: summary.hasWeekdayPattern ? "Your weekly rhythm" : "Your daily activity"
        case .habits: "Your habits"
        case .habit(let id): summary.habits.first { $0.id == id }?.title ?? "Habit"
        case .activity: "Recorded activity"
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if destination != .about {
                    Text(windowLabel).font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
                }
                switch destination {
                case .about: about
                case .hour: hour
                case .weekday: weekday
                case .habits: habits
                case .habit(let id): habit(id)
                case .activity(let filter): activity(filter)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .background(DWColor.bg(colorScheme))
        .foregroundStyle(DWColor.label)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .tint(DWColor.accent(colorScheme))
    }

    @ViewBuilder
    private var actionBar: some View {
        if case .hour = destination, let top = summary.topHour {
            primaryAction("Plan a task at \(summary.hourLabel(top.id))", id: "statistics.planTask") {
                planTask(top.id)
            }
        } else if case .habit(let id) = destination, summary.habits.contains(where: { $0.id == id }) {
            primaryAction("Adjust this habit", id: "statistics.editHabit") { editHabit(id) }
        }
    }

    private func primaryAction(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .foregroundStyle(.white)
        .accessibilityIdentifier(id)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(DWColor.bg(colorScheme))
    }

    private var windowLabel: String {
        switch destination {
        case .habit, .activity(.habit): "All recorded history · Through yesterday"
        default: summary.rangeLabel
        }
    }

    private var hour: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let top = summary.topHour {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "sun.max").font(.title2).accessibilityHidden(true)
                    Text(top.label).font(.largeTitle.bold())
                    Text("\(top.count) of \(summary.timedCompletionCount) same-day check-ins")
                        .font(.headline)
                    Text("were marked done in this hour\(summary.hourIsTied ? ", one of your top hours" : "").")
                        .font(.subheadline)
                    hourChart
                }
                .foregroundStyle(DWColor.lilacLabel)
                .statisticsCard(DWColor.lilacBg)
                explanation("A pattern worth trying", text: "Consider placing one flexible task here. Treat this as an experiment, not a rule.")
                Label("Based on when you tap Done on the task’s day. This does not measure focus or effort. Retrospective marks count in totals but have no known completion hour.", systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(DWColor.secondary(colorScheme))
                    .statisticsCard()

            } else {
                Text("Your rhythm is taking shape").font(.title2.bold())
                hourChart
            }
        }
    }

    private var hourChart: some View {
        Chart(summary.hours) { hour in
            BarMark(x: .value("Hour", hour.id), y: .value("Check-ins", hour.count))
                .cornerRadius(3)
                .foregroundStyle(DWColor.accent(colorScheme).opacity(hour.id == summary.topHour?.id ? 1 : 0.55))
                .annotation(position: .top) {
                    if hour.id == summary.topHour?.id { Text(hour.count, format: .number).font(.caption) }
                }
                .accessibilityLabel(hour.label)
                .accessibilityValue("\(hour.count) check-ins")
        }
        .chartXScale(domain: -0.5...23.5)
        .chartYScale(domain: 0...Double(max(1, summary.hours.map(\.count).max() ?? 0)) * 1.4)
        .chartYAxis(.hidden)
        .chartXAxis {
            AxisMarks(values: [0, 6, 12, 18]) { value in
                AxisValueLabel {
                    if let hour = value.as(Int.self) { Text(summary.hourLabel(hour)).font(.caption2) }
                }
            }
        }
        .frame(height: 160)
        .accessibilityLabel("\(summary.timedCompletionCount) same-day check-ins across 24 one-hour bins")
    }

    @ViewBuilder
    private var weekday: some View {
        if let top = summary.topWeekdayIndex {
            VStack(alignment: .leading, spacing: 16) {
                Text("\(summary.weekdays[top].accessibilityLabel) \(summary.weekdayIsTied ? "is one of your top weekdays" : "stands out")")
                    .font(.title2.bold())
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        average(top).font(.largeTitle.bold()).foregroundStyle(DWColor.accent(colorScheme))
                        Text("tasks per \(summary.weekdays[top].accessibilityLabel), on average").font(.subheadline)
                    }
                    VStack(alignment: .leading) {
                        average(top).font(.largeTitle.bold()).foregroundStyle(DWColor.accent(colorScheme))
                        Text("tasks per \(summary.weekdays[top].accessibilityLabel), on average").font(.subheadline)
                    }
                }
                ForEach(summary.weekdays) { day in
                    HStack(spacing: 12) {
                        Text(day.label).frame(width: 40, alignment: .leading)
                        GeometryReader { geometry in
                            Capsule().fill(DWColor.bg(colorScheme))
                            Capsule().fill(DWColor.accent(colorScheme).opacity(day.id == top ? 1 : 0.6))
                                .frame(width: geometry.size.width * summary.weekdayAverage(day.id) / max(1, summary.weekdayAverage(top)))
                        }
                        .frame(height: 20)
                        average(day.id).frame(minWidth: 34, alignment: .trailing)
                    }
                    .font(.subheadline)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(day.accessibilityLabel)
                    .accessibilityValue("\(summary.weekdayAverage(day.id).formatted(.number.precision(.fractionLength(1)))) tasks on average")
                }
            }
            .statisticsCard()
            explanation("An average, not a target", text: "\(summary.weekdays[top].count) tasks across \(summary.weekdayOccurrences[top]) occurrences of \(summary.weekdays[top].accessibilityLabel) in this period, including days with no completions.")
            Text("Counts describe check-ins, not task difficulty.")
                .font(.footnote).foregroundStyle(DWColor.secondary(colorScheme))
            activityLink("View \(summary.weekdays[top].accessibilityLabel) activity", filter: .weekday(top))
        } else {
            StatisticsBarChart(buckets: summary.bars).frame(minHeight: 160).statisticsCard()
            ForEach(summary.bars) { day in
                LabeledContent(day.accessibilityLabel, value: "\(day.count)")
            }
            explanation("Every complete day counts", text: "These totals belong to the day each task was planned, including tasks checked off later. Longer weekday patterns need at least 28 complete days and 40 completions.")
            activityLink("View all activity", filter: .period)
        }
    }

    private func average(_ index: Int) -> some View {
        Text(summary.weekdayAverage(index), format: .number.precision(.fractionLength(1)))
            .monospacedDigit()
    }

    private var habits: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recorded completions through yesterday. Open a habit to see its activity or adjust its plan.")
                .font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
            if summary.habits.isEmpty {
                ContentUnavailableView("No habits yet", systemImage: "repeat", description: Text("Your repeating tasks will appear here."))
            }
            ForEach(summary.habits) { habit in
                NavigationLink(value: StatisticsDestination.habit(habit.id)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(habit.title).font(.headline).foregroundStyle(DWColor.label)
                            Text("\(habit.count) in this period · \(habit.lifetimeCount) all time")
                                .font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.caption)
                    }
                    .statisticsCard()
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func habit(_ id: UUID) -> some View {
        if let habit = summary.habits.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                Label("EVERY CHECK-IN COUNTS", systemImage: "repeat").font(.caption)
                Text(habit.lifetimeCount, format: .number).font(.largeTitle.bold())
                Text("recorded completions").font(.headline)
                if let first = habit.firstCompletion {
                    Text("Since \(summary.format(first, template: "MMM d, yyyy"))").font(.subheadline)
                }
            }
            .foregroundStyle(DWColor.mintLabel).statisticsCard(DWColor.mintBg)
            explanation("Make it fit your day", text: "You can adjust your plan without losing recorded completions. Only recorded outcomes appear below; an empty day is not automatically a missed session.")
            Text("Recent history").font(.title2.bold())
            activityRows(Array(summary.activity(matching: .habit(id)).prefix(10)))
            activityLink("View all activity", filter: .habit(id))
        } else {
            ContentUnavailableView("Habit unavailable", systemImage: "repeat")
        }
    }

    private func activity(_ filter: StatisticsActivityFilter) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity is listed by the day each task belongs to. Later check-ins stay on their original day.")
                .font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
            activityRows(summary.activity(matching: filter))
        }
    }

    private func activityRows(_ items: [StatisticsSummary.Activity]) -> some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if items.isEmpty {
                Text("No recorded activity yet.").foregroundStyle(DWColor.secondary(colorScheme))
            }
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "forward.circle")
                        .foregroundStyle(DWColor.accent(colorScheme)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title).font(.headline)
                        Text(summary.format(item.day, template: "EEE MMM d, yyyy"))
                        Text(item.isCompleted ? "Completed" : "Skipped")
                    }
                    .font(.subheadline)
                }
                .statisticsCard()
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func activityLink(_ title: String, filter: StatisticsActivityFilter) -> some View {
        // A concrete destination also works when this detail was pushed using
        // navigationDestination(item:), as it is from a habit's task details.
        NavigationLink {
            StatisticsDetailView(destination: .activity(filter), summary: summary)
        } label: {
            Text(title).frame(maxWidth: .infinity, minHeight: 28)
        }
        .buttonStyle(.borderedProminent).controlSize(.large)
        .foregroundStyle(.white)
        .accessibilityIdentifier("statistics.viewActivity")
    }

    private var about: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Your activity, made easier to understand.").font(.title2.bold())
            explanation("Facts with context", text: "Every insight shows its time period and the activity behind it. Tap a card to see the numbers.")
            explanation("The right window", text: "Totals and daily patterns use the day each task belongs to, ending yesterday. Marking a past task done updates that day, even when you check it off later. Today’s tasks appear tomorrow. Hour patterns use same-day check-in times in your current time zone; retrospective marks are excluded.")
            explanation("Each check-in counts once", text: "Skipped tasks do not count as completions. Undoing a check-in removes it. Habit cards show completion counts; consistency rates need a reliable history of planned sessions.")
            explanation("Private by design", text: "Your statistics are calculated on device and work offline.")
            Text("“Marked done” is not a measure of your worth, effort, or time spent working.")
                .font(.footnote).foregroundStyle(DWColor.secondary(colorScheme))
        }
    }

    private func explanation(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.title2.bold())
            Text(text).font(.body).foregroundStyle(DWColor.secondary(colorScheme))
        }
    }
}
