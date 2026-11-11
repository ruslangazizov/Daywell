import Clients
import ComposableArchitecture
import Testing
@testable import SettingsFeature

@MainActor
struct AppIconBadgeSettingsTests {
    @Test func grantEnablesBadgeIndependentlyOfReminders() async {
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.notificationsClient.requestBadgeAuthorization = { .authorized }
        }
        await store.send(.didChangeAppIconBadgeEnabled(true)) {
            $0.$appIconBadgeEnabled.withLock { $0 = true }
            $0.isRequestingBadgeAuthorization = true
        }
        await store.receive(\.badgeAuthorizationResponse) { $0.isRequestingBadgeAuthorization = false }
        #expect(store.state.appIconBadgeEnabled)
        #expect(!store.state.taskRemindersEnabled)
    }

    @Test func denialTurnsBadgeOffAndOffersSettings() async {
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.notificationsClient.requestBadgeAuthorization = { .denied }
        }
        store.exhaustivity = .off
        await store.send(.didChangeAppIconBadgeEnabled(true))
        await store.receive(\.badgeAuthorizationResponse)
        #expect(!store.state.appIconBadgeEnabled)
        #expect(store.state.notificationsAlert != nil)
    }

    @Test func disablingIgnoresLatePermissionResult() async {
        var state = SettingsReducer.State()
        state.$appIconBadgeEnabled.withLock { $0 = true }
        state.isRequestingBadgeAuthorization = true
        let store = TestStore(initialState: state) { SettingsReducer() }
        await store.send(.didChangeAppIconBadgeEnabled(false)) {
            $0.$appIconBadgeEnabled.withLock { $0 = false }
            $0.isRequestingBadgeAuthorization = false
        }
        await store.send(.badgeAuthorizationResponse(.success(.authorized)))
    }

    @Test func revokingOnlyBadgesDoesNotDisableReminders() async {
        let state = SettingsReducer.State()
        state.$appIconBadgeEnabled.withLock { $0 = true }
        state.$taskRemindersEnabled.withLock { $0 = true }
        let store = TestStore(initialState: state) { SettingsReducer() } withDependencies: {
            $0.notificationsClient.badgeAuthorizationStatus = { .denied }
        }
        await store.send(.checkBadgeAuthorization)
        await store.receive(\.badgeStatusChecked) { $0.$appIconBadgeEnabled.withLock { $0 = false } }
        #expect(store.state.taskRemindersEnabled)
    }
}
