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
        @SharedReader(Preferences.appIconBadgeEnabled) var appIconBadgeEnabled
        @SharedReader(Preferences.todayLayout) var todayLayout
        @SharedReader(Preferences.dailyZones) var dailyZones
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
        case synchronizeNotifications
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
            case .synchronizeNotifications:
                let configuration = NotificationConfiguration(
                    remindersEnabled: state.taskRemindersEnabled, badgeEnabled: state.appIconBadgeEnabled,
                    layout: state.todayLayout, zones: state.dailyZones
                )
                return .run { send in
                    do {
                        try await notificationsClient.synchronize(configuration)
                        await send(.settings(.reminderSchedulingResponse(nil)))
                    } catch {
                        await send(.settings(.reminderSchedulingResponse(
                            "Notifications could not be updated. Reopen Daywell to try again."
                        )))
                    }
                }
            case .settings(.task):
                return .merge(.send(.settings(.checkNotificationAuthorization)),
                              .send(.settings(.checkBadgeAuthorization)), .send(.synchronizeNotifications))
            case .settings(.badgeAuthorizationResponse),
                 .settings(.badgeStatusChecked),
                 .settings(.didChangeAppIconBadgeEnabled(false)),
                 .settings(.didChooseTodayLayout),
                 .settings(.dailyZones(.didTapDelete)),
                 .settings(.dailyZones(.confirmation(.presented(.restoreDefaults)))),
                 .settings(.dailyZones(.editor(.presented(.delegate(.didSave))))),
                 .settings(.notificationAuthorizationResponse),
                 .settings(.notificationStatusChecked),
                 .settings(.didChangeTaskRemindersEnabled(false)),
                 .tasks(.dataResponse(.success)):
                return .send(.synchronizeNotifications)
            case .tasks(.clockTick):
                return state.taskRemindersEnabled || state.appIconBadgeEnabled ? .send(.synchronizeNotifications) : .none
            case .becameActive:
                return .merge(
                    .send(.settings(.checkNotificationAuthorization)),
                    .send(.settings(.checkBadgeAuthorization)),
                    .send(.synchronizeNotifications),
                    .send(.settings(.didTapCheckICloudStatus)),
                    .send(.tasks(.storeChanged)),
                    .send(.statistics(.task))
                )
            case .settings(.iCloudDataChanged):
                return .merge(.send(.tasks(.storeChanged)), .send(.statistics(.task)), .send(.synchronizeNotifications))
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
                    .send(.synchronizeNotifications),
                    state.selectedTab == .statistics || state.tasks.habitStatisticsID != nil
                        ? .send(.statistics(.task)) : .none
                )
            case .tasks, .statistics, .settings:
                return .none
            }
        }
    }
}
