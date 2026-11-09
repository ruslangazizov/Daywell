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
        case storeChanged
        case dataResponse(Result<Data, Error>)
        case todayButtonTapped
        case dateStripTapped(Date)
        case addTaskButtonTapped
        case planTaskAtHour(Int)
        case editTask(DWTask)
        case taskEditor(PresentationAction<TaskEditorReducer.Action>)
        case detailsChanged(TaskOccurrenceID?)
        case editDetailsTapped
        case completionChanged(TaskOccurrenceID, Bool)
        case completionSaveResponse(TaskOccurrenceID, previous: OccurrenceRecord?, saved: OccurrenceRecord?, Result<Void, Error>)
        case moreStatsButtonTapped
        case habitStatisticsChanged(UUID?)
        case dismissError
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
            case .task, .storeChanged:
                if case .storeChanged = action {
                    state.storeRefreshPending = true
                    guard !state.isLoading, state.savingOccurrenceIDs.isEmpty, state.taskEditor == nil else { return .none }
                } else {
                    guard !state.hasLoadedData, !state.isLoading else { return .none }
                    state.now = dateGenerator.now
                    updateDate(dateGenerator.now, in: &state)
                }
                state.storeRefreshPending = false
                state.isLoading = true
                state.errorMessage = nil

                return .run { send in
                    async let tasks = tasksClient.fetch()
                    async let occurrences = occurrencesClient.fetch()
                    try await send(.dataResponse(.success(Action.Data(
                        tasks: tasks,
                        tasksOccurrences: occurrences
                    ))))
                } catch: { error, send in
                    await send(.dataResponse(.failure(error)))
                }

            case .dataResponse(let result):
                state.isLoading = false
                switch result {
                case .success(let data):
                    state.tasks = data.tasks
                    // Keep optimistic toggles while their local writes are in flight.
                    var occurrences = data.tasksOccurrences
                    for id in state.savingOccurrenceIDs {
                        occurrences[id: id] = state.tasksOccurrences[id: id]
                    }
                    state.tasksOccurrences = occurrences
                    state.hasLoadedData = true
                    state.errorMessage = nil
                case .failure(let error):
                    state.errorMessage = error.localizedDescription
                }
                return state.storeRefreshPending ? .send(.storeChanged) : .none

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

            case .detailsChanged(let id):
                if let id {
                    guard id.day == state.selectedLocalDate,
                          state.scheduledTasks.contains(where: { $0.id == id.taskID }) else { return .none }
                }
                state.detailsID = id
                state.habitStatisticsID = nil
                return .none

            case .editDetailsTapped:
                guard let id = state.detailsID, state.taskEditor == nil,
                      let task = state.tasks.first(where: { $0.id == id.taskID }) else { return .none }
                state.taskEditor = TaskEditorReducer.State(task: task, calendar: calendar)
                return .none

            case let .planTaskAtHour(hour):
                guard (0..<24).contains(hour), state.taskEditor == nil else { return .none }
                let now = dateGenerator.now
                // Pick the next occurrence of this wall-clock hour, never a past time.
                guard let planned = calendar.nextDate(after: now, matching: DateComponents(hour: hour, minute: 0),
                                                       matchingPolicy: .nextTime) else { return .none }
                state.taskEditor = TaskEditorReducer.State(
                    id: uuid(), selectedDate: planned, now: planned,
                    calendar: calendar, duration: state.defaultTaskDuration
                )
                return .none

            case let .editTask(task):
                guard state.taskEditor == nil, !task.isArchived else { return .none }
                state.taskEditor = TaskEditorReducer.State(task: task, calendar: calendar)
                return .none

            case .addTaskButtonTapped:
                guard state.taskEditor == nil else { return .none }
                state.taskEditor = TaskEditorReducer.State(
                    id: uuid(), selectedDate: state.selectedDate, now: dateGenerator.now,
                    calendar: calendar, duration: state.defaultTaskDuration
                )
                return .none

            case .taskEditor(.presented(.delegate(.didSave(let task)))):
                state.tasks.removeAll { $0.id == task.id }
                state.tasks.append(task)
                state.taskEditor = nil
                return state.storeRefreshPending ? .send(.storeChanged) : .none

            case .taskEditor(.dismiss):
                return state.storeRefreshPending ? .send(.storeChanged) : .none

            case .taskEditor:
                return .none

            case let .completionChanged(id, isCompleted):
                guard id.day == state.selectedLocalDate || id == state.detailsID,
                      state.tasks.contains(where: {
                          $0.id == id.taskID && !$0.isArchived && $0.schedule.occurs(on: id.day)
                      }) else { return .none }

                let previous = state.tasksOccurrences[id: id]
                if isCompleted {
                    guard previous?.isCompleted != true else { return .none }
                    do {
                        state.tasksOccurrences[id: id] = try OccurrenceRecord(
                            id: id, outcome: .completed(at: dateGenerator.now)
                        )
                    } catch {
                        state.errorMessage = error.localizedDescription
                        return .none
                    }
                } else {
                    guard previous != nil else { return .none }
                    state.tasksOccurrences.remove(id: id)
                }
                state.errorMessage = nil
                // Coalesce rapid toggles while a write is running. The next write
                // starts only after acknowledgement, so an older write cannot win.
                guard state.savingOccurrenceIDs.insert(id).inserted else { return .none }
                return persist(id, record: state.tasksOccurrences[id: id], previous: previous)

            case let .completionSaveResponse(id, previous, saved, result):
                switch result {
                case .success:
                    let desired = state.tasksOccurrences[id: id]
                    if desired != saved {
                        return persist(id, record: desired, previous: saved)
                    }
                case .failure(let error):
                    state.tasksOccurrences[id: id] = previous
                    state.errorMessage = error.localizedDescription
                }
                state.savingOccurrenceIDs.remove(id)
                return state.storeRefreshPending ? .send(.storeChanged) : .none

            case .moreStatsButtonTapped:
                guard let id = state.detailsID,
                      state.tasks.contains(where: { $0.id == id.taskID && $0.isHabit && !$0.isArchived })
                else { return .none }
                state.habitStatisticsID = id.taskID
                return .none

            case let .habitStatisticsChanged(id):
                guard id == nil || id == state.habitStatisticsID else { return .none }
                state.habitStatisticsID = id
                return .none

            case .dismissError:
                state.errorMessage = nil
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
        .ifLet(\.$taskEditor, action: \.taskEditor) {
            TaskEditorReducer()
        }
    }

    public init() {}

    private func persist(
        _ id: TaskOccurrenceID,
        record: OccurrenceRecord?,
        previous: OccurrenceRecord?
    ) -> Effect<Action> {
        .run { send in
            if let record {
                try await occurrencesClient.save(record)
            } else {
                try await occurrencesClient.delete(id)
            }
            await send(.completionSaveResponse(id, previous: previous, saved: record, .success(())))
        } catch: { error, send in
            await send(.completionSaveResponse(id, previous: previous, saved: record, .failure(error)))
        }
    }

    private func updateDate(_ date: Date, in state: inout State) {
        state.calendar = calendar
        state.selectedDate = date
        state.selectedLocalDate = try? LocalDate(date, in: calendar.timeZone)
    }
}
