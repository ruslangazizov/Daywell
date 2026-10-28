import Clients
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Persistence

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
        var iCloudStatus: ICloudSyncStatus
        var lastConfirmedSync: Date?

        public init(
            iCloudStatus: ICloudSyncStatus = .notChecked,
            lastConfirmedSync: Date? = nil
        ) {
            self.iCloudStatus = iCloudStatus
            self.lastConfirmedSync = lastConfirmedSync
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
        case didChangeAppIconBadgeEnabled(Bool)
        case didTapCheckICloudStatus

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
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [appearance = state.appearance] _ in
                    await userInterfaceStyleClient.override(appearance.userInterfaceStyle)
                }

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
                // TODO: apply this preference to calendars.
                return .none

            case .taskDuration(let taskDurationAction):
                switch taskDurationAction {
                case .didChooseDefault(let duration):
                    state.$defaultTaskDuration.withLock { $0 = duration }
                    // TODO: apply this preference to new tasks.
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
                    // TODO: apply this preference to new tasks.
                    return .none

                case .custom:
                    return .none
                }

            case .didChangeTaskRemindersEnabled(let isEnabled):
                state.$taskRemindersEnabled.withLock { $0 = isEnabled }
                // TODO: update reminder scheduling on this device.
                return .none

            case .didChangeAppIconBadgeEnabled(let isEnabled):
                state.$appIconBadgeEnabled.withLock { $0 = isEnabled }
                // TODO: update the app icon badge.
                return .none

            case .didTapCheckICloudStatus:
                // TODO: request observed account/sync status from an iCloud client.
                // Keep the current status until a real response is available.
                return .none
            }
        }
        .ifLet(\.$customTaskDuration, action: \.taskDuration.custom) {
            CustomTaskDurationReducer()
        }
        .ifLet(\.$editDayZone, action: \.dailyZones.editor) {
            EditDayZoneReducer()
        }
        .ifLet(\.$zonesConfirmation, action: \.dailyZones.confirmation)
    }

    static var restoreZonesConfirmation: ConfirmationDialogState<Action.DailyZonesAction.Confirmation> {
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
