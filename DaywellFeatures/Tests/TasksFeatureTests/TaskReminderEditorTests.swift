import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import TasksFeature

@MainActor
struct TaskReminderEditorTests {
    @Test func newTaskHasNoReminderUntilDeviceOptIn() throws {
        var state = TaskEditorReducer.State(id: UUID(), selectedDate: .now, now: .now,
                                            calendar: .current, duration: .defaultValue)
        state.draft.title = "Read"
        #expect(!state.taskRemindersEnabled)
        #expect(try state.draft.task(id: state.id, now: .now, calendar: .current).reminder == nil)
    }

    @Test func optedInNewTaskDefaultsToAtStart() throws {
        @Shared(Preferences.taskRemindersEnabled) var enabled
        $enabled.withLock { $0 = true }
        var state = TaskEditorReducer.State(id: UUID(), selectedDate: .now, now: .now,
                                            calendar: .current, duration: .defaultValue)
        state.draft.title = "Read"
        #expect(state.taskRemindersEnabled)
        #expect(try state.draft.task(id: state.id, now: .now, calendar: .current).reminder == .atStart)
    }

    @Test func disablingDeviceRemindersPreservesExistingChoice() throws {
        let task = try DWTask(title: "Read", schedule: .once(on: LocalDate(year: 2026, month: 11, day: 10)),
                              reminder: .atTime(LocalTime(hour: 9, minute: 30)))
        let state = TaskEditorReducer.State(task: task, calendar: .current)
        #expect(!state.taskRemindersEnabled)
        #expect(try state.draft.task(id: task.id, now: .now, calendar: .current, original: task).reminder == task.reminder)
    }

    @Test func removingWindowConvertsRelativeReminderToExplicitTime() async throws {
        var state = TaskEditorReducer.State(id: UUID(), selectedDate: .now, now: .now,
                                            calendar: .current, duration: .defaultValue)
        state.draft.reminderOption = .atStart
        state.draft.start = try LocalTime(hour: 14, minute: 15)
        let store = TestStore(initialState: state) { TaskEditorReducer() }
        await store.send(.timeWindowChanged(false)) {
            $0.draft.hasTimeWindow = false
            $0.draft.reminderOption = .customTime
            $0.draft.reminderTime = try! LocalTime(hour: 14, minute: 15)
        }
        #expect(store.state.draft.reminder == .atTime(try LocalTime(hour: 14, minute: 15)))
    }
}
