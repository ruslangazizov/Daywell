import Clients
import ComposableArchitecture
import Testing
@testable import SettingsFeature

@MainActor
struct TaskRemindersSettingsTests {
    @Test func enablingWaitsForAuthorizationAndDenialTurnsOff() async {
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.notificationsClient.requestAuthorization = { .denied }
        }
        await store.send(.didChangeTaskRemindersEnabled(true)) {
            $0.$taskRemindersEnabled.withLock { $0 = true }
            $0.isRequestingNotifications = true
        }
        await store.receive(\.notificationAuthorizationResponse) {
            $0.isRequestingNotifications = false
            $0.$taskRemindersEnabled.withLock { $0 = false }
            $0.notificationsAlert = SettingsReducer.notificationsDeniedAlert
        }
    }

    @Test func grantEnablesReminders() async {
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.notificationsClient.requestAuthorization = { .authorized }
        }
        await store.send(.didChangeTaskRemindersEnabled(true)) {
            $0.$taskRemindersEnabled.withLock { $0 = true }
            $0.isRequestingNotifications = true
        }
        await store.receive(\.notificationAuthorizationResponse) { $0.isRequestingNotifications = false }
        #expect(store.state.taskRemindersEnabled)
        await store.send(.didChangeTaskRemindersEnabled(true))
    }

    @Test func disablingNeverRequestsPermissionAndIgnoresLateGrant() async {
        var state = SettingsReducer.State()
        state.$taskRemindersEnabled.withLock { $0 = true }
        state.isRequestingNotifications = true
        let store = TestStore(initialState: state) { SettingsReducer() }
        await store.send(.didChangeTaskRemindersEnabled(false)) {
            $0.$taskRemindersEnabled.withLock { $0 = false }
            $0.isRequestingNotifications = false
        }
        await store.send(.notificationAuthorizationResponse(.success(.authorized)))
        #expect(!store.state.taskRemindersEnabled)
    }

    @Test func revokingSystemPermissionDisablesOnReturn() async {
        let state = SettingsReducer.State()
        state.$taskRemindersEnabled.withLock { $0 = true }
        let store = TestStore(initialState: state) { SettingsReducer() } withDependencies: {
            $0.notificationsClient.authorizationStatus = { .denied }
        }
        await store.send(.checkNotificationAuthorization)
        await store.receive(\.notificationStatusChecked) {
            $0.$taskRemindersEnabled.withLock { $0 = false }
        }
    }
}
