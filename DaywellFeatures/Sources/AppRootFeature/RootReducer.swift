import ComposableArchitecture
import TasksFeature
import StatisticsFeature
import SettingsFeature

public struct RootReducer: Reducer {
    public enum Tab: Hashable {
        case today
        case statistics
        case settings
    }

    @ObservableState
    public struct State: Equatable {
        var selectedTab: Tab = .today
        var tasks = TasksReducer.State()
        var statistics = StatisticsReducer.State()
        var settings = SettingsReducer.State()
    }

    @CasePathable
    public enum Action {
        case tabSelected(Tab)
        case tasks(TasksReducer.Action)
        case statistics(StatisticsReducer.Action)
        case settings(SettingsReducer.Action)
    }

    public var body: some Reducer<State, Action> {
        Scope(\.tasks, action: \.tasks) {
            TasksReducer()
        }

        Scope(\.statistics, action: \.statistics) {
            StatisticsReducer()
        }

        Scope(\.settings, action: \.settings) {
            SettingsReducer()
        }

        Reduce { state, action in
            switch action {
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            case .tasks, .statistics, .settings:
                return .none
            }
        }
    }
}
