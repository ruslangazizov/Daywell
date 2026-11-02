#if DEBUG
import ComposableArchitecture
import Domain
import SwiftUI

/// Isolated fixtures used only by previews and rendering tests. Live stores stay empty.
enum StatisticsPreviewData {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }
    static let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 12))!

    static func makeStore(period: StatisticsPeriod = .week) -> StoreOf<StatisticsReducer> {
        let start = calendar.date(byAdding: .day, value: -60, to: now)!
        let tasks = (0..<9).map { index in
            try! DWTask(title: ["Read 10 pages", "Morning walk", "Practice French", "Stretch", "Journal", "Water plants", "Plan tomorrow", "Cook dinner", "Call family"][index],
                        schedule: .repeating(Recurrence(startsOn: LocalDate(start, in: calendar.timeZone), pattern: .daily(every: 1))),
                        createdAt: start)
        }
        var records: IdentifiedArrayOf<OccurrenceRecord> = []
        for (offset, count) in [5, 6, 9, 4, 7, 6, 5].enumerated() {
            let date = calendar.date(byAdding: .day, value: offset - 7, to: calendar.startOfDay(for: now))!
            for index in 0..<count {
                let completedAt = calendar.date(byAdding: .hour, value: index < 2 ? 10 : 12 + index, to: date)!
                records.append(try! OccurrenceRecord(
                    id: TaskOccurrenceID(taskID: tasks[index].id, day: LocalDate(date, in: calendar.timeZone)),
                    outcome: .completed(at: completedAt)
                ))
            }
        }
        var state = StatisticsReducer.State()
        state.tasks = tasks
        state.occurrences = records
        state.now = now
        state.calendar = calendar
        state.hasLoaded = true
        state.period = period
        let outcomes = records
        return Store(initialState: state) { StatisticsReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.continuousClock = .continuous
            $0.tasksClient.fetch = { tasks }
            $0.occurrencesClient.fetch = { outcomes }
        }
    }
}

#Preview("Statistics · Overview") {
    StatisticsView(store: StatisticsPreviewData.makeStore())
}

#Preview("Statistics · Dark") {
    StatisticsView(store: StatisticsPreviewData.makeStore()).preferredColorScheme(.dark)
}

#Preview("Statistics · Larger text") {
    StatisticsView(store: StatisticsPreviewData.makeStore()).environment(\.dynamicTypeSize, .accessibility3)
}
#endif
