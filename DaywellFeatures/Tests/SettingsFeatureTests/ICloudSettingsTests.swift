import Clients
import ComposableArchitecture
import Foundation
import Persistence
import Testing
@testable import SettingsFeature

struct ICloudSettingsTests {
    @Test func lateCheckResponseCannotOverwriteANewerAccountChange() async {
        var state = SettingsReducer.State(iCloudStatus: .signedOut)
        state.iCloudSnapshotVersion = 3
        state.isCheckingICloud = true
        let store = TestStore(initialState: state) { SettingsReducer() }
        await store.send(.iCloudCheckResponse(.init(status: .available, version: 2))) {
            $0.isCheckingICloud = false
        }
        #expect(store.state.iCloudStatus == .signedOut)
    }

    @Test func checkShowsProgressAndDoesNotInventASyncDate() async {
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.iCloudClient.refresh = { .init(status: .noConfirmedSync) }
        }
        await store.send(.didTapCheckICloudStatus) { $0.isCheckingICloud = true }
        await store.receive(\.iCloudCheckResponse) {
            $0.isCheckingICloud = false
            $0.iCloudStatus = .noConfirmedSync
        }
        #expect(store.state.lastConfirmedSync == nil)
    }

    @Test func importReloadsDataAndSignOutClearsObservedHistory() async {
        let date = Date(timeIntervalSince1970: 100)
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() }
        await store.send(.iCloudStatusChanged(.init(status: .available, lastConfirmedSync: date, dataRevision: 1))) {
            $0.iCloudStatus = .available
            $0.lastConfirmedSync = date
            $0.iCloudDataRevision = 1
        }
        await store.receive(\.iCloudDataChanged)
        await store.send(.iCloudStatusChanged(.init(status: .signedOut, dataRevision: 2))) {
            $0.iCloudStatus = .signedOut
            $0.lastConfirmedSync = nil
            $0.iCloudDataRevision = 2
        }
        await store.receive(\.iCloudDataChanged)
    }

    @Test func repeatedTapsDoNotStartOverlappingChecks() async {
        let clock = TestClock()
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.iCloudClient.refresh = {
                try? await clock.sleep(for: .seconds(1))
                return .init(status: .restricted)
            }
        }
        await store.send(.didTapCheckICloudStatus) { $0.isCheckingICloud = true }
        await store.send(.didTapCheckICloudStatus)
        await clock.advance(by: .seconds(1))
        await store.receive(\.iCloudCheckResponse) {
            $0.isCheckingICloud = false
            $0.iCloudStatus = .restricted
        }
    }

    @Test func observationLivesUntilCancelled() async {
        let (stream, continuation) = AsyncStream<ICloudSnapshot>.makeStream()
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() } withDependencies: {
            $0.iCloudClient.observe = { stream }
            $0.iCloudClient.refresh = { .init(status: .noConfirmedSync) }
            $0.userInterfaceStyleClient.override = { _ in }
        }
        let effect = await store.send(.task)
        await store.receive(\.didTapCheckICloudStatus) { $0.isCheckingICloud = true }
        await store.receive(\.iCloudCheckResponse) {
            $0.isCheckingICloud = false
            $0.iCloudStatus = .noConfirmedSync
        }
        continuation.yield(.init(status: .syncing))
        await store.receive(\.iCloudStatusChanged) { $0.iCloudStatus = .syncing }
        await effect.cancel()
    }
}
