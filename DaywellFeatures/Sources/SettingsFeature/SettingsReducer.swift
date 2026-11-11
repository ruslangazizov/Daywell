import Clients
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Persistence

private nonisolated enum CancelID: Hashable, Sendable { case observation, check, notificationPermission, badgePermission }

public struct SettingsReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        @Shared(Preferences.appearance) var appearance
        @Shared(Preferences.todayLayout) var todayLayout
        @Shared(Preferences.dailyZones) var dailyZones
        @Presents var editDayZone: EditDayZoneReducer.State?
        @Presents var zonesConfirmation: ConfirmationDialogState<Action.DailyZonesAction.Confirmation>?
        @Shared(Preferences.customCardWidthPercentage) var customCardWidthPercentage
        @Shared(Preferences.firstDayOfWeek) var firstDayOfWeek
        @Shared(Preferences.taskDurations) var taskDurations
        @Shared(Preferences.defaultTaskDuration) var defaultTaskDuration
        @Presents var customTaskDuration: CustomTaskDurationReducer.State?
        @Shared(Preferences.taskRemindersEnabled) var taskRemindersEnabled
        @Shared(Preferences.appIconBadgeEnabled) var appIconBadgeEnabled
        var isRequestingNotifications = false
        var isRequestingBadgeAuthorization = false
        var reminderSchedulingError: String?
        @Presents var notificationsAlert: AlertState<Action.NotificationsAlert>?
        var iCloudStatus: ICloudSyncStatus
        var lastConfirmedSync: Date? = nil
        var isCheckingICloud = false
        var iCloudDataRevision = 0
        var iCloudSnapshotVersion = 0

        var sortedDailyZones: [DayZone] {
            dailyZones.sorted { $0.window.start < $1.window.start }
        }

        public init(
            iCloudStatus: ICloudSyncStatus = .notChecked
        ) {
            self.iCloudStatus = iCloudStatus
        }
    }

    @CasePathable
    public enum Action {
        case task
        case didChooseAppearance(DWAppearance)
        case didChooseTodayLayout(TodayLayout)
        case didChooseCustomCardWidthPercentage(Double)
        case didChooseFirstDayOfWeek(FirstDayOfWeek)
        case taskDuration(TaskDurationAction)
        case dailyZones(DailyZonesAction)
        case didChangeTaskRemindersEnabled(Bool)
        case checkNotificationAuthorization
        case notificationStatusChecked(NotificationAuthorization)
        case notificationAuthorizationResponse(Result<NotificationAuthorization, Error>)
        case notificationsAlert(PresentationAction<NotificationsAlert>)
        case reminderSchedulingResponse(String?)
        case didChangeAppIconBadgeEnabled(Bool)
        case checkBadgeAuthorization
        case badgeStatusChecked(NotificationAuthorization)
        case badgeAuthorizationResponse(Result<NotificationAuthorization, Error>)
        case didTapCheckICloudStatus
        case iCloudStatusChanged(ICloudSnapshot)
        case iCloudCheckResponse(ICloudSnapshot)
        case iCloudDataChanged

        @CasePathable
        public enum NotificationsAlert: Equatable {
            case openSettings
        }

        @CasePathable
        public enum TaskDurationAction {
            case didChooseDefault(TaskDuration)
            case didTapCustom
            case custom(PresentationAction<CustomTaskDurationReducer.Action>)
        }

        @CasePathable
        public enum DailyZonesAction {
            case didTapAdd
            case didTapZone(UUID)
            case didTapDelete(UUID)
            case didTapRestoreDefaults
            case editor(PresentationAction<EditDayZoneReducer.Action>)
            case confirmation(PresentationAction<Confirmation>)

            @CasePathable
            public enum Confirmation: Equatable {
                case restoreDefaults
            }
        }
    }

    @Dependency(\.userInterfaceStyleClient) var userInterfaceStyleClient
    @Dependency(\.iCloudClient) var iCloudClient
    @Dependency(\.notificationsClient) var notificationsClient

    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return .merge(
                    .run { [appearance = state.appearance] _ in
                        await userInterfaceStyleClient.override(appearance.userInterfaceStyle)
                    },
                    .run { send in
                        for await snapshot in await iCloudClient.observe() {
                            await send(.iCloudStatusChanged(snapshot))
                        }
                    }.cancellable(id: CancelID.observation, cancelInFlight: true),
                    .send(.didTapCheckICloudStatus)
                )

            case .didChooseAppearance(let appearance):
                state.$appearance.withLock { $0 = appearance }
                return .run { _ in
                    await userInterfaceStyleClient.override(appearance.userInterfaceStyle)
                }

            case .didChooseTodayLayout(let layout):
                state.$todayLayout.withLock { $0 = layout }
                return .none

            case .dailyZones(let action):
                switch action {
                case .didTapAdd:
                    state.editDayZone = .init(id: uuid(), zones: state.dailyZones)

                case .didTapZone(let id):
                    guard let zone = state.dailyZones.first(where: { $0.id == id }) else { return .none }

                    state.editDayZone = .init(zone: zone, otherZones: state.dailyZones)

                case .didTapDelete(let id):
                    state.$dailyZones.withLock { $0.removeAll { $0.id == id } }

                case .didTapRestoreDefaults:
                    state.zonesConfirmation = Self.restoreZonesConfirmation

                case .confirmation(.presented(.restoreDefaults)):
                    state.$dailyZones.withLock { $0 = DayZone.defaults }

                case .editor(.presented(.delegate(.didSave(let zone)))):
                    // Validate against the latest collection, not just the editor's snapshot.
                    let zones = (state.dailyZones.filter { $0.id != zone.id } + [zone])
                        .sorted { $0.window.start < $1.window.start }
                    do {
                        try DayZone.validate(zones)
                        state.$dailyZones.withLock { $0 = zones }
                        state.editDayZone = nil
                    } catch {
                        let otherZones = state.dailyZones.filter { $0.id != zone.id }
                        state.editDayZone?.otherZones = otherZones
                        state.editDayZone?.saveError = error.localizedDescription
                    }

                case .editor, .confirmation:
                    break
                }
                return .none

            case .didChooseCustomCardWidthPercentage(let percentage):
                state.$customCardWidthPercentage.withLock { $0 = percentage }
                return .none

            case .didChooseFirstDayOfWeek(let day):
                state.$firstDayOfWeek.withLock { $0 = day }
                return .none

            case .taskDuration(let taskDurationAction):
                switch taskDurationAction {
                case .didChooseDefault(let duration):
                    state.$defaultTaskDuration.withLock { $0 = duration }
                    return .none

                case .didTapCustom:
                    state.customTaskDuration = CustomTaskDurationReducer.State(
                        duration: state.defaultTaskDuration
                    )
                    return .none

                case .custom(.presented(.delegate(.didSave(let duration)))):
                    state.$taskDurations.withLock { durations in
                        if !durations.contains(duration) {
                            durations.append(duration)
                            durations.sort { $0.minutes < $1.minutes }
                        }
                    }
                    state.$defaultTaskDuration.withLock { $0 = duration }
                    return .none

                case .custom:
                    return .none
                }

            case .didChangeTaskRemindersEnabled(let isEnabled):
                state.reminderSchedulingError = nil
                if !isEnabled {
                    state.$taskRemindersEnabled.withLock { $0 = false }
                    state.isRequestingNotifications = false
                    return .cancel(id: CancelID.notificationPermission)
                }
                guard !state.taskRemindersEnabled, !state.isRequestingNotifications else { return .none }
                state.$taskRemindersEnabled.withLock { $0 = true }
                state.isRequestingNotifications = true
                return .run { send in
                    await send(.notificationAuthorizationResponse(Result {
                        try await notificationsClient.requestAuthorization()
                    }))
                }.cancellable(id: CancelID.notificationPermission, cancelInFlight: true)

            case .notificationAuthorizationResponse(let result):
                guard state.isRequestingNotifications else { return .none }
                state.isRequestingNotifications = false
                switch result {
                case .success(.authorized):
                    state.$taskRemindersEnabled.withLock { $0 = true }
                case .success:
                    state.$taskRemindersEnabled.withLock { $0 = false }
                    state.notificationsAlert = Self.openSettingsAlert(
                        title: "Notifications are off",
                        message: "Allow notifications for Daywell in iOS Settings, then turn Task reminders on again."
                    )
                case .failure:
                    state.$taskRemindersEnabled.withLock { $0 = false }
                    state.notificationsAlert = AlertState {
                        TextState("Could not enable reminders")
                    } actions: {
                        ButtonState(role: .cancel) { TextState("OK") }
                    } message: {
                        TextState("Please try turning Task reminders on again.")
                    }
                }
                return .none

            case .checkNotificationAuthorization:
                guard state.taskRemindersEnabled, !state.isRequestingNotifications else { return .none }
                return .run { send in
                    await send(.notificationStatusChecked(notificationsClient.authorizationStatus()))
                }

            case .notificationStatusChecked(let status):
                guard !state.isRequestingNotifications else { return .none }
                if status != .authorized { state.$taskRemindersEnabled.withLock { $0 = false } }
                return .none

            case .notificationsAlert(.presented(.openSettings)):
                return .run { _ in await notificationsClient.openSettings() }

            case .notificationsAlert:
                return .none

            case .reminderSchedulingResponse(let error):
                state.reminderSchedulingError = error
                return .none

            case .didChangeAppIconBadgeEnabled(let isEnabled):
                state.reminderSchedulingError = nil
                if !isEnabled {
                    state.$appIconBadgeEnabled.withLock { $0 = false }
                    state.isRequestingBadgeAuthorization = false
                    return .cancel(id: CancelID.badgePermission)
                }

                guard !state.appIconBadgeEnabled, !state.isRequestingBadgeAuthorization else { return .none }

                state.$appIconBadgeEnabled.withLock { $0 = true }
                state.isRequestingBadgeAuthorization = true
                return .run { send in
                    await send(.badgeAuthorizationResponse(Result {
                        try await notificationsClient.requestBadgeAuthorization()
                    }))
                }.cancellable(id: CancelID.badgePermission, cancelInFlight: true)

            case .badgeAuthorizationResponse(let result):
                guard state.isRequestingBadgeAuthorization else { return .none }

                state.isRequestingBadgeAuthorization = false
                switch result {
                case .success(.authorized):
                    state.$appIconBadgeEnabled.withLock { $0 = true }
                case .success:
                    state.$appIconBadgeEnabled.withLock { $0 = false }
                    state.notificationsAlert = Self.openSettingsAlert(
                        title: "App icon badges are off",
                        message: "Allow Badges for Daywell in iOS Settings, then turn App icon badge on again."
                    )
                case .failure:
                    state.$appIconBadgeEnabled.withLock { $0 = false }
                    state.notificationsAlert = Self.couldNotEnableAppIconBadgeAlert
                }
                return .none

            case .checkBadgeAuthorization:
                guard state.appIconBadgeEnabled, !state.isRequestingBadgeAuthorization else { return .none }

                return .run { send in
                    await send(.badgeStatusChecked(notificationsClient.badgeAuthorizationStatus()))
                }

            case .badgeStatusChecked(let status):
                guard !state.isRequestingBadgeAuthorization else { return .none }

                if status != .authorized { state.$appIconBadgeEnabled.withLock { $0 = false } }
                return .none

            case .didTapCheckICloudStatus:
                guard !state.isCheckingICloud else { return .none }
                state.isCheckingICloud = true
                return .run { send in
                    await send(.iCloudCheckResponse(iCloudClient.refresh()))
                }.cancellable(id: CancelID.check, cancelInFlight: true)

            case .iCloudStatusChanged(let snapshot), .iCloudCheckResponse(let snapshot):
                if case .iCloudCheckResponse = action { state.isCheckingICloud = false }
                guard snapshot.version >= state.iCloudSnapshotVersion else { return .none }
                state.iCloudSnapshotVersion = snapshot.version
                state.iCloudStatus = snapshot.status
                state.lastConfirmedSync = snapshot.lastConfirmedSync
                let didChangeData = snapshot.dataRevision != state.iCloudDataRevision
                state.iCloudDataRevision = snapshot.dataRevision
                return didChangeData ? .send(.iCloudDataChanged) : .none

            case .iCloudDataChanged:
                return .none
            }
        }
        .ifLet(\.$customTaskDuration, action: \.taskDuration.custom) {
            CustomTaskDurationReducer()
        }
        .ifLet(\.$editDayZone, action: \.dailyZones.editor) {
            EditDayZoneReducer()
        }
        .ifLet(\.$notificationsAlert, action: \.notificationsAlert)
        .ifLet(\.$zonesConfirmation, action: \.dailyZones.confirmation)
    }

    // MARK: - Private

    private static func openSettingsAlert(
        title: String,
        message: String
    ) -> AlertState<Action.NotificationsAlert> {
        AlertState {
            TextState(title)
        } actions: {
            ButtonState(action: .openSettings) { TextState("Open Settings") }
            ButtonState(role: .cancel) { TextState("Not now") }
        } message: {
            TextState(message)
        }
    }

    private static var couldNotEnableAppIconBadgeAlert: AlertState<Action.NotificationsAlert> {
        AlertState { TextState("Could not enable app icon badge") } actions: {
            ButtonState(role: .cancel) { TextState("OK") }
        } message: {
            TextState("Please try turning App icon badge on again.")
        }
    }

    private static var restoreZonesConfirmation: ConfirmationDialogState<Action.DailyZonesAction.Confirmation> {
        ConfirmationDialogState {
            TextState("Restore default zones?")
        } actions: {
            ButtonState(role: .destructive, action: .send(.restoreDefaults, animation: .default)) {
                TextState("Restore defaults")
            }
            ButtonState(role: .cancel) { TextState("Cancel") }
        } message: {
            TextState("Your current zones will be replaced with Morning, Day and Evening")
        }
    }
}
