import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

/// Read observable state inside a destination view, rather than capturing a
/// snapshot when SwiftUI first resolves the navigation destination.
struct TaskDetailsDestination: View {
    let store: StoreOf<TasksReducer>
    let id: TaskOccurrenceID

    var body: some View {
        if let task = store.tasks.first(where: { $0.id == id.taskID }) {
            TaskDetailsView(
                model: TaskDetailsModel(task: task, id: id, records: store.tasksOccurrences,
                                        now: store.now, calendar: store.calendar),
                isSaving: store.savingOccurrenceIDs.contains(id),
                errorMessage: store.errorMessage,
                onComplete: { store.send(.completionChanged(id, $0)) },
                onEdit: { store.send(.editDetailsTapped) },
                onDismissError: { store.send(.dismissError) }
            )
        } else {
            ContentUnavailableView("Task unavailable", systemImage: "calendar.badge.exclamationmark")
        }
    }
}

struct TaskDetailsView: View {
    let model: TaskDetailsModel
    let isSaving: Bool
    let errorMessage: String?
    let onComplete: (Bool) -> Void
    let onEdit: () -> Void
    let onDismissError: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(model.task.title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier(Accessibility.taskDetailsTitle)
                    Text(model.task.isHabit ? model.repeatLabel : "One-time task")
                        .foregroundStyle(.secondary)
                    Label(model.dayLabel, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                timeWindow
                if let description = model.task.description {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Description").font(.headline)
                        Text(description).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                Label(model.status, systemImage: model.isCompleted ? "checkmark.circle" : "clock")
                    .font(.subheadline)
                    .foregroundStyle(model.isCompleted ? DWColor.accent(colorScheme) : DWColor.secondary(colorScheme))
                    .accessibilityIdentifier(Accessibility.taskDetailsStatus)
                if model.task.isHabit { history }
                schedule
                if let errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Couldn’t save completion").font(.headline)
                        Text(errorMessage).font(.subheadline)
                        Button("Dismiss", action: onDismissError)
                    }
                    .accessibilityIdentifier(Accessibility.taskDetailsError)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(DWColor.bg(colorScheme).ignoresSafeArea())
        .navigationTitle(model.task.isHabit ? "Habit details" : "Task details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit", action: onEdit)
                    .accessibilityIdentifier(Accessibility.taskDetailsEdit)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button { onComplete(!model.isCompleted) } label: {
                HStack(spacing: 10) {
                    if isSaving { ProgressView().tint(colorScheme == .dark ? .black : .white) }
                    Text(model.isCompleted ? "Mark incomplete" : "Mark complete")
                        .fontWeight(.semibold)
                    if !dynamicTypeSize.isAccessibilitySize {
                        Image(systemName: model.isCompleted ? "arrow.uturn.backward" : "checkmark")
                    }
                }
                .foregroundStyle(colorScheme == .dark ? Color.black : Color.white)
                .frame(maxWidth: .infinity, minHeight: 36)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .disabled(!model.canComplete || isSaving)
            .accessibilityIdentifier(Accessibility.taskDetailsComplete)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private var timeWindow: some View {
        let colorGroup = model.task.color.toDWColorGroup
        return VStack(alignment: .leading, spacing: 12) {
            Text("YOUR TIME WINDOW").font(.caption)
            Text(model.timeLabel).font(.title3.bold())
            Text(model.task.timeWindow == nil
                 ? "Make time for this whenever it suits your day."
                 : "A window, not a deadline. Start when you’re ready.")
                .font(.subheadline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .foregroundStyle(colorGroup.label)
        .background(colorGroup.bg, in: RoundedRectangle(cornerRadius: 24))
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last 7 days").font(.headline)
            if dynamicTypeSize.isAccessibilitySize {
                ForEach(model.history) { day in
                    Label("\(model.dateLabel(day.id)): \(day.status)", systemImage: day.symbol)
                        .font(.subheadline)
                }
            } else {
                HStack(alignment: .top) {
                    ForEach(model.history) { day in
                        VStack(spacing: 8) {
                            Text(day.date, format: .dateTime.weekday(.narrow))
                                .font(.caption).foregroundStyle(.secondary)
                            Image(systemName: day.symbol)
                                .font(.caption.weight(.semibold))
                                .frame(width: 32, height: 32)
                                .background(DWColor.accent(colorScheme).opacity(day.outcome == nil ? 0.04 : 0.12), in: Circle())
                                .overlay { Circle().strokeBorder(day.isSelected ? DWColor.accent(colorScheme) : .clear) }
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(model.dateLabel(day.id)), \(day.status)")
                    }
                }
                .foregroundStyle(DWColor.accent(colorScheme))
            }
            Text(model.historySummary).font(.footnote).foregroundStyle(DWColor.accent(colorScheme))
        }
        .accessibilityIdentifier(Accessibility.taskDetailsHistory)
    }

    private var schedule: some View {
        VStack(spacing: 16) {
            LabeledContent("Repeat", value: model.repeatLabel)
            if let recurrence = model.task.schedule.recurrence {
                Divider()
                LabeledContent("Starts on", value: model.dateLabel(recurrence.startsOn))
                if let end = recurrence.endsOn {
                    LabeledContent("Ends on", value: model.dateLabel(end))
                }
            }
        }
        .font(.body)
        .padding(16)
        .background(DWColor.group, in: RoundedRectangle(cornerRadius: 20))
    }
}

#Preview("Habit details") {
    NavigationStack { taskDetailsPreview() }
}

#Preview("Habit details · Dark · Large text") {
    NavigationStack { taskDetailsPreview() }
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility3)
}

#if DEBUG
private func taskDetailsPreview() -> some View {
    let day = try! LocalDate(year: 2026, month: 11, day: 1)
    let task = try! DWTask(
        title: "Do stretches", description: "A gentle reset for your body. Move slowly and breathe.",
        schedule: .repeating(Recurrence(startsOn: day, pattern: .daily(every: 1))),
        timeWindow: TimeWindow(start: LocalTime(hour: 8, minute: 0), end: LocalTime(hour: 9, minute: 0)),
        color: .mint
    )
    return TaskDetailsView(
        model: TaskDetailsModel(task: task, id: TaskOccurrenceID(taskID: task.id, day: day),
                                records: [], now: .now, calendar: .current),
        isSaving: false, errorMessage: nil, onComplete: { _ in }, onEdit: {}, onDismissError: {}
    )
}
#endif
