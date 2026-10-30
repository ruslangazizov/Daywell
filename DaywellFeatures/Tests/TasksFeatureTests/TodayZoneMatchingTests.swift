import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import TasksFeature

struct TodayZoneMatchingTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 17))!
    }

    private var day: LocalDate { try! LocalDate(now, in: calendar.timeZone) }

    private func window(_ start: Int, _ end: Int, overnight: Bool = false) throws -> TimeWindow {
        try TimeWindow(start: LocalTime(hour: start / 60, minute: start % 60),
                       end: LocalTime(hour: end / 60, minute: end % 60),
                       endDay: overnight ? .nextDay : .sameDay)
    }

    private func task(window: TimeWindow? = nil) throws -> DWTask {
        try DWTask(title: "Read", schedule: .once(on: day), timeWindow: window)
    }

    private func sections(for task: DWTask, zones: [DayZone] = DayZone.defaults) -> [TodayListViewModel.Section] {
        let state = TasksReducer.State(selectedDate: now, tasks: [task], zones: zones, calendar: calendar)
        return TodayListViewModel(timeline: state.timeline, zones: state.zones).zones
    }

    @Test(arguments: [
        (1020, 1080, false, ["Day"]),
        (1050, 1110, false, ["Day", "Evening"]),
        (1080, 1140, false, ["Evening"]),
        (1350, 1410, false, ["Evening"]),
        (1410, 30, true, ["No zone"]),
        (1380, 420, true, ["No zone"]),
        (1380, 480, true, ["Morning"]),
        (630, 1110, false, ["Morning", "Day", "Evening"]),
        (420, 420, true, ["Morning", "Day", "Evening"])
    ])
    func intervalsAppearInEveryOverlappingZone(values: (Int, Int, Bool, [String])) throws {
        let (start, end, overnight, expected) = values
        let task = try task(window: window(start, end, overnight: overnight))
        let populated = sections(for: task).filter { !$0.tasks.isEmpty }
        #expect(populated.map(\.title) == expected)
        for section in populated {
            #expect(section.tasks.count == 1)
            #expect(section.tasks.first?.timeWindow == task.timeWindow)
            #expect(section.tasks.first?.id == TaskOccurrenceID(taskID: task.id, day: day))
        }
    }

    @Test func untimedTasksAndTasksWithNoConfiguredZonesRemainVisible() throws {
        let untimed = try task()
        #expect(sections(for: untimed).filter { !$0.tasks.isEmpty }.map(\.title) == ["No zone"])
        let timed = try task(window: window(1020, 1080))
        let noZones = sections(for: timed, zones: [])
        #expect(noZones.map(\.title) == ["No zone"])
        #expect(noZones.first?.tasks.first?.timeWindow == timed.timeWindow)
    }

    @Test func partialGapsDoNotCreateExtraNoZoneCards() throws {
        let zones = try [DayZone(name: "Morning", window: window(420, 600)),
                         DayZone(name: "Day", window: window(720, 1080))]
        let crossing = try task(window: window(540, 780))
        #expect(sections(for: crossing, zones: zones).map(\.title) == ["Morning", "Day"])
        let gapOnly = try task(window: window(600, 720))
        #expect(sections(for: gapOnly, zones: zones).filter { !$0.tasks.isEmpty }.map(\.title) == ["No zone"])
    }

    @Test func overlappingBothPartsOfNightCreatesOneCardAndKeepsStartDay() throws {
        let night = try DayZone(name: "Night", window: window(1320, 120, overnight: true))
        let task = try task(window: window(1410, 60, overnight: true))
        let section = try #require(sections(for: task, zones: [night]).first)
        #expect(section.tasks.count == 1)
        #expect(section.tasks.first?.id.day == day)
        #expect(section.tasks.first?.endMinute == 1500)
        #expect(section.tasks.first?.time.contains("+1 day") == true)
    }

    @Test func editingOrDeletingZonesRegroupsWithoutChangingTheTaskOrItsCompletion() throws {
        @Shared(Preferences.dailyZones) var zones
        let task = try task(window: window(1050, 1110))
        let id = TaskOccurrenceID(taskID: task.id, day: day)
        let occurrence = try OccurrenceRecord(id: id, outcome: .completed(at: now))
        let state = TasksReducer.State(selectedDate: now, tasks: [task], tasksOccurrences: [occurrence], calendar: calendar)
        let timeline = state.timeline

        // Moving the boundary from 18:00 to 19:00 leaves this task entirely in Day.
        let edited = try [
            DayZone.defaults[0],
            DayZone(id: DayZone.defaults[1].id, name: "Day", window: window(660, 1140)),
            DayZone(id: DayZone.defaults[2].id, name: "Evening", window: window(1140, 1380))
        ]
        $zones.withLock { $0 = edited }
        var populated = TodayListViewModel(timeline: state.timeline, zones: state.zones).zones.filter { !$0.tasks.isEmpty }
        #expect(populated.map(\.title) == ["Day"])
        #expect(populated.first?.tasks.first?.isCompleted == true)
        #expect(state.timeline == timeline)
        #expect(state.tasks == [task])

        $zones.withLock { $0 = [] }
        populated = TodayListViewModel(timeline: state.timeline, zones: state.zones).zones.filter { !$0.tasks.isEmpty }
        #expect(populated.map(\.title) == ["No zone"])
        #expect(populated.first?.tasks.first?.isCompleted == true)
        #expect(state.timeline == timeline)

        $zones.withLock { $0 = DayZone.defaults }
        populated = TodayListViewModel(timeline: state.timeline, zones: state.zones).zones.filter { !$0.tasks.isEmpty }
        #expect(populated.map(\.title) == ["Day", "Evening"])
        #expect(populated.flatMap(\.tasks).allSatisfy { $0.isCompleted })
    }

    @Test func completingAndUndoingEitherCardUpdatesBothAndCountsOneTaskForTheDay() async throws {
        let task = try task(window: window(1050, 1110))
        let id = TaskOccurrenceID(taskID: task.id, day: day)
        let record = try OccurrenceRecord(id: id, outcome: .completed(at: now))
        let store = TestStore(initialState: TasksReducer.State(selectedDate: now, tasks: [task],
                                                               zones: DayZone.defaults, calendar: calendar)) {
            TasksReducer()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
        }

        let before = TodayListViewModel(timeline: store.state.timeline, zones: store.state.zones)
        let dayCard = try #require(before.zones.first(where: { $0.title == "Day" })?.tasks.first)
        let eveningCard = try #require(before.zones.first(where: { $0.title == "Evening" })?.tasks.first)
        #expect(dayCard.id == eveningCard.id)
        await store.send(.completionChanged(dayCard.id, true)) { $0.tasksOccurrences.append(record) }
        let completed = TodayListViewModel(timeline: store.state.timeline, zones: store.state.zones)
        #expect(completed.zones.flatMap(\.tasks).count == 2)
        #expect(completed.zones.flatMap(\.tasks).allSatisfy { $0.isCompleted })
        #expect(completed.agenda.flatMap(\.tasks).count == 1)
        #expect(store.state.timeline.tasks.count == 1)
        #expect(store.state.completionSummary == TodayCompletionSummaryModel(completedCount: 1, totalCount: 1))
        await store.send(.completionChanged(eveningCard.id, true))
        #expect(store.state.tasksOccurrences.count == 1)

        await store.send(.completionChanged(eveningCard.id, false)) { $0.tasksOccurrences.remove(id: id) }
        let undone = TodayListViewModel(timeline: store.state.timeline, zones: store.state.zones)
        #expect(undone.zones.flatMap(\.tasks).allSatisfy { !$0.isCompleted })
        #expect(store.state.completionSummary == TodayCompletionSummaryModel(completedCount: 0, totalCount: 1))
    }
}
