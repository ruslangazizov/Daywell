import Clients
import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import AppRootFeature

@MainActor
struct BadgeRefreshTests {
    @Test func layoutAndZoneChangesSendLatestPreferences() async {
        @Shared(Preferences.appIconBadgeEnabled) var enabled = true
        let received = LockIsolated<[NotificationConfiguration]>([])
        let store = TestStore(initialState: RootReducer.State()) { RootReducer() } withDependencies: {
            $0.notificationsClient.synchronize = { config in received.withValue { $0.append(config) } }
        }
        store.exhaustivity = .off
        await store.send(.settings(.didChooseTodayLayout(.zones)))
        await store.receive(\.synchronizeNotifications)
        await store.receive(\.settings.reminderSchedulingResponse)
        #expect(received.value.last?.layout == .zones)
        #expect(received.value.last?.badgeEnabled == true)
        let morning = DayZone.defaults[0]
        await store.send(.settings(.dailyZones(.didTapDelete(morning.id))))
        await store.receive(\.synchronizeNotifications)
        await store.receive(\.settings.reminderSchedulingResponse)
        #expect(received.value.last?.zones.contains(where: { $0.id == morning.id }) == false)
        await store.send(.settings(.didChangeAppIconBadgeEnabled(false)))
        await store.receive(\.synchronizeNotifications)
        await store.receive(\.settings.reminderSchedulingResponse)
        #expect(received.value.last?.badgeEnabled == false)
    }

    @Test func successfulCompletionAndClockTickRefreshWithRemindersOff() async throws {
        @Shared(Preferences.appIconBadgeEnabled) var enabled = true
        let received = LockIsolated(0)
        let now = Date(timeIntervalSince1970: 1_794_312_000)
        let store = TestStore(initialState: RootReducer.State()) { RootReducer() } withDependencies: {
            $0.date.now = now
            $0.calendar = Calendar(identifier: .gregorian)
            $0.notificationsClient.synchronize = { _ in received.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off
        let id = TaskOccurrenceID(taskID: UUID(), day: try LocalDate(now, in: .current))
        await store.send(.tasks(.completionSaveResponse(id, previous: nil, saved: nil, .success(()))))
        await store.receive(\.synchronizeNotifications)
        await store.receive(\.settings.reminderSchedulingResponse)
        await store.send(.tasks(.clockTick))
        await store.receive(\.synchronizeNotifications)
        await store.receive(\.settings.reminderSchedulingResponse)
        #expect(received.value == 2)
    }
}
