import ComposableArchitecture
import Persistence

public struct CustomTaskDurationReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        public var hours: Int
        public var minutes: Int

        public init(duration: TaskDuration) {
            hours = duration.minutes / 60
            minutes = duration.minutes % 60
        }

        public var duration: TaskDuration {
            TaskDuration(minutes: hours * 60 + minutes)
        }

        public var canSave: Bool {
            duration.minutes > 0
        }

        // Extend the wheel as needed instead of imposing a 24-hour duration limit.
        public var hourOptions: ClosedRange<Int> {
            0...max(24, hours + 12)
        }
    }

    @CasePathable
    public enum Action {
        case didChooseHours(Int)
        case didChooseMinutes(Int)
        case didTapCancel
        case didTapSave
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case didSave(TaskDuration)
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didChooseHours(let hours):
                state.hours = hours
                return .none

            case .didChooseMinutes(let minutes):
                state.minutes = minutes
                return .none

            case .didTapCancel:
                return .run { _ in await dismiss() }

            case .didTapSave:
                guard state.canSave else { return .none }

                return .run { [duration = state.duration] send in
                    await send(.delegate(.didSave(duration)))
                    await dismiss()
                }

            case .delegate:
                return .none
            }
        }
    }
}
