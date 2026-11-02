import Clients
import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import StatisticsFeature

struct StatisticsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }
    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour))!
    }
    private func task(_ title: String = "Read", archived: Bool = false) throws -> DWTask {
        try DWTask(title: title,
                   schedule: .repeating(Recurrence(startsOn: LocalDate(date(1), in: calendar.timeZone), pattern: .daily(every: 1))),
                   createdAt: date(1), updatedAt: date(29), archivedAt: archived ? date(28) : nil)
    }
    private func record(_ task: DWTask, day: Int, completedOn: Int? = nil, hour: Int = 10,
                        skipped: Bool = false) throws -> OccurrenceRecord {
        try OccurrenceRecord(id: TaskOccurrenceID(taskID: task.id, day: LocalDate(date(day), in: calendar.timeZone)),
                             outcome: skipped ? .skipped(at: date(completedOn ?? day, hour: hour)) :
                                .completed(at: date(completedOn ?? day, hour: hour)))
    }
    private func summary(_ tasks: [DWTask], _ records: [OccurrenceRecord], period: StatisticsPeriod = .week) -> StatisticsSummary {
        StatisticsSummary(tasks: tasks, occurrences: records, period: period, now: date(30), calendar: calendar)
    }

    @Test func scheduledDayControlsRangeAndRetrospectiveMarksHaveNoHour() throws {
        let task = try task()
        let late = try record(task, day: 15, completedOn: 24, hour: 23)
        let today = try record(task, day: 29, completedOn: 30)
        let skipped = try record(task, day: 25, skipped: true)
        let outside = try record(task, day: 22)
        let result = summary([task], [late, today, skipped, outside])
        #expect(result.total == 1)
        #expect(result.timedCompletionCount == 0)
        #expect(result.bars.map(\.count) == [0, 0, 0, 0, 0, 0, 1])
        #expect(result.start == date(23, hour: 0))
        #expect(result.end == date(30, hour: 0))
        #expect(result.previousTotal == 1)
        #expect(result.habits.first?.lifetimeCount == 3)
        #expect(result.habits.first?.firstCompletion == date(15, hour: 0))
    }

    @Test func retrospectiveHistoryCountsBeforeTaskCreationAndSurvivesTimeZoneChanges() throws {
        let task = try DWTask(title: "Read", schedule: .once(on: LocalDate(date(2), in: calendar.timeZone)),
                              createdAt: date(30))
        let records = [try record(task, day: 2, completedOn: 30)]
        for zone in ["Europe/Belgrade", "America/Los_Angeles", "Asia/Tokyo"] {
            var calendar = self.calendar
            calendar.timeZone = TimeZone(identifier: zone)!
            let result = StatisticsSummary(tasks: [task], occurrences: records, period: .allTime,
                                           now: date(30), calendar: calendar)
            #expect(result.total == 1)
            #expect(result.historyDays == 28)
            #expect(calendar.component(.day, from: result.start) == 2)
            #expect(result.bars.reduce(0) { $0 + $1.count } == 1)
            #expect(result.timedCompletionCount == 0)
        }
    }

    @Test func todayAndFutureScheduledDaysStayOutsideCompleteDayTotals() throws {
        let task = try task()
        let result = summary([task], [try record(task, day: 29, completedOn: 30),
                                     try record(task, day: 30),
                                     try record(task, day: 31, completedOn: 30)])
        #expect(result.total == 1)
        #expect(result.habits.first?.lifetimeCount == 1)
    }

    @Test func retrospectiveMarksDoNotUnlockAnHourPattern() throws {
        let tasks = try (0..<20).map { try task("Habit \($0)") }
        let records = try tasks.enumerated().map {
            try record($0.element, day: 24, completedOn: $0.offset == 0 ? 30 : 24)
        }
        let result = summary(tasks, records)
        #expect(result.total == 20)
        #expect(result.timedCompletionCount == 19)
        #expect(result.topHour == nil)
    }

    @Test func daylightSavingStillIncludesExactlySevenCalendarDaysAndZeroDays() throws {
        let task = try task()
        let result = summary([task], [try record(task, day: 23), try record(task, day: 29)])
        #expect(result.bars.count == 7)
        #expect(result.bars.map(\.count) == [1, 0, 0, 0, 0, 0, 1])
        // Belgrade moves its clocks back during this window.
        #expect(result.end.timeIntervalSince(result.start) == 7 * 86400 + 3600)
    }

    @Test func countsAreUniqueIgnoreUnknownTasksAndPreserveArchivedHistory() throws {
        let archived = try task("Archived", archived: true)
        let unknown = try task("Unknown")
        let completed = try record(archived, day: 24)
        let result = summary([archived], [completed, completed, try record(unknown, day: 24)])
        #expect(result.total == 1)
        #expect(result.habits.isEmpty)
    }

    @Test func thresholdAndTiesAreBasedOnRecordedFacts() throws {
        let tasks = try (0..<20).map { try task("Habit \($0)") }
        let records = try tasks.enumerated().map { try record($0.element, day: 24, hour: $0.offset < 10 ? 9 : 10) }
        let result = summary(tasks, records)
        #expect(result.topHour?.count == 10)
        #expect(result.hourIsTied)
        #expect(summary(tasks, Array(records.prefix(19))).topHour == nil)
        let recentTasks = try tasks.map {
            try DWTask(id: $0.id, title: $0.title, schedule: $0.schedule, createdAt: date(27))
        }
        let recentRecords = try recentTasks.map { try record($0, day: 28) }
        #expect(summary(recentTasks, recentRecords).topHour == nil)
    }

    @Test func fourWeeksIncludesZeroWeekdaysAndUsesFourAsDenominator() throws {
        let tasks = try (0..<40).map { try task("Habit \($0)") }
        let records = try tasks.map { try record($0, day: 20) }
        let result = summary(tasks, records, period: .month)
        #expect(result.total == 40)
        #expect(result.bars.count == 4)
        #expect(result.weekdayOccurrences == [4, 4, 4, 4, 4, 4, 4])
        #expect(result.weekdayAverage(1) == 10)
        #expect(result.weekdayAverage(0) == 0)
        #expect(result.topWeekdayIndex == 1)
    }

    @Test func allTimeAndHabitFactsSurviveScheduleChanges() throws {
        let task = try task()
        let records = try [record(task, day: 2), record(task, day: 24), record(task, day: 25, skipped: true)]
        let edited = try DWTask(id: task.id, title: task.title,
                                schedule: .repeating(Recurrence(startsOn: LocalDate(date(29), in: calendar.timeZone), pattern: .monthly(every: 1, day: 29))),
                                createdAt: task.createdAt, updatedAt: date(29))
        let before = summary([task], records, period: .allTime)
        let after = summary([edited], records, period: .allTime)
        #expect(before == after)
        #expect(after.total == 2)
        #expect(after.habits.first?.lifetimeCount == 2)
        #expect(after.bars.reduce(0) { $0 + $1.count } == 2)
        #expect(after.previousTotal == nil)
    }

    @Test func firstVisitAndTodayOnlyAreDistinct() throws {
        let task = try task()
        #expect(!summary([task], []).hasAnyCompletions)
        let today = summary([task], [try record(task, day: 30)])
        #expect(today.hasAnyCompletions)
        #expect(today.total == 0)
        #expect(today.topHour == nil)
    }

    @Test func refreshDuringLoadIsNotLost() async {
        var state = StatisticsReducer.State()
        state.isLoading = true
        state.now = date(30)
        state.calendar = calendar
        let store = TestStore(initialState: state) { StatisticsReducer() } withDependencies: {
            $0.date = .constant(date(30))
            $0.calendar = calendar
            $0.tasksClient.fetch = { [] }
            $0.occurrencesClient.fetch = { [] }
        }
        await store.send(.task) { $0.refreshRequested = true }
        await store.send(.dataResponse(.success(.init(tasks: [], occurrences: [])))) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.refreshRequested = false
        }
        await store.receive(\.task) { $0.isLoading = true }
        await store.receive(\.dataResponse) { $0.isLoading = false }
    }

    @Test func midnightRefreshesCompleteDaysButOrdinaryTicksDoNotFetch() async {
        var state = StatisticsReducer.State()
        state.hasLoaded = true
        state.now = date(29, hour: 23)
        state.calendar = calendar
        let now = date(30, hour: 0)
        let store = TestStore(initialState: state) { StatisticsReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.tasksClient.fetch = { [] }
            $0.occurrencesClient.fetch = { [] }
        }
        await store.send(.clockTick)
        await store.receive(\.task) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.isLoading = false
            $0.now = now
        }
        await store.send(.clockTick)
    }

    @Test func storageRefreshReflectsUndoAndRetainsFactsOnFailure() async throws {
        let database = try TaskStore(inMemory: true)
        let task = try task()
        let completion = try record(task, day: 24, completedOn: 30)
        try database.saveTask(task)
        try database.saveOccurrence(completion)
        var state = StatisticsReducer.State()
        state.now = date(30)
        state.calendar = calendar
        let store = TestStore(initialState: state) { StatisticsReducer() } withDependencies: {
            $0.date = .constant(date(30))
            $0.calendar = calendar
            $0.tasksClient = .swiftData(database)
            $0.occurrencesClient = .swiftData(database)
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.isLoading = false
            $0.hasLoaded = true
            $0.tasks = [task]
            $0.occurrences = [completion]
        }
        #expect(store.state.summary.total == 1)
        try database.deleteOccurrence(completion.id)
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.isLoading = false
            $0.occurrences = []
        }
        #expect(store.state.summary.total == 0)
        enum Failure: Error { case unavailable }
        store.dependencies.tasksClient.fetch = { throw Failure.unavailable }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.isLoading = false
            $0.errorMessage = "Couldn’t update statistics. Your last results are still here."
        }
        #expect(store.state.tasks == [task])
        #expect(store.state.hasLoaded)
    }
}
