import ComposableArchitecture
import Foundation
import Persistence
import Testing
@testable import SettingsFeature

struct CustomTaskDurationTests {
    @Dependency(\.defaultAppStorage) var userDefaults

    @Test func savingCustomDurationAddsAndSelectsIt() async throws {
        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }
        await store.send(.taskDuration(.didTapCustom)) {
            $0.customTaskDuration = .init(duration: TaskDuration(minutes: 30))
        }
        await store.send(.taskDuration(.custom(.presented(.didChooseHours(1))))) {
            $0.customTaskDuration?.hours = 1
        }
        await store.send(.taskDuration(.custom(.presented(.didChooseMinutes(15))))) {
            $0.customTaskDuration?.minutes = 15
        }
        // Editing the draft has not changed either the selection or its options.
        #expect(store.state.defaultTaskDuration.minutes == 30)
        #expect(store.state.taskDurations == TaskDuration.defaults)

        await store.send(.taskDuration(.custom(.presented(.didTapSave))))
        await store.receive(\.taskDuration.custom.presented.delegate.didSave) {
            $0.$taskDurations.withLock { $0.insert(TaskDuration(minutes: 75), at: 4) }
            $0.$defaultTaskDuration.withLock { $0 = TaskDuration(minutes: 75) }
        }
        await store.receive(\.taskDuration.custom.dismiss) {
            $0.customTaskDuration = nil
        }

        let optionsData = try #require(userDefaults.data(forKey: UserDefaultsKeys.taskDurations))
        let selectionData = try #require(userDefaults.data(forKey: UserDefaultsKeys.defaultTaskDuration))
        #expect(try JSONDecoder().decode([TaskDuration].self, from: optionsData) == store.state.taskDurations)
        #expect(try JSONDecoder().decode(TaskDuration.self, from: selectionData).minutes == 75)

        await store.send(.taskDuration(.didTapCustom)) {
            $0.customTaskDuration = .init(duration: TaskDuration(minutes: 75))
        }
        await store.send(.taskDuration(.custom(.dismiss))) {
            $0.customTaskDuration = nil
        }
    }

    @Test func cancellingDiscardsDraft() async {
        let store = TestStore(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }
        await store.send(.taskDuration(.didTapCustom)) {
            $0.customTaskDuration = .init(duration: TaskDuration(minutes: 30))
        }
        await store.send(.taskDuration(.custom(.presented(.didChooseHours(2))))) {
            $0.customTaskDuration?.hours = 2
        }
        await store.send(.taskDuration(.custom(.presented(.didTapCancel))))
        await store.receive(\.taskDuration.custom.dismiss) {
            $0.customTaskDuration = nil
        }
        #expect(store.state.taskDurations == TaskDuration.defaults)
        #expect(store.state.defaultTaskDuration.minutes == 30)
        #expect(SettingsReducer.State().defaultTaskDuration.minutes == 30)
    }

    @Test func swipingToDismissDiscardsDraft() async {
        var state = SettingsReducer.State()
        state.customTaskDuration = .init(duration: TaskDuration(minutes: 75))
        let store = TestStore(initialState: state) { SettingsReducer() }

        await store.send(.taskDuration(.custom(.dismiss))) {
            $0.customTaskDuration = nil
        }
        #expect(store.state.taskDurations == TaskDuration.defaults)
        #expect(store.state.defaultTaskDuration.minutes == 30)
    }

    @Test func savingExistingDurationReusesOption() async {
        var state = SettingsReducer.State()
        state.customTaskDuration = .init(duration: TaskDuration(minutes: 60))
        let store = TestStore(initialState: state) { SettingsReducer() }

        await store.send(.taskDuration(.custom(.presented(.didTapSave))))
        await store.receive(\.taskDuration.custom.presented.delegate.didSave) {
            $0.$defaultTaskDuration.withLock { $0 = TaskDuration(minutes: 60) }
        }
        await store.receive(\.taskDuration.custom.dismiss) {
            $0.customTaskDuration = nil
        }
        #expect(store.state.taskDurations == TaskDuration.defaults)
    }

    @Test func zeroDurationCannotSave() async {
        var state = SettingsReducer.State()
        state.customTaskDuration = .init(duration: TaskDuration(minutes: 0))
        let store = TestStore(initialState: state) { SettingsReducer() }

        #expect(store.state.customTaskDuration?.canSave == false)
        await store.send(.taskDuration(.custom(.presented(.didTapSave))))
        #expect(store.state.customTaskDuration != nil)
        #expect(store.state.taskDurations == TaskDuration.defaults)
        #expect(store.state.defaultTaskDuration.minutes == 30)
    }

    @Test func durationsLongerThanOneDayRemainEditable() async {
        var state = SettingsReducer.State()
        state.customTaskDuration = .init(duration: TaskDuration(minutes: 25 * 60 + 15))
        let store = TestStore(initialState: state) { SettingsReducer() }

        #expect(store.state.customTaskDuration?.hourOptions.contains(26) == true)
        await store.send(.taskDuration(.custom(.presented(.didChooseHours(26))))) {
            $0.customTaskDuration?.hours = 26
        }
        await store.send(.taskDuration(.custom(.presented(.didTapSave))))
        await store.receive(\.taskDuration.custom.presented.delegate.didSave) {
            $0.$taskDurations.withLock { $0.append(TaskDuration(minutes: 26 * 60 + 15)) }
            $0.$defaultTaskDuration.withLock { $0 = TaskDuration(minutes: 26 * 60 + 15) }
        }
        await store.receive(\.taskDuration.custom.dismiss) {
            $0.customTaskDuration = nil
        }
    }
}
