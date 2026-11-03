import Clients
import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import TasksFeature

struct TaskEditorTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Belgrade")!
        return value
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 24, hour: 23, minute: 45))!
    }

    private func state() -> TaskEditorReducer.State {
        .init(id: UUID(0), selectedDate: now, now: now, calendar: calendar,
              duration: TaskDuration(minutes: 45))
    }

    @Test func statisticsSuggestionOpensReviewAtNextHourAndCancelDoesNotWrite() async throws {
        let initial = TasksReducer.State(selectedDate: now, calendar: calendar, hasLoadedData: true)
        let planned = calendar.nextDate(after: now, matching: DateComponents(hour: 10, minute: 0), matchingPolicy: .nextTime)!
        let store = TestStore(initialState: initial) { TasksReducer() } withDependencies: {
            $0.uuid = .constant(UUID(0))
            $0.date = .constant(now)
            $0.calendar = calendar
        }
        await store.send(.planTaskAtHour(24))
        await store.send(.planTaskAtHour(10)) {
            $0.taskEditor = .init(id: UUID(0), selectedDate: planned, now: planned,
                                 calendar: calendar, duration: initial.defaultTaskDuration)
        }
        #expect(store.state.taskEditor?.draft.start == (try LocalTime(hour: 10, minute: 0)))
        #expect(store.state.taskEditor?.hasChanges == false)
        #expect(planned > now)
        await store.send(.taskEditor(.dismiss)) { $0.taskEditor = nil }
        #expect(store.state.tasks.isEmpty)
    }

    @Test func defaultWindowUsesPreferenceAndCrossesMidnight() throws {
        let draft = state().draft
        let window = try #require(try draft.timeWindow())
        #expect(window.start == (try LocalTime(hour: 23, minute: 45)))
        #expect(window.end == (try LocalTime(hour: 0, minute: 30)))
        #expect(window.crossesMidnight)
        #expect(window.durationInMinutes == 45)
    }

    @Test func openingUsesSelectedDayAndSavedDurationWithoutWriting() async throws {
        let selected = calendar.date(byAdding: .day, value: 3, to: now)!
        @Shared(Preferences.defaultTaskDuration) var duration
        $duration.withLock { $0 = TaskDuration(minutes: 90) }
        let initial = TasksReducer.State(selectedDate: selected, calendar: calendar, hasLoadedData: true)
        let store = TestStore(initialState: initial) { TasksReducer() } withDependencies: {
            $0.uuid = .constant(UUID(0))
            $0.date = .constant(now)
            $0.calendar = calendar
        }
        await store.send(.addTaskButtonTapped) {
            $0.taskEditor = .init(id: UUID(0), selectedDate: selected, now: now,
                                 calendar: calendar, duration: TaskDuration(minutes: 90))
        }
        #expect(store.state.taskEditor?.draft.scheduledDate == selected)
        #expect(try store.state.taskEditor?.draft.timeWindow()?.durationInMinutes == 90)
        await store.send(.addTaskButtonTapped)
        await store.send(.taskEditor(.dismiss)) { $0.taskEditor = nil }
        #expect(store.state.tasks.isEmpty)
    }

    @Test func saveWritesThroughExistingStoreAndOnlyThenUpdatesToday() async throws {
        let database = try TaskStore(inMemory: true)
        var initial = TasksReducer.State(
            selectedDate: now, calendar: calendar, hasLoadedData: true
        )
        initial.taskEditor = state()
        initial.taskEditor?.draft.title = "  Read a chapter  "
        initial.taskEditor?.draft.notes = "  With tea  "
        let store = TestStore(initialState: initial) { TasksReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.calendar = calendar
            $0.uuid = .constant(UUID(0))
            $0.tasksClient = .swiftData(database)
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.taskEditor(.presented(.saveTapped)))
        #expect(store.state.tasks.isEmpty)
        await store.receive(\.taskEditor.presented.saveResponse)
        await store.receive(\.taskEditor.presented.delegate.didSave)
        #expect(store.state.taskEditor == nil)
        let saved = try #require(database.fetchTasks().first)
        #expect(saved.title == "Read a chapter")
        #expect(saved.description == "With tea")
        #expect(!saved.isHabit)
        #expect(saved.schedule.startsOn == (try LocalDate(now, in: calendar.timeZone)))
        #expect(store.state.scheduledTasks == [saved])
        #expect(try database.fetchOccurrences().isEmpty)
        #expect(try database.fetchTasks().count == 1)
    }

    @Test func failedSavePreservesDraftAndRetryUsesSameIdentity() async throws {
        enum SaveError: LocalizedError {
            case failed
            var errorDescription: String? { "Storage unavailable." }
        }
        let database = try TaskStore(inMemory: true)
        let attempts = LockIsolated(0)
        var initial = state()
        initial.draft.title = "Walk"
        initial.draft.repeatOption = .daily
        initial.draft.hasTimeWindow = false
        let saved = try initial.draft.task(id: initial.id, now: now, calendar: calendar)
        let store = TestStore(initialState: initial) { TaskEditorReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.tasksClient.save = { task in
                let attempt = attempts.withValue { $0 += 1; return $0 }
                if attempt == 1 { throw SaveError.failed }
                try await database.saveTask(task)
            }
        }
        await store.send(.saveTapped) { $0.isSaving = true }
        await store.receive(\.saveResponse) {
            $0.isSaving = false
            $0.saveError = "Storage unavailable."
        }
        #expect(store.state.draft == initial.draft)
        #expect(try database.fetchTasks().isEmpty)
        await store.send(.saveTapped) {
            $0.isSaving = true
            $0.saveError = nil
        }
        await store.receive(\.saveResponse)
        await store.receive(\.delegate.didSave)
        #expect(try database.fetchTasks() == [saved])
        #expect(saved.isHabit)
        #expect(saved.timeWindow == nil)
    }

    @Test func savingRejectsRepeatedSubmitAndCancel() async throws {
        let clock = TestClock()
        let writes = LockIsolated(0)
        var initial = state()
        initial.draft.title = "Read"
        let store = TestStore(initialState: initial) { TaskEditorReducer() } withDependencies: {
            $0.date = .constant(now)
            $0.tasksClient.save = { _ in
                writes.withValue { $0 += 1 }
                try await clock.sleep(for: .seconds(1))
            }
        }
        await store.send(.saveTapped) { $0.isSaving = true }
        await store.send(.saveTapped)
        await store.send(.cancelTapped)
        await clock.advance(by: .seconds(1))
        await store.receive(\.saveResponse)
        await store.receive(\.delegate.didSave)
        #expect(writes.value == 1)
    }

    @Test func invalidDraftNeverCallsStorage() async throws {
        var initial = state()
        initial.draft.title = " \n "
        let store = TestStore(initialState: initial) { TaskEditorReducer() }
        await store.send(.saveTapped)
        #expect(!store.state.canSave)
        var draft = initial.draft
        draft.title = "Valid title"
        draft.endsNextDay = false
        #expect(draft.validationMessage(calendar: calendar) != nil)
        draft.hasTimeWindow = false
        draft.repeatOption = .custom
        draft.weekdays = []
        #expect(draft.validationMessage(calendar: calendar) != nil)
        draft.weekdays = [.monday]
        draft.hasEndDate = true
        draft.endDate = calendar.date(byAdding: .day, value: -1, to: now)!
        #expect(draft.validationMessage(calendar: calendar) != nil)
    }

    @Test func customSchedulesPreserveDomainRules() throws {
        var draft = state().draft
        draft.title = "Practice"
        draft.repeatOption = .custom
        draft.frequency = .weekly
        draft.interval = 2
        draft.weekdays = [.monday, .friday]
        let recurrence = try #require(draft.schedule(in: calendar).recurrence)
        #expect(recurrence.pattern == .weekly(every: 2, weekdays: [.monday, .friday]))
        draft.frequency = .monthly
        draft.interval = 1
        draft.monthDay = 31
        let monthly = try draft.schedule(in: calendar)
        #expect(try !monthly.occurs(on: LocalDate(year: 2026, month: 11, day: 30)))
        #expect(try monthly.occurs(on: LocalDate(year: 2026, month: 12, day: 31)))
        draft.repeatOption = .never
        draft.hasEndDate = true
        draft.weekdays = []
        #expect(try !draft.task(id: UUID(0), now: now, calendar: calendar).isHabit)
    }

    @Test func cancellingDirtyDraftRequiresDiscardAndDoesNotSave() async {
        var initial = state()
        initial.draft.title = "Unsaved task"
        let dismissed = LockIsolated(false)
        let store = TestStore(initialState: initial) { TaskEditorReducer() } withDependencies: {
            $0.dismiss = DismissEffect { dismissed.setValue(true) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.cancelTapped)
        #expect(store.state.discardConfirmation != nil)
        #expect(!dismissed.value)
        await store.send(.discardConfirmation(.presented(.discard)))
        await store.finish()
        #expect(dismissed.value)
    }
}
