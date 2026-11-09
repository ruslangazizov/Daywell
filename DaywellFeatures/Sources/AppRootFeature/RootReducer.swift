import ComposableArchitecture
import Clients
import Domain
import Persistence
import TasksFeature
import StatisticsFeature
import SettingsFeature
import Foundation

public struct RootReducer: Reducer {
    public enum Tab: Hashable {
        case today
        case statistics
        case settings
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(Preferences.taskRemindersEnabled) var taskRemindersEnabled
        var selectedTab: Tab = .today
        var tasks = TasksReducer.State()
        var statistics = StatisticsReducer.State()
        var settings = SettingsReducer.State()
    }

    @CasePathable
    public enum Action {
        case task
        case reminderTapped(TaskOccurrenceID)
        case tabSelected(Tab)
        case synchronizeReminders
        case becameActive
        case tasks(TasksReducer.Action)
        case statistics(StatisticsReducer.Action)
        case settings(SettingsReducer.Action)
    }

    private nonisolated enum CancelID { case notificationResponses }

    @Dependency(\.notificationsClient) var notificationsClient

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
            case .task:
                return .merge(
                    .send(.settings(.task)),
                    .run { send in
                        for await id in await notificationsClient.responses() {
                            await send(.reminderTapped(id))
                        }
                    }.cancellable(id: CancelID.notificationResponses, cancelInFlight: true)
                )
            case .reminderTapped(let id):
                state.selectedTab = .today
                return .send(.tasks(.openReminder(id)))
            case .synchronizeReminders:
                return .run { [enabled = state.taskRemindersEnabled] send in
                    do {
                        try await notificationsClient.synchronize(enabled)
                        await send(.settings(.reminderSchedulingResponse(nil)))
                    } catch {
                        await send(.settings(.reminderSchedulingResponse(
                            "Reminders could not be updated. Reopen Daywell to try again."
                        )))
                    }
                }
            case .settings(.task):
                return .merge(.send(.settings(.checkNotificationAuthorization)), .send(.synchronizeReminders))
            case .settings(.notificationAuthorizationResponse),
                 .settings(.notificationStatusChecked),
                 .settings(.didChangeTaskRemindersEnabled(false)),
                 .tasks(.dataResponse(.success)):
                return .send(.synchronizeReminders)
            case .tasks(.clockTick):
                return state.taskRemindersEnabled ? .send(.synchronizeReminders) : .none
            case .becameActive:
                return .merge(
                    .send(.settings(.checkNotificationAuthorization)),
                    .send(.synchronizeReminders),
                    .send(.settings(.didTapCheckICloudStatus)),
                    .send(.tasks(.storeChanged)),
                    .send(.statistics(.task))
                )
            case .settings(.iCloudDataChanged):
                return .merge(.send(.tasks(.storeChanged)), .send(.statistics(.task)), .send(.synchronizeReminders))
            case let .tabSelected(tab):
                state.selectedTab = tab
                return .none
            case let .statistics(.planTask(hour)):
                return .send(.tasks(.planTaskAtHour(hour)))
            case let .statistics(.editHabit(id)):
                guard let task = state.statistics.taskForEditing(id: id) else { return .none }
                return .send(.tasks(.editTask(task)))
            case .statistics(.goToToday):
                state.selectedTab = .today
                return .send(.tasks(.todayButtonTapped))
            case .tasks(.completionSaveResponse(_, _, _, .success)),
                 .tasks(.taskEditor(.presented(.delegate(.didSave)))):
                // A write may finish after the user has switched tabs.
                return .merge(
                    .send(.synchronizeReminders),
                    state.selectedTab == .statistics || state.tasks.habitStatisticsID != nil
                        ? .send(.statistics(.task)) : .none
                )
            case .tasks, .statistics, .settings:
                return .none
            }
        }
    }
}
