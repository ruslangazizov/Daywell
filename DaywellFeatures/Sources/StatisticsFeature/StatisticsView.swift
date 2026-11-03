import ComposableArchitecture
import DesignSystem
import SwiftUI

public struct StatisticsView: View {
    @Bindable var store: StoreOf<StatisticsReducer>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<StatisticsReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.path.sending(\.pathChanged)) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let error = store.errorMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.hasLoaded ? error : "Couldn’t load statistics.")
                            Button("Retry") { store.send(.task) }
                                .frame(minHeight: 44)
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("statistics.error")
                    }
                    if store.hasLoaded && store.isLoading {
                        ProgressView("Updating statistics")
                            .font(.caption)
                            .accessibilityIdentifier("statistics.updating")
                    }
                    if store.hasLoaded {
                        content(store.summary)
                    } else if store.isLoading {
                        ProgressView("Loading statistics")
                            .frame(maxWidth: .infinity, minHeight: 240)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .background(DWColor.bg(colorScheme))
            .foregroundStyle(DWColor.label)
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                let clock = ContinuousClock()
                let minimumEnd = clock.now.advanced(by: .milliseconds(300))
                await store.send(.task).finish()
                // Keep the native refresh indicator visible for at least 300 ms.
                try? await clock.sleep(until: minimumEnd)
            }
            .navigationTitle("Statistics")
            .navigationDestination(for: StatisticsDestination.self) { destination in
                StatisticsDetailView(
                    destination: destination, summary: store.summary,
                    planTask: { store.send(.planTask($0)) },
                    editHabit: { store.send(.editHabit($0)) }
                )
            }
            .sheet(item: $store.destination.sending(\.destinationChanged)) { destination in
                NavigationStack {
                    StatisticsDetailView(destination: destination, summary: store.summary)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { store.send(.destinationChanged(nil)) }
                            }
                        }
                }
            }
        }
        .tint(DWColor.accent(colorScheme))
        .task { await store.send(.task).finish() }
        .task { await store.send(.startClock).finish() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.task) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Statistics")
                    .font(.largeTitle.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button {
                    store.send(.destinationChanged(.about))
                } label: {
                    Image(systemName: "info.circle")
                        .font(.title)
                }
                .accessibilityLabel("How insights work")
                .accessibilityIdentifier("statistics.about")
            }
            Text(!store.summary.hasAnyCompletions ? "Discover your own rhythm." :
                 store.summary.historyDays < 7 ? "A little history goes a long way." : "See what works for you.")
                .font(.body)
                .foregroundStyle(DWColor.secondary(colorScheme))
        }
    }

    @ViewBuilder
    private func content(_ summary: StatisticsSummary) -> some View {
        if !summary.hasAnyCompletions {
            firstVisit
        } else {
            VStack(spacing: 12) {
                periodPicker
                ViewThatFits(in: .horizontal) {
                    HStack {
                        Text(summary.rangeLabel)
                        Spacer()
                        Text("Completed days")
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.rangeLabel)
                        Text("Completed days")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.caption)
                .foregroundStyle(DWColor.secondary(colorScheme))
                summaryCard(summary)
            }
            if summary.total == 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("No activity in this period").font(.title3.bold())
                    Text("Try another period. Today’s tasks will appear after the day is complete.")
                        .foregroundStyle(DWColor.secondary(colorScheme))
                    Button("Change period") {
                        store.send(.periodChanged(store.period == .allTime ? .week : .allTime))
                    }
                    .frame(minHeight: 44)
                }
                .statisticsCard()
                .accessibilityIdentifier("statistics.noActivity")
            } else {
                rhythm(summary)
            }
            habits(summary)
        }
    }

    @ViewBuilder
    private var periodPicker: some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker("Period", selection: $store.period.sending(\.periodChanged)) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier("statistics.period")
        } else {
            Picker("Period", selection: $store.period.sending(\.periodChanged)) {
                ForEach(StatisticsPeriod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(minHeight: 44)
            .accessibilityIdentifier("statistics.period")
        }
    }

    private func summaryCard(_ summary: StatisticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    total(summary.total)
                    Text("tasks completed").font(.body)
                }
                VStack(alignment: .leading, spacing: 0) {
                    total(summary.total)
                    Text("tasks completed").font(.body)
                }
            }
            if let previous = summary.previousTotal {
                let difference = summary.total - previous
                Text(difference == 0 ? "Same as the previous \(summary.period.rawValue)" :
                     "\(difference > 0 ? "↑" : "↓") \(abs(difference)) \(difference > 0 ? "more" : "fewer") than the previous \(summary.period.rawValue)")
                    .font(.caption)
                    .foregroundStyle(difference > 0 ? DWColor.mintLabel : DWColor.secondary(colorScheme))
            } else {
                Text("Through yesterday · \(min(summary.historyDays, summary.period.days ?? summary.historyDays)) complete days of history")
                    .font(.caption)
                    .foregroundStyle(DWColor.secondary(colorScheme))
            }
            if summary.historyDays < 7 {
                ProgressView(value: Double(summary.historyDays), total: 7)
                    .accessibilityLabel("Complete days of history")
                    .accessibilityValue("\(summary.historyDays) of 7 days")
                Text("\(summary.historyDays) of 7 complete days")
                    .font(.caption).foregroundStyle(DWColor.secondary(colorScheme))
            } else {
                StatisticsBarChart(buckets: summary.bars)
            }
        }
        .statisticsCard()
    }

    private func total(_ count: Int) -> some View {
        Text(count, format: .number)
            .font(.largeTitle.bold().monospacedDigit())
            .accessibilityIdentifier("statistics.total")
    }

    @ViewBuilder
    private func rhythm(_ summary: StatisticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Your rhythm", detail: summary.period.rawValue)
            if let hour = summary.topHour {
                Button { store.send(.destinationChanged(.hour)) } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(summary.hourIsTied ? "ONE OF YOUR TOP HOURS" : "YOUR TOP HOUR", systemImage: "sun.max")
                            .font(.caption)
                        Text(hour.label).font(.largeTitle.bold())
                        Text("\(hour.count) tasks marked done in this hour.\n\(summary.hourIsTied ? "One of your busiest hours" : "Your busiest hour") in this period.")
                            .font(.subheadline)
                        Divider()
                        HStack {
                            Text("Explore your pattern")
                            Spacer()
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DWColor.accent(colorScheme))
                        .frame(minHeight: 28)
                    }
                    .foregroundStyle(DWColor.lilacLabel)
                    .statisticsCard(DWColor.lilacBg)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("statistics.topHour")
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Image(systemName: "chart.bar.xaxis").font(.title2)
                    Text("Your rhythm is taking shape").font(.title3.bold())
                    Text("We need at least 7 complete days and 20 same-day check-ins in this period before calling out a top hour.\n\nKeep using Daywell as usual. There is no daily target to unlock insights.")
                        .font(.subheadline)
                }
                .foregroundStyle(DWColor.lilacLabel)
                .statisticsCard(DWColor.lilacBg)
                .accessibilityIdentifier("statistics.buildingPattern")
            }
        }
        if summary.period == .week, let topDay = summary.topDay {
            VStack(alignment: .leading, spacing: 12) {
                sectionTitle("More insights")
                Button { store.send(.destinationChanged(.weekday)) } label: {
                    insightRow(icon: "calendar", title: summary.dayIsTied ? "One of your top days" : "Your top day this week",
                               value: "\(topDay.count) completed tasks for \(topDay.accessibilityLabel)",
                               footer: "See daily activity")
                }
                .buttonStyle(.plain)
            }
        } else if let index = summary.topWeekdayIndex {
            Button { store.send(.destinationChanged(.weekday)) } label: {
                insightRow(icon: "calendar", title: "\(summary.weekdays[index].accessibilityLabel) \(summary.weekdayIsTied ? "was one of your top weekdays" : "was your top weekday")",
                           value: "\(summary.weekdayAverage(index).formatted(.number.precision(.fractionLength(1)))) completions on average",
                           footer: "See weekday patterns")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("statistics.weekday")
        }
    }

    private func habits(_ summary: StatisticsSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Your habits").font(.title2.bold()).accessibilityAddTraits(.isHeader)
                Spacer()
                if !summary.habits.isEmpty {
                    Button("All habits") { store.send(.destinationChanged(.habits)) }
                        .accessibilityIdentifier("statistics.allHabits")
                        .font(.subheadline)
                        .frame(minHeight: 44)
                }
            }
            if let habit = summary.periodHabit, summary.period != .allTime {
                habitCard(habit, title: "COMPLETED IN THIS PERIOD", count: habit.count,
                          background: DWColor.mintBg, foreground: DWColor.mintLabel)
            }
            if let habit = summary.mostRepeated {
                habitCard(habit, title: summary.repetitionIsTied ? "ONE OF YOUR MOST REPEATED · ALL TIME" : "MOST REPEATED · ALL TIME", count: habit.lifetimeCount,
                          since: habit.firstCompletion.map { summary.format($0, template: "MMM d, yyyy") })
            }
            if summary.habits.isEmpty {
                Text("Your repeating tasks will appear here as habits.")
                    .font(.subheadline)
                    .foregroundStyle(DWColor.secondary(colorScheme))
                    .statisticsCard()
            } else {
                Text("Each check-in counts. Habit insights currently show recorded completions, rather than consistency rates.")
                    .font(.footnote)
                    .foregroundStyle(DWColor.secondary(colorScheme))
                    .padding(.horizontal, 4)
            }
        }
    }

    private func habitCard(
        _ habit: StatisticsSummary.Habit,
        title: String,
        count: Int,
        since: String? = nil,
        background: Color = DWColor.group,
        foreground: Color = DWColor.label
    ) -> some View {
        Button { store.send(.destinationChanged(.habit(habit.id))) } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "repeat").font(.title2)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.caption2.weight(.medium))
                        Text(habit.title).font(.title3.bold())
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption)
                }
                Text("\(count) completions\(since.map { " since \($0)" } ?? "")").font(.subheadline)
            }
            .foregroundStyle(foreground)
            .statisticsCard(background)
        }
        .buttonStyle(.plain)
    }

    private func insightRow(icon: String, title: String, value: String, footer: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon).font(.title2).foregroundStyle(DWColor.accent(colorScheme))
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline).foregroundStyle(DWColor.label)
                Text(value).font(.subheadline).foregroundStyle(DWColor.secondary(colorScheme))
                Text(footer).font(.subheadline).foregroundStyle(DWColor.accent(colorScheme))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(DWColor.secondary(colorScheme))
        }
        .statisticsCard()
    }

    private func sectionTitle(_ title: String, detail: String? = nil) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.title2.bold()).accessibilityAddTraits(.isHeader)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(DWColor.secondary(colorScheme)) }
        }
    }

    private var firstVisit: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 52))
                .foregroundStyle(DWColor.accent(colorScheme))
                .accessibilityHidden(true)
            Text("Small steps.\nUseful discoveries.")
                .font(.largeTitle.bold())
            Text("As you complete tasks, you’ll see what works for you — from your busiest hour to habits that are finding a place.")
                .foregroundStyle(DWColor.secondary(colorScheme))
            Button("Go to Today") { store.send(.goToToday) }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("statistics.goToToday")
            Label("Insights stay on your device.", systemImage: "lock")
                .font(.footnote)
                .foregroundStyle(DWColor.secondary(colorScheme))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
}

#Preview("Statistics · First visit") {
    StatisticsView(store: Store(initialState: StatisticsReducer.State()) { StatisticsReducer() })
}
