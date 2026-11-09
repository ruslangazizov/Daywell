import Clients
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import TasksFeature

struct TaskReminderNavigationTests {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }
    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: 12))!
    }

    @Test func coldLaunchTapWaitsForDataThenOpensTheScheduledDay() async throws {
        let day = try LocalDate(year: 2026, month: 11, day: 10)
        let task = try DWTask(title: "Read", schedule: .once(on: day))
        let id = TaskOccurrenceID(taskID: task.id, day: day)
        let store = TestStore(initialState: TasksReducer.State(selectedDate: date(9), calendar: calendar)) {
            TasksReducer()
        } withDependencies: {
            $0.calendar = calendar
            $0.tasksClient.fetch = { [task] }
            $0.occurrencesClient.fetch = { [] }
        }
        await store.send(.openReminder(id)) { $0.pendingReminderID = id }
        await store.receive(\.storeChanged) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.tasks = [task]
            $0.isLoading = false
            $0.hasLoadedData = true
            $0.pendingReminderID = nil
            $0.detailsID = id
            $0.selectedDate = date(10)
            $0.selectedLocalDate = day
        }
    }

    @Test func tappingReminderDoesNotDiscardAnUnsavedEditor() async throws {
        let day = try LocalDate(year: 2026, month: 11, day: 10)
        let task = try DWTask(title: "Read", schedule: .once(on: day))
        let id = TaskOccurrenceID(taskID: task.id, day: day)
        var state = TasksReducer.State(selectedDate: date(9), tasks: [task], calendar: calendar)
        state.taskEditor = TaskEditorReducer.State(id: UUID(), selectedDate: date(9), now: date(9),
                                                   calendar: calendar, duration: .defaultValue)
        state.taskEditor?.draft.title = "Unsaved"
        let store = TestStore(initialState: state) { TasksReducer() } withDependencies: {
            $0.calendar = calendar
        }
        await store.send(.openReminder(id)) { $0.pendingReminderID = id }
        #expect(store.state.taskEditor?.draft.title == "Unsaved")
        await store.send(.taskEditor(.dismiss)) {
            $0.taskEditor = nil
            $0.pendingReminderID = nil
        }
        await store.receive(\.openReminder) {
            $0.detailsID = id
            $0.selectedDate = date(10)
            $0.selectedLocalDate = day
        }
    }
}
