import ComposableArchitecture
import Clients
import Domain
import Foundation

public struct StatisticsReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        var period: StatisticsPeriod = .week
        // TODO: check whether should be replaced with IdentifiedArrayOf<DWTask>
        var tasks: [DWTask] = []
        // TODO: check for unnecessary conversions to Array(occurrences)
        var occurrences: IdentifiedArrayOf<OccurrenceRecord> = []
        var now: Date = .now
        var calendar: Calendar = .current
        var isLoading = false
        var refreshRequested = false
        var hasLoaded = false
        var errorMessage: String?
        var destination: StatisticsDestination?
        var path: [StatisticsDestination] = []

        var summary: StatisticsSummary {
            StatisticsSummary(
                tasks: tasks,
                occurrences: Array(occurrences),
                period: period,
                now: now,
                calendar: calendar
            )
        }

        public func taskForEditing(id: UUID) -> DWTask? {
            tasks.first { $0.id == id && $0.isHabit && !$0.isArchived }
        }

        public init() {}
    }

    @CasePathable
    public enum Action {
        public struct Data: Sendable {
            let tasks: [DWTask]
            let occurrences: IdentifiedArrayOf<OccurrenceRecord>
        }
        case task
        case startClock
        case clockTick
        case dataResponse(Result<Data, Error>)
        case periodChanged(StatisticsPeriod)
        case destinationChanged(StatisticsDestination?)
        case pathChanged([StatisticsDestination])
        case planTask(Int)
        case editHabit(UUID)
        case goToToday
    }

    @Dependency(\.tasksClient) var tasksClient
    @Dependency(\.occurrencesClient) var occurrencesClient
    @Dependency(\.date) var date
    @Dependency(\.calendar) var calendar
    @Dependency(\.continuousClock) var clock

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.isLoading else {
                    state.refreshRequested = true
                    return .none
                }

                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    async let tasks = tasksClient.fetch()
                    async let occurrences = occurrencesClient.fetch()
                    try await send(.dataResponse(.success(Action.Data(tasks: tasks, occurrences: occurrences))))
                } catch: { error, send in
                    await send(.dataResponse(.failure(error)))
                }
            case let .dataResponse(result):
                state.isLoading = false
                switch result {
                case let .success(data):
                    state.tasks = data.tasks
                    state.occurrences = data.occurrences
                    state.now = date.now
                    state.calendar = calendar
                    state.hasLoaded = true
                    state.errorMessage = nil
                case .failure:
                    state.errorMessage = "Couldn’t update statistics. Your last results are still here."
                }
                let refreshRequested = state.refreshRequested
                state.refreshRequested = false
                return refreshRequested ? .send(.task) : .none
            case .startClock:
                return .run { [clock] send in
                    for await _ in clock.timer(interval: .seconds(60)) {
                        await send(.clockTick)
                    }
                }
            case .clockTick:
                guard state.hasLoaded,
                      !calendar.isDate(state.now, inSameDayAs: date.now) || state.calendar.timeZone != calendar.timeZone
                else { return .none }
                return .send(.task)
            case let .periodChanged(period):
                state.period = period
                return .none
            case let .destinationChanged(destination):
                if let destination, destination != .about {
                    state.path.append(destination)
                } else {
                    state.destination = destination
                }
                return .none
            case let .pathChanged(path):
                state.path = path
                return .none
            case .planTask, .editHabit, .goToToday:
                return .none
            }
        }
    }

    public init() {}
}
