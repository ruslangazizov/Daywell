import DesignSystem
import Domain
import SwiftUI

struct TodayAgendaView: View {
    let model: TodayListViewModel
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    var body: some View {
        TodaySectionList(sections: model.agenda, onCompletionChanged: onCompletionChanged)
            .accessibilityIdentifier(Accessibility.todayAgenda)
    }
}

private struct TodaySectionList: View {
    let sections: [TodayListViewModel.Section]
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                Color.clear.frame(height: 1)
                    .id(TodayListViewModel.topID)

                if sections.allSatisfy({ $0.tasks.isEmpty }) {
                    ContentUnavailableView(
                        "No tasks for this day",
                        systemImage: "calendar",
                        description: Text("Your scheduled tasks will appear here.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 250)
                } else {
                    ForEach(sections) { section in
                        Section {
                            if section.tasks.isEmpty {
                                Text("No tasks in this zone")
                                    .font(.subheadline)
                                    .foregroundStyle(DWColor.secondary(colorScheme))
                                    .padding(.bottom, 8)
                            } else {
                                ForEach(section.tasks) { task in
                                    TodayTaskCard(model: task, onCompletionChanged: onCompletionChanged)
                                        .id(TodayListViewModel.taskID(task))
                                }
                            }
                        } header: {
                            HStack(alignment: .firstTextBaseline) {
                                Text(section.title)
                                    .font(.headline)
                                Spacer()
                                if section.isCurrent {
                                    Text("Now")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(DWColor.accent(colorScheme))
                                }
                                Text("\(section.tasks.count { $0.isCompleted })/\(section.tasks.count)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DWColor.secondary(colorScheme))
                                    .accessibilityLabel("\(section.tasks.count { $0.isCompleted }) of \(section.tasks.count) completed")
                            }
                            .padding(.top, 12)
                            .accessibilityAddTraits(.isHeader)
                            .id(section.id)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 84)
        }
        .scrollIndicators(.hidden)
    }
}

#Preview("Agenda") {
    TodayAgendaView(model: todayListPreview(), onCompletionChanged: { _, _ in })
}

#Preview("Empty day") {
    TodayAgendaView(model: todayListPreview(isEmpty: true), onCompletionChanged: { _, _ in })
}

private func todayListPreview(isEmpty: Bool = false) -> TodayListViewModel {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 9))!
    // Fixed, valid dates and windows keep these fixtures independent of app storage.
    let day = try! LocalDate(date, in: calendar.timeZone)
    let tasks = isEmpty ? [] : try! [
        DWTask(title: "Make room for a slow morning", schedule: .once(on: day),
               timeWindow: DayZone.defaults[0].window, color: .peach),
        DWTask(title: "Read a chapter", schedule: .once(on: day),
               timeWindow: DayZone.defaults[2].window, color: .lilac),
        DWTask(title: "Collect ideas for a weekend trip, including places to visit and things to pack",
               schedule: .once(on: day), color: .mint)
    ]
    let timeline = TodayTimelineViewModel(
        tasks: tasks,
        day: day,
        occurrences: [],
        todayLayout: .agenda,
        now: date,
        calendar: calendar
    )
    return TodayListViewModel(timeline: timeline, zones: DayZone.defaults)
}
