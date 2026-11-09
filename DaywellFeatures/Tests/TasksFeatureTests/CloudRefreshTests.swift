import Clients
import ComposableArchitecture
import Domain
import Foundation
import Testing
@testable import TasksFeature

struct CloudRefreshTests {
    @Test func importRefreshPreservesTheSelectedPastDay() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let selected = Date(timeIntervalSince1970: 1_700_000_000)
        let today = selected.addingTimeInterval(86400 * 10)
        let task = try DWTask(title: "Imported", schedule: .once(on: LocalDate(selected, in: calendar.timeZone)))
        let store = TestStore(initialState: TasksReducer.State(selectedDate: selected, calendar: calendar, hasLoadedData: true)) {
            TasksReducer()
        } withDependencies: {
            $0.date.now = today
            $0.tasksClient.fetch = { [task] }
            $0.occurrencesClient.fetch = { [] }
        }
        await store.send(.storeChanged) { $0.isLoading = true }
        await store.receive(\.dataResponse) {
            $0.isLoading = false
            $0.tasks = [task]
        }
        #expect(store.state.selectedDate == selected)
    }

    @Test func importWaitsForPendingLocalToggle() async throws {
        let day = try LocalDate(year: 2026, month: 11, day: 3)
        let task = try DWTask(title: "Read", schedule: .once(on: day))
        let record = try OccurrenceRecord(id: .init(taskID: task.id, day: day), outcome: .completed(at: .now))
        var state = TasksReducer.State(tasks: [task], tasksOccurrences: [record])
        state.savingOccurrenceIDs = [record.id]
        let store = TestStore(initialState: state) { TasksReducer() } withDependencies: {
            $0.tasksClient.fetch = { [task] }
            $0.occurrencesClient.fetch = { [record] }
        }
        await store.send(.storeChanged) { $0.storeRefreshPending = true }
        await store.send(.completionSaveResponse(record.id, previous: nil, saved: record, .success(()))) {
            $0.savingOccurrenceIDs = []
        }
        await store.receive(\.storeChanged) {
            $0.storeRefreshPending = false
            $0.isLoading = true
        }
        await store.receive(\.dataResponse) { $0.isLoading = false }
    }
}
