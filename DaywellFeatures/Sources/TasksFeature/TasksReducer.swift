import Foundation
import Domain
import Clients
import Persistence
import ComposableArchitecture

private nonisolated enum CancelID: Hashable, Sendable { case clock }

public struct TasksReducer: Reducer {
    @CasePathable
    public enum Action {
        public struct Data: Sendable {
            public let tasks: [DWTask]
            public let tasksOccurrences: IdentifiedArrayOf<OccurrenceRecord>
        }

        case task
        case dataResponse(Result<Data, Error>)
        case todayButtonTapped
        case dateStripTapped(Date)
        case addTaskButtonTapped
        case completionChanged(TaskOccurrenceID, Bool)
        case startClock
        case clockTick
    }

    @Dependency(\.date) var dateGenerator
    @Dependency(\.uuid) var uuid
    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock
    @Dependency(\.tasksClient) var tasksClient
    @Dependency(\.occurrencesClient) var occurrencesClient

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.hasLoadedData, !state.isLoading else { return .none }

                state.isLoading = true
                state.errorMessage = nil
                state.now = dateGenerator.now
                updateDate(dateGenerator.now, in: &state)

                return .run { send in
                    try await send(.dataResponse(.success(Action.Data(
                        tasks: tasksClient.fetch(),
                        tasksOccurrences: occurrencesClient.fetch()
                    ))))
                } catch: { error, send in
                    await send(.dataResponse(.failure(error)))
                }

            case .dataResponse(let result):
                state.isLoading = false
                switch result {
                case .success(let data):
                    state.tasks = data.tasks
                    state.tasksOccurrences = data.tasksOccurrences
                    state.hasLoadedData = true
                    state.errorMessage = nil
                case .failure(let error):
                    state.errorMessage = error.localizedDescription
                }
                return .none

            case .todayButtonTapped:
                let now = dateGenerator.now
                if !calendar.isDate(state.selectedDate, inSameDayAs: now) {
                    state.dateStripResetID = uuid()
                }
                state.now = now
                updateDate(now, in: &state)
                if state.todayLayout == .zones {
                    state.zonesResetID = uuid()
                }
                return .none

            case .dateStripTapped(let date):
                guard state.selectedDate != date else { return .none }

                updateDate(date, in: &state)
                return .none

            case .addTaskButtonTapped:
                // TODO: open add task screen
                return .none

            case let .completionChanged(id, isCompleted):
                guard id.day == state.selectedLocalDate,
                      state.scheduledTasks.contains(where: { $0.id == id.taskID }) else { return .none }

                if isCompleted {
                    guard state.tasksOccurrences[id: id]?.isCompleted != true else { return .none }
                    do {
                        state.tasksOccurrences[id: id] = try OccurrenceRecord(
                            id: id, outcome: .completed(at: dateGenerator.now)
                        )
                    } catch {
                        state.errorMessage = error.localizedDescription
                    }
                } else {
                    state.tasksOccurrences.remove(id: id)
                }
                // TODO: persist the changed occurrence when the storage client is ready.
                return .none

            case .startClock:
                return .run { [clock] send in
                    await send(.clockTick)
                    for await _ in clock.timer(interval: .seconds(60)) {
                        await send(.clockTick)
                    }
                }
                .cancellable(id: CancelID.clock, cancelInFlight: true)

            case .clockTick:
                let wasViewingToday = state.calendar.isDate(state.selectedDate, inSameDayAs: state.now)
                state.now = dateGenerator.now
                // Follow midnight only when the user was viewing today, not another day.
                updateDate(wasViewingToday ? state.now : state.selectedDate, in: &state)
                return .none
            }
        }
    }

    public init() {}

    private func updateDate(_ date: Date, in state: inout State) {
        state.calendar = calendar
        state.selectedDate = date
        state.selectedLocalDate = try? LocalDate(date, in: calendar.timeZone)
    }
}
