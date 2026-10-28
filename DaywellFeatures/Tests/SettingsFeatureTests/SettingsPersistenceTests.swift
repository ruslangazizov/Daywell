import Clients
import ComposableArchitecture
import Foundation
import Persistence
import Testing
import UIKit
@testable import SettingsFeature

struct SettingsPersistenceTests {
    @Dependency(\.defaultAppStorage) var userDefaults

    @Test func emptyStorageUsesPreferenceDefaults() {
        let state = SettingsReducer.State()

        #expect(state.appearance == .system)
        #expect(state.todayLayout == .timeline)
        #expect(state.customCardWidthPercentage == 0.4)
        #expect(state.firstDayOfWeek == .system)
        #expect(state.taskDurations == TaskDuration.defaults)
        #expect(state.defaultTaskDuration == TaskDuration(minutes: 30))
        #expect(state.taskRemindersEnabled)
        #expect(state.appIconBadgeEnabled)
    }

    @Test func preferencesStaySharedWhenReaderIsCreatedBeforeSettings() async {
        @Shared(Preferences.firstDayOfWeek) var firstDayOfWeek
        #expect(firstDayOfWeek == .system)

        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }

        await store.send(.didChooseFirstDayOfWeek(.monday)) {
            $0.$firstDayOfWeek.withLock { $0 = .monday }
        }
        #expect(firstDayOfWeek == .monday)
        #expect(userDefaults.string(forKey: UserDefaultsKeys.firstDayOfWeek) == "monday")

        $firstDayOfWeek.withLock { $0 = .sunday }
        #expect(store.state.firstDayOfWeek == .sunday)
    }

    @Test func preferenceKeysUseCurrentStorageDependency() {
        let firstStorage = UserDefaults.inMemory
        let secondStorage = UserDefaults.inMemory
        firstStorage.set("agenda", forKey: UserDefaultsKeys.todayLayout)
        secondStorage.set("zones", forKey: UserDefaultsKeys.todayLayout)

        let first = withDependencies {
            $0.defaultAppStorage = firstStorage
        } operation: {
            Shared(Preferences.todayLayout)
        }
        let second = withDependencies {
            $0.defaultAppStorage = secondStorage
        } operation: {
            Shared(Preferences.todayLayout)
        }

        #expect(first.wrappedValue == .agenda)
        #expect(second.wrappedValue == .zones)
    }

    @Test func preferenceActionsWriteToUserDefaults() async throws {
        let styleClient = RecordingStyleClient()
        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        } withDependencies: {
            $0.userInterfaceStyleClient.override = { await styleClient.override(to: $0) }
        }

        await store.send(.didChooseAppearance(.dark)) {
            $0.$appearance.withLock { $0 = .dark }
        }.finish()
        await store.send(.didChooseTodayLayout(.zones)) {
            $0.$todayLayout.withLock { $0 = .zones }
        }
        await store.send(.didChooseCustomCardWidthPercentage(0.7)) {
            $0.$customCardWidthPercentage.withLock { $0 = 0.7 }
        }
        await store.send(.didChooseFirstDayOfWeek(.sunday)) {
            $0.$firstDayOfWeek.withLock { $0 = .sunday }
        }
        await store.send(.taskDuration(.didChooseDefault(TaskDuration(minutes: 45)))) {
            $0.$defaultTaskDuration.withLock { $0 = TaskDuration(minutes: 45) }
        }
        await store.send(.didChangeTaskRemindersEnabled(false)) {
            $0.$taskRemindersEnabled.withLock { $0 = false }
        }
        await store.send(.didChangeAppIconBadgeEnabled(false)) {
            $0.$appIconBadgeEnabled.withLock { $0 = false }
        }

        #expect(userDefaults.string(forKey: UserDefaultsKeys.appearance) == "dark")
        #expect(userDefaults.string(forKey: UserDefaultsKeys.todayLayout) == "zones")
        #expect(userDefaults.double(forKey: UserDefaultsKeys.customCardWidthPercentage) == 0.7)
        #expect(userDefaults.string(forKey: UserDefaultsKeys.firstDayOfWeek) == "sunday")
        #expect(userDefaults.object(forKey: UserDefaultsKeys.taskRemindersEnabled) as? Bool == false)
        #expect(userDefaults.object(forKey: UserDefaultsKeys.appIconBadgeEnabled) as? Bool == false)
        let data = try #require(userDefaults.data(forKey: UserDefaultsKeys.defaultTaskDuration))
        #expect(try JSONDecoder().decode(TaskDuration.self, from: data).minutes == 45)
        #expect(await styleClient.styles == [.dark])
    }

    @Test func storedPreferencesOverrideDefaults() throws {
        let duration = TaskDuration(minutes: 75)
        let durations = (TaskDuration.defaults + [duration]).sorted { $0.minutes < $1.minutes }
        // Seed storage before creating State so this checks loading, not Shared's in-memory cache.
        userDefaults.set("dark", forKey: UserDefaultsKeys.appearance)
        userDefaults.set("zones", forKey: UserDefaultsKeys.todayLayout)
        userDefaults.set(0.7, forKey: UserDefaultsKeys.customCardWidthPercentage)
        userDefaults.set("sunday", forKey: UserDefaultsKeys.firstDayOfWeek)
        userDefaults.set(try JSONEncoder().encode(durations), forKey: UserDefaultsKeys.taskDurations)
        userDefaults.set(try JSONEncoder().encode(duration), forKey: UserDefaultsKeys.defaultTaskDuration)
        userDefaults.set(false, forKey: UserDefaultsKeys.taskRemindersEnabled)
        userDefaults.set(false, forKey: UserDefaultsKeys.appIconBadgeEnabled)

        let state = SettingsReducer.State()
        #expect(state.appearance == .dark)
        #expect(state.todayLayout == .zones)
        #expect(state.customCardWidthPercentage == 0.7)
        #expect(state.firstDayOfWeek == .sunday)
        #expect(state.taskDurations == durations)
        #expect(state.defaultTaskDuration == duration)
        #expect(!state.taskRemindersEnabled)
        #expect(!state.appIconBadgeEnabled)
        #expect(state.customTaskDuration == nil)
        #expect(state.iCloudStatus == .notChecked)
        #expect(state.lastConfirmedSync == nil)
        #expect(userDefaults.string(forKey: UserDefaultsKeys.appearance) == "dark")
    }

    @Test func unreadablePreferencesFallBackToDefaults() {
        userDefaults.set("unknown", forKey: UserDefaultsKeys.appearance)
        userDefaults.set("unknown", forKey: UserDefaultsKeys.todayLayout)
        userDefaults.set("unknown", forKey: UserDefaultsKeys.firstDayOfWeek)
        userDefaults.set(Data([0xFF]), forKey: UserDefaultsKeys.taskDurations)
        userDefaults.set(Data([0xFF]), forKey: UserDefaultsKeys.defaultTaskDuration)

        let state = SettingsReducer.State()
        #expect(state.appearance == .system)
        #expect(state.todayLayout == .timeline)
        #expect(state.firstDayOfWeek == .system)
        #expect(state.taskDurations == TaskDuration.defaults)
        #expect(state.defaultTaskDuration == TaskDuration(minutes: 30))
    }

    @Test func startupAppliesStoredAppearance() async {
        userDefaults.set("dark", forKey: UserDefaultsKeys.appearance)
        let styleClient = RecordingStyleClient()
        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        } withDependencies: {
            $0.userInterfaceStyleClient.override = { await styleClient.override(to: $0) }
        }

        await store.send(.task).finish()
        #expect(await styleClient.styles == [.dark])
    }
}

private actor RecordingStyleClient {
    private(set) var styles: [UIUserInterfaceStyle] = []

    func override(to newStyle: UIUserInterfaceStyle) async {
        styles.append(newStyle)
    }
}
