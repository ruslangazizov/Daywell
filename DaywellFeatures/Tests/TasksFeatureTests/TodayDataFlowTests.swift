import Clients
import Persistence
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import TasksFeature

struct TodayDataFlowTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        value.locale = Locale(identifier: "en_US")
        return value
    }

    private func date(_ day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }

    private func day(_ number: Int) throws -> LocalDate {
        try LocalDate(year: 2026, month: 10, day: number)
    }

    private func window(_ start: Int, _ end: Int, overnight: Bool = false) throws -> TimeWindow {
        try TimeWindow(start: LocalTime(hour: start / 60, minute: start % 60),
                       end: LocalTime(hour: end / 60, minute: end % 60),
                       endDay: overnight ? .nextDay : .sameDay)
    }

    private func task(_ title: String, start: Int? = nil, end: Int? = nil,
                      schedule: TaskSchedule? = nil, color: TaskColorToken = .lilac,
                      archived: Bool = false) throws -> DWTask {
        try DWTask(title: title,
                   schedule: schedule ?? .repeating(Recurrence(startsOn: day(1), pattern: .daily(every: 1))),
                   timeWindow: start.flatMap { start in try end.map { try window(start, $0) } },
                   color: color, createdAt: date(1), updatedAt: date(24),
                   archivedAt: archived ? date(23) : nil)
    }

    @Test func summaryAndCardsUseTheSameDayAndOccurrences() throws {
        let timed = try task("Read", start: 480, end: 540, color: .mint)
        let untimed = try task("Walk")
        let tomorrow = try task("Tomorrow only", schedule: .once(on: day(25)))
        let archived = try task("Archived", archived: true)
        let complete = try OccurrenceRecord(id: TaskOccurrenceID(taskID: timed.id, day: day(24)),
                                             outcome: .completed(at: date(24)))
        let otherDay = try OccurrenceRecord(id: TaskOccurrenceID(taskID: untimed.id, day: day(23)),
                                             outcome: .completed(at: date(23)))
        let state = TasksReducer.State(selectedDate: date(24), tasks: [timed, untimed, tomorrow, archived],
                                       tasksOccurrences: [complete, otherDay], calendar: calendar)
        #expect(state.completionSummary == TodayCompletionSummaryModel(completedCount: 1, totalCount: 2))
        #expect(state.timeline.tasks.map(\.title) == ["Read"])
        #expect(state.timeline.tasks.first?.color == .mint)
        #expect(state.timeline.tasks.first?.isCompleted == true)
        #expect(state.timeline.tasks.first?.startMinute == 480)
        #expect(state.timeline.tasks.first?.endMinute == 540)
        #expect(state.timeline.untimedTasks.map(\.title) == ["Walk"])
        #expect(state.timeline.untimedTasks.first?.isCompleted == false)
    }

    @Test func changingZonesNeverChangesTaskTimesOrHidesUntimedTasks() throws {
        let zone = try DayZone(name: "Morning", window: window(420, 660))
        let schedule = try TaskSchedule.once(on: day(24))
        let timed = try DWTask(title: "Timed", schedule: schedule, timeWindow: window(480, 540))
        let untimed = try DWTask(title: "Any time", schedule: schedule)
        let withZones = TasksReducer.State(selectedDate: date(24), tasks: [timed, untimed], zones: [zone], calendar: calendar)
        let withoutZones = TasksReducer.State(selectedDate: date(24), tasks: [timed, untimed], zones: [], calendar: calendar)
        #expect(withZones.timeline == withoutZones.timeline)
        #expect(withoutZones.timeline.tasks.map(\.startMinute) == [480])
        #expect(withoutZones.timeline.untimedTasks.map(\.title) == ["Any time"])
        #expect(withoutZones.completionSummary?.totalCount == 2)
    }

    @Test func overnightWindowExtendsTheSelectedStartDay() throws {
        let overnight = try DWTask(title: "Night", schedule: .once(on: day(24)),
                                    timeWindow: window(1320, 120, overnight: true))
        let state = TasksReducer.State(selectedDate: date(24), tasks: [overnight], calendar: calendar)
        #expect(state.timeline.tasks.first?.endMinute == 1560)
        #expect(state.timeline.tasks.first?.time.contains("+1 day") == true)
        #expect(state.timeline.hours.last?.value == 25)
        #expect(state.timeline.tasks.first?.id.day == (try day(24)))
    }

    @Test func currentTimeUsesLocalMinutesAndDisappearsOnOtherDates() throws {
        let read = try task("Read", start: 480, end: 540)
        var state = TasksReducer.State(selectedDate: date(24), tasks: [read],
                                        now: date(24, hour: 17, minute: 26), calendar: calendar)
        #expect(state.timeline.currentTime?.minute == 1046)
        #expect(state.timeline.scrollTargetID == "today-hour-17")
        state.selectedLocalDate = try day(25)
        #expect(state.timeline.currentTime == nil)
        #expect(state.timeline.scrollTargetID == "today-hour-8")
    }

    @Test func labelsFollowLocaleAndHandleHoursBeforeNoon() throws {
        var french = calendar
        french.locale = Locale(identifier: "fr_FR")
        let read = try task("Read", start: 450, end: 510)
        let state = TasksReducer.State(selectedDate: date(24), tasks: [read], calendar: french)
        #expect(state.timeline.tasks.first?.time.contains("07:30") == true)
        #expect(state.timeline.tasks.first?.time.contains("08:30") == true)
        #expect(state.timeline.hours.count == 24)
        #expect(state.timeline.hours.first?.label.contains("00") == true)
    }

    @Test func overlappingGroupsReuseColumnsAndKeepAdjacentWindowsSeparate() throws {
        let tasks = try [task("A", start: 480, end: 660), task("B", start: 540, end: 570),
                         task("C", start: 570, end: 600), task("D", start: 660, end: 720)]
        let state = TasksReducer.State(selectedDate: date(24), tasks: tasks, calendar: calendar)
        let groups = TodayTaskWindowGroup.layout(state.timeline.tasks, minimumMinutes: 0)
        #expect(groups.count == 2)
        #expect(groups[0].columnCount == 2)
        #expect(groups[0].placements.map(\.column) == [0, 1, 1])
        #expect(groups[1].columnCount == 1)
        #expect(groups[1].startMinute == 660)
    }

    @Test func denseAndShortWindowsDoNotShareOccupiedColumns() throws {
        let tasks = try [task("A", start: 480, end: 485), task("B", start: 490, end: 495),
                         task("C", start: 500, end: 505)]
        let state = TasksReducer.State(selectedDate: date(24), tasks: tasks, calendar: calendar)
        let groups = TodayTaskWindowGroup.layout(state.timeline.tasks, minimumMinutes: 50)
        #expect(groups.count == 1)
        #expect(groups[0].columnCount == 3)
        #expect(groups[0].endMinute == 550)
        #expect(groups[0].placements.map(\.column) == [0, 1, 2])
    }

    @Test func emptyAndLoadingAreDistinct() {
        var state = TasksReducer.State(selectedDate: date(24), calendar: calendar)
        #expect(state.completionSummary == nil)
        state.hasLoadedData = true
        #expect(state.timeline.isEmpty)
        #expect(state.completionSummary == TodayCompletionSummaryModel(completedCount: 0, totalCount: 0))
    }

    @Test func completingAndUndoingUpdatesBothCardsAndSummaryWithoutTouchingOtherDays() async throws {
        let read = try task("Read", start: 480, end: 540)
        let id = try TaskOccurrenceID(taskID: read.id, day: day(24))
        let previous = try OccurrenceRecord(id: TaskOccurrenceID(taskID: read.id, day: day(23)),
                                             outcome: .completed(at: date(23)))
        let now = date(24, hour: 15)
        let completed = try OccurrenceRecord(id: id, outcome: .completed(at: now))
        let store = TestStore(initialState: TasksReducer.State(selectedDate: date(24), tasks: [read],
                                                               tasksOccurrences: [previous], calendar: calendar)) {
            TasksReducer()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.occurrencesClient.save = { _ in }
            $0.occurrencesClient.delete = { _ in }
        }
        await store.send(.completionChanged(id, true)) {
            $0.tasksOccurrences.append(completed)
            $0.savingOccurrenceIDs.insert(id)
        }
        await store.receive(\.completionSaveResponse) { $0.savingOccurrenceIDs.remove(id) }
        #expect(store.state.completionSummary?.completedCount == 1)
        #expect(store.state.timeline.tasks.first?.isCompleted == true)
        await store.send(.completionChanged(id, true))
        await store.send(.completionChanged(id, false)) {
            $0.tasksOccurrences.remove(id: id)
            $0.savingOccurrenceIDs.insert(id)
        }
        await store.receive(\.completionSaveResponse) { $0.savingOccurrenceIDs.remove(id) }
        #expect(store.state.completionSummary?.completedCount == 0)
        #expect(store.state.tasksOccurrences == [previous])
        // Returning to Today must not reload fixtures and overwrite the user's change.
        await store.send(.task)
    }

    @Test func failedCompletionSaveRestoresPreviousOutcome() async throws {
        enum SaveError: LocalizedError {
            case failed
            var errorDescription: String? { "Could not save completion." }
        }
        let read = try task("Read")
        let id = try TaskOccurrenceID(taskID: read.id, day: day(24))
        let previous = try OccurrenceRecord(id: id, outcome: .skipped(at: date(24)))
        let now = date(24, hour: 15)
        let completed = try OccurrenceRecord(id: id, outcome: .completed(at: now))
        let store = TestStore(initialState: TasksReducer.State(
            selectedDate: date(24), tasks: [read], tasksOccurrences: [previous], calendar: calendar
        )) { TasksReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.occurrencesClient.save = { _ in throw SaveError.failed }
        }
        await store.send(.completionChanged(id, true)) {
            $0.tasksOccurrences[id: id] = completed
            $0.savingOccurrenceIDs.insert(id)
        }
        await store.receive(\.completionSaveResponse) {
            $0.tasksOccurrences[id: id] = previous
            $0.savingOccurrenceIDs.remove(id)
            $0.errorMessage = "Could not save completion."
        }
        await store.send(.dismissError) { $0.errorMessage = nil }
    }

    @Test func rapidUndoWaitsForSaveAndPersistsTheLatestChoice() async throws {
        let database = try TaskStore(inMemory: true)
        let read = try task("Read")
        try database.saveTask(read)
        let id = try TaskOccurrenceID(taskID: read.id, day: day(24))
        let now = date(24, hour: 15)
        let completed = try OccurrenceRecord(id: id, outcome: .completed(at: now))
        let clock = TestClock()
        let store = TestStore(initialState: TasksReducer.State(
            selectedDate: date(24), tasks: [read], calendar: calendar
        )) { TasksReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.occurrencesClient = .swiftData(database)
            $0.occurrencesClient.save = { record in
                try await clock.sleep(for: .seconds(1))
                try await database.saveOccurrence(record)
            }
        }
        await store.send(.completionChanged(id, true)) {
            $0.tasksOccurrences[id: id] = completed
            $0.savingOccurrenceIDs.insert(id)
        }
        await store.send(.completionChanged(id, false)) {
            $0.tasksOccurrences.remove(id: id)
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.completionSaveResponse)
        await store.receive(\.completionSaveResponse) { $0.savingOccurrenceIDs.remove(id) }
        #expect(try database.fetchOccurrences().isEmpty)
    }

    @Test func loadingReadsStoredTasksAndOutcomes() async throws {
        let database = try TaskStore(inMemory: true)
        let read = try task("Read")
        let now = date(24)
        let id = try TaskOccurrenceID(taskID: read.id, day: day(24))
        let completed = try OccurrenceRecord(id: id, outcome: .completed(at: now))
        try database.saveTask(read)
        try database.saveOccurrence(completed)
        let store = TestStore(initialState: TasksReducer.State(selectedDate: now, calendar: calendar)) {
            TasksReducer()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.tasksClient = .swiftData(database)
            $0.occurrencesClient = .swiftData(database)
        }
        await store.send(.task) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.isLoading = false
            $0.hasLoadedData = true
            $0.tasks = [read]
            $0.tasksOccurrences = [completed]
        }
    }

    @Test func changingDateRecomputesCardsAndRejectsStaleCardActions() async throws {
        let once = try task("Once", schedule: .once(on: day(24)))
        let target = date(25)
        let localTarget = try day(25)
        let store = TestStore(initialState: TasksReducer.State(selectedDate: date(24), tasks: [once], calendar: calendar)) {
            TasksReducer()
        } withDependencies: { $0.calendar = calendar }
        await store.send(.dateStripTapped(target)) {
            $0.selectedDate = target
            $0.selectedLocalDate = localTarget
        }
        #expect(store.state.timeline.isEmpty)
        #expect(store.state.completionSummary?.totalCount == 0)
        let staleID = try TaskOccurrenceID(taskID: once.id, day: day(24))
        await store.send(.completionChanged(staleID, true))
    }

    @Test func nowButtonReturnsToInjectedCurrentDay() async throws {
        let now = date(24, hour: 17)
        let localNow = try day(24)
        let resetID = UUID()
        let store = TestStore(initialState: TasksReducer.State(selectedDate: date(23), calendar: calendar)) {
            TasksReducer()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.uuid = .constant(resetID)
        }
        await store.send(.todayButtonTapped) {
            $0.dateStripResetID = resetID
            $0.now = now
            $0.selectedDate = now
            $0.selectedLocalDate = localNow
        }
        await store.send(.todayButtonTapped)
    }

    @Test func nowButtonResetsDateStripOnEveryTapWhenTodayIsAlreadySelected() async {
        // Different UTC dates, but the same calendar day in Belgrade.
        let selected = date(24, hour: 0, minute: 30)
        let now = date(24, hour: 17)
        let store = TestStore(initialState: TasksReducer.State(selectedDate: selected, calendar: calendar)) {
            TasksReducer()
        } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.uuid = .incrementing
        }
        await store.send(.todayButtonTapped) {
            $0.dateStripResetID = UUID(0)
            $0.now = now
            $0.selectedDate = now
        }
        #expect(store.state.timeline.scrollTargetID == "today-hour-17")
        await store.send(.todayButtonTapped) {
            $0.dateStripResetID = UUID(1)
        }
    }

    @Test func midnightFollowsTodayButDoesNotChangeAnExplicitlySelectedPastDay() async throws {
        let now = date(25, hour: 0, minute: 1)
        let localNow = try day(25)
        for selected in [24, 23] {
            let store = TestStore(initialState: TasksReducer.State(selectedDate: date(selected),
                                                                   now: date(24, hour: 23), calendar: calendar)) {
                TasksReducer()
            } withDependencies: {
                $0.date = .constant(now)
                $0.calendar = calendar
            }
            await store.send(.clockTick) {
                $0.now = now
                if selected == 24 {
                    $0.selectedDate = now
                    $0.selectedLocalDate = localNow
                }
            }
        }
    }
}
