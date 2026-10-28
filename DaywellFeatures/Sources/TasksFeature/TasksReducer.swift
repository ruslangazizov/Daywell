import Foundation
import Domain
import Clients
import Persistence
import ComposableArchitecture

private nonisolated enum CancelID: Hashable, Sendable { case clock }

public struct TasksReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        var selectedDate: Date
        var selectedLocalDate: LocalDate?
        var dateStripResetID = UUID()
        var tasks: [DWTask]
        var tasksOccurrences: IdentifiedArrayOf<OccurrenceRecord>
        var zones: [DayZone]
        var now: Date
        var calendar: Calendar
        var hasLoadedData: Bool
        var isLoading = false
        var errorMessage: String?

        public init(
            selectedDate: Date = .now,
            selectedLocalDate: LocalDate? = nil,
            tasks: [DWTask] = [],
            tasksOccurrences: IdentifiedArrayOf<OccurrenceRecord> = [],
            zones: [DayZone] = [],
            now: Date? = nil,
            calendar: Calendar = .current,
            hasLoadedData: Bool? = nil
        ) {
            self.selectedDate = selectedDate
            self.selectedLocalDate = selectedLocalDate ?? (try? LocalDate(selectedDate, in: calendar.timeZone))
            self.tasks = tasks
            self.tasksOccurrences = tasksOccurrences
            self.zones = zones
            self.now = now ?? selectedDate
            self.calendar = calendar
            self.hasLoadedData = hasLoadedData ?? !tasks.isEmpty
        }

        var scheduledTasks: [DWTask] {
            guard let day = selectedLocalDate else { return [] }
            return tasks.filter { !$0.isArchived && $0.schedule.occurs(on: day) }
        }

        var completionSummary: TodayCompletionSummaryModel? {
            guard hasLoadedData, let today = selectedLocalDate else { return nil }

            let tasksForToday = scheduledTasks
            let completedTasksCount = tasksForToday.count { task in
                let id = TaskOccurrenceID(taskID: task.id, day: today)
                return tasksOccurrences[id: id]?.isCompleted == true
            }
            return TodayCompletionSummaryModel(
                completedCount: completedTasksCount,
                totalCount: tasksForToday.count
            )
        }

        var timeline: TodayTimelineViewModel {
            TodayTimelineViewModel(
                tasks: scheduledTasks,
                day: selectedLocalDate,
                zones: zones,
                occurrences: Dictionary(uniqueKeysWithValues: tasksOccurrences.map { ($0.id, $0) }),
                now: now,
                calendar: calendar
            )
        }
    }

    @CasePathable
    public enum Action {
        public struct Data: Sendable {
            public let tasks: [DWTask]
            public let tasksOccurrences: IdentifiedArrayOf<OccurrenceRecord>
            public let zones: [DayZone]
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
    @Dependency(\.zonesClient) var zonesClient
    @Shared(Preferences.firstDayOfWeek) var firstDayOfWeek

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
                        tasksOccurrences: occurrencesClient.fetch(),
                        zones: zonesClient.fetch()
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
                    state.zones = data.zones
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
