import Clients
import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import TasksFeature

struct TaskDetailsTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        return value
    }
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }
    private func day(_ day: Int) throws -> LocalDate { try LocalDate(year: 2026, month: 10, day: day) }
    private func habit() throws -> DWTask {
        try DWTask(title: "Read", schedule: .repeating(Recurrence(startsOn: day(1), pattern: .daily(every: 1))),
                   timeWindow: TimeWindow(start: LocalTime(hour: 23, minute: 0), end: LocalTime(hour: 1, minute: 0), endDay: .nextDay),
                   createdAt: date(1))
    }

    @Test func openingRejectsStaleOccurrencesAndDoesNotComplete() async throws {
        let task = try habit()
        let id = try TaskOccurrenceID(taskID: task.id, day: day(24))
        let stale = try TaskOccurrenceID(taskID: task.id, day: day(23))
        let store = TestStore(initialState: TasksReducer.State(selectedDate: date(24), tasks: [task], calendar: calendar)) { TasksReducer() }
        await store.send(.detailsChanged(stale))
        await store.send(.detailsChanged(id)) { $0.detailsID = id }
        #expect(store.state.tasksOccurrences.isEmpty)
        await store.send(.detailsChanged(nil)) { $0.detailsID = nil }
    }

    @Test func detailsKeepStartDayAcrossMidnightAndSaveAfterPop() async throws {
        let task = try habit()
        let database = try TaskStore(inMemory: true)
        try database.saveTask(task)
        let id = try TaskOccurrenceID(taskID: task.id, day: day(24))
        var initial = TasksReducer.State(selectedDate: date(24), tasks: [task], calendar: calendar)
        initial.detailsID = id
        let clock = TestClock()
        let store = TestStore(initialState: initial) { TasksReducer() } withDependencies: {
            $0.calendar = calendar
            $0.date = .constant(date(25, hour: 0))
            $0.occurrencesClient = .swiftData(database)
            $0.occurrencesClient.save = { record in
                try await clock.sleep(for: .seconds(1))
                try await database.saveOccurrence(record)
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.clockTick)
        #expect(store.state.selectedLocalDate == (try day(25)))
        #expect(store.state.detailsID == id)
        await store.send(.completionChanged(id, true))
        await store.send(.detailsChanged(nil))
        await clock.advance(by: .seconds(1))
        await store.receive(\.completionSaveResponse)
        #expect(try database.fetchOccurrences().first?.id == id)
        #expect(store.state.timeline.tasks.first?.isCompleted == false)
    }

    @Test func moreStatsUsesTheDisplayedHabitAndPreservesDetailsOnBack() async throws {
        let task = try habit()
        let id = try TaskOccurrenceID(taskID: task.id, day: day(24))
        let store = TestStore(initialState: TasksReducer.State(
            selectedDate: date(24), tasks: [task], calendar: calendar
        )) { TasksReducer() } withDependencies: {
            $0.calendar = calendar
        }

        await store.send(.moreStatsButtonTapped)
        await store.send(.detailsChanged(id)) { $0.detailsID = id }
        // Changing the selected day must not change which habit's details are open.
        await store.send(.dateStripTapped(date(25))) {
            $0.selectedDate = date(25)
            $0.selectedLocalDate = try? day(25)
        }
        await store.send(.moreStatsButtonTapped) { $0.habitStatisticsID = task.id }
        await store.send(.habitStatisticsChanged(nil)) { $0.habitStatisticsID = nil }
        #expect(store.state.detailsID == id)
        await store.send(.moreStatsButtonTapped) { $0.habitStatisticsID = task.id }
        await store.send(.detailsChanged(nil)) {
            $0.detailsID = nil
            $0.habitStatisticsID = nil
        }
    }

    @Test func moreStatsIgnoresOneTimeTasks() async throws {
        let task = try DWTask(title: "Read", schedule: .once(on: day(24)), createdAt: date(24))
        let id = try TaskOccurrenceID(taskID: task.id, day: day(24))
        let store = TestStore(initialState: TasksReducer.State(
            selectedDate: date(24), tasks: [task], calendar: calendar
        )) { TasksReducer() }
        await store.send(.detailsChanged(id)) { $0.detailsID = id }
        await store.send(.moreStatsButtonTapped)
    }

    @Test func failedCompletionRestoresDetailsAndToday() async throws {
        struct SaveError: Error {}
        let task = try habit()
        let id = try TaskOccurrenceID(taskID: task.id, day: day(24))
        var initial = TasksReducer.State(selectedDate: date(24), tasks: [task], calendar: calendar)
        initial.detailsID = id
        let store = TestStore(initialState: initial) { TasksReducer() } withDependencies: {
            $0.date = .constant(date(24))
            $0.occurrencesClient.save = { _ in throw SaveError() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.completionChanged(id, true))
        #expect(store.state.timeline.tasks.first?.isCompleted == true)
        await store.receive(\.completionSaveResponse)
        #expect(store.state.tasksOccurrences.isEmpty)
        #expect(store.state.timeline.tasks.first?.isCompleted == false)
        #expect(store.state.errorMessage != nil)
        #expect(store.state.detailsID == id)
    }

    @Test func historyShowsFactsAcrossDSTAndScheduleChanges() throws {
        let task = try DWTask(title: "Read", schedule: .repeating(Recurrence(startsOn: day(26), pattern: .weekly(every: 2, weekdays: [.monday]))), createdAt: date(1))
        let completed = try OccurrenceRecord(id: TaskOccurrenceID(taskID: task.id, day: day(23)), outcome: .completed(at: date(23)))
        let skipped = try OccurrenceRecord(id: TaskOccurrenceID(taskID: task.id, day: day(24)), outcome: .skipped(at: date(24)))
        let model = try TaskDetailsModel(task: task, id: TaskOccurrenceID(taskID: task.id, day: day(26)), records: [completed, skipped], now: date(26), calendar: calendar)
        #expect(model.history.map(\.id.day) == [20, 21, 22, 23, 24, 25, 26])
        #expect(model.history[3].status == "Completed")
        #expect(model.history[4].status == "Skipped")
        #expect(model.history[5].status == "No recorded outcome")
    }

    @Test func editingPreservesIdentityExactRecurrenceAndHistory() async throws {
        let database = try TaskStore(inMemory: true)
        let task = try DWTask(title: "Read", schedule: .repeating(Recurrence(startsOn: day(1), endsOn: day(31), pattern: .monthly(every: 3, day: 31))), timeWindow: habit().timeWindow, createdAt: date(1))
        try database.saveTask(task)
        let record = try OccurrenceRecord(id: TaskOccurrenceID(taskID: task.id, day: day(24)), outcome: .completed(at: date(24)))
        try database.saveOccurrence(record)
        var initial = TasksReducer.State(selectedDate: date(24), tasks: [task], tasksOccurrences: [record], calendar: calendar)
        initial.detailsID = record.id
        initial.taskEditor = .init(task: task, calendar: calendar)
        #expect(initial.taskEditor?.hasChanges == false)
        initial.taskEditor?.draft.title = "Read slowly"
        let store = TestStore(initialState: initial) { TasksReducer() } withDependencies: {
            $0.calendar = calendar
            $0.date = .constant(date(26))
            $0.tasksClient = .swiftData(database)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.taskEditor(.presented(.saveTapped)))
        await store.receive(\.taskEditor.presented.saveResponse)
        await store.receive(\.taskEditor.presented.delegate.didSave)
        let saved = try #require(database.fetchTasks().first)
        #expect(saved.id == task.id)
        #expect(saved.createdAt == task.createdAt)
        #expect(saved.schedule == task.schedule)
        #expect(saved.timeWindow == task.timeWindow)
        #expect(saved.title == "Read slowly")
        #expect(try database.fetchOccurrences() == [record])
        #expect(store.state.tasks == [saved])
        #expect(store.state.taskEditor == nil)
    }
}
