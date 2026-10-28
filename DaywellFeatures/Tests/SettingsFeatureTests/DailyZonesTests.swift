import ComposableArchitecture
import Domain
import Foundation
import Persistence
import Testing
@testable import SettingsFeature

struct DailyZonesTests {
    @Dependency(\.defaultAppStorage) var userDefaults

    @Test func defaultsAreValidAndHaveStableIdentities() throws {
        try DayZone.validate(DayZone.defaults)
        #expect(DayZone.defaults.map(\.name) == ["Morning", "Day", "Evening"])
        #expect(Set(DayZone.defaults.map(\.id)).count == 3)
    }

    @Test func gapsJoinAcrossMidnightAndHandleEmptyAndFullDays() throws {
        let gaps = DailyZonesFormatting.gaps(in: DayZone.defaults)
        #expect(gaps.count == 1)
        #expect(gaps.first?.start.hour == 23)
        #expect(gaps.first?.end.hour == 7)
        #expect(gaps.first?.crossesMidnight == true)
        #expect(DailyZonesFormatting.gaps(in: []).first?.isFullDay == true)

        let allDay = try zone("All day", start: 0, end: 0, nextDay: true)
        #expect(DailyZonesFormatting.gaps(in: [allDay]).isEmpty)
        let overnight = try zone("Night", start: 23, end: 7, nextDay: true)
        #expect(DailyZonesFormatting.gaps(in: DayZone.defaults + [overnight]).isEmpty)
    }

    @Test func gapsIncludeEveryUncoveredInterval() throws {
        let morning = try zone("Morning", start: 7, end: 9)
        let afternoon = try zone("Afternoon", start: 12, end: 17)
        let gaps = DailyZonesFormatting.gaps(in: [afternoon, morning])
        #expect(gaps.map(\.start.hour) == [9, 17])
        #expect(gaps.map(\.end.hour) == [12, 7])
    }

    @Test func editorRejectsEmptyNamesInvalidWindowsAndOverlaps() async throws {
        let store = TestStore(initialState: EditDayZoneReducer.State(
            id: UUID(), zones: DayZone.defaults
        )) { EditDayZoneReducer() }
        #expect(!store.state.canSave)
        await store.send(.didTapSave)
        await store.send(.didChangeName("  Night  ")) { $0.name = "  Night  " }
        #expect(store.state.canSave)
        let seven = try LocalTime(hour: 7, minute: 0)
        let eight = try LocalTime(hour: 8, minute: 0)
        await store.send(.didChangeEnd(eight)) { $0.end = eight }
        #expect(!store.state.canSave)
        #expect(store.state.validationMessage == "Zones cannot overlap.")
        await store.send(.didChangeEnd(seven)) { $0.end = seven }
        #expect(store.state.canSave)
        await store.send(.didChangeEndsNextDay(false)) { $0.endsNextDay = false }
        #expect(!store.state.canSave)
        await store.send(.didTapSave)
    }

    @Test func editorAllowsAdjacentAndFullDayWindows() throws {
        let fullDay = try zone("All day", start: 6, end: 6, nextDay: true)
        let draft = EditDayZoneReducer.State(zone: fullDay, otherZones: [])
        #expect(draft.canSave)
        let morning = DayZone.defaults[0]
        #expect(EditDayZoneReducer.State(zone: morning, otherZones: DayZone.defaults).canSave)
    }

    @Test func clockValuesRoundTripWithoutDeviceTimeZoneConversion() throws {
        let time = try LocalTime(hour: 2, minute: 30)
        #expect(DailyZonesFormatting.time(from: DailyZonesFormatting.date(for: time)) == time)
        let window = try TimeWindow(start: time, end: LocalTime(hour: 7, minute: 15))
        #expect(DailyZonesFormatting.interval(window, locale: Locale(identifier: "en_GB")) == "2:30 – 7:15")
    }

    @Test func addingZonePersistsAndUpdatesExistingReaders() async throws {
        @Shared(Preferences.dailyZones) var zones
        let id = UUID()
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() }
            withDependencies: { $0.uuid = .constant(id) }
        await store.send(.dailyZones(.didTapAdd)) {
            $0.editDayZone = .init(id: id, zones: DayZone.defaults)
        }
        await store.send(.dailyZones(.editor(.presented(.didChangeName("  Night  "))))) {
            $0.editDayZone?.name = "  Night  "
        }
        #expect(zones == DayZone.defaults)
        let saved = try DayZone(id: id, name: "Night", window: TimeWindow(
            start: LocalTime(hour: 23, minute: 0), end: LocalTime(hour: 0, minute: 0), endDay: .nextDay
        ))
        await store.send(.dailyZones(.editor(.presented(.didTapSave))))
        await store.receive(\.dailyZones.editor.presented.delegate.didSave) {
            $0.$dailyZones.withLock { $0.append(saved) }
            $0.editDayZone = nil
        }
        #expect(zones.last == saved)
        let data = try #require(userDefaults.data(forKey: UserDefaultsKeys.dailyZones))
        #expect(try JSONDecoder().decode([DayZone].self, from: data) == zones)
        #expect(SettingsReducer.State().dailyZones == zones)
    }

    @Test func editingPreservesIdentityAndCancelDiscardsChanges() async throws {
        let original = DayZone.defaults[0]
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() }
        await store.send(.dailyZones(.didTapZone(original.id))) {
            $0.editDayZone = .init(zone: original, otherZones: DayZone.defaults)
        }
        await store.send(.dailyZones(.editor(.presented(.didChangeName("Early morning"))))) {
            $0.editDayZone?.name = "Early morning"
        }
        await store.send(.dailyZones(.editor(.presented(.didTapCancel))))
        await store.receive(\.dailyZones.editor.dismiss) { $0.editDayZone = nil }
        #expect(store.state.dailyZones == DayZone.defaults)

        await store.send(.dailyZones(.didTapZone(original.id))) {
            $0.editDayZone = .init(zone: original, otherZones: DayZone.defaults)
        }
        await store.send(.dailyZones(.editor(.presented(.didChangeName("Early morning"))))) {
            $0.editDayZone?.name = "Early morning"
        }
        let updated = try DayZone(id: original.id, name: "Early morning", window: original.window)
        await store.send(.dailyZones(.editor(.presented(.didTapSave))))
        await store.receive(\.dailyZones.editor.presented.delegate.didSave) {
            $0.$dailyZones.withLock { $0[0] = updated }
            $0.editDayZone = nil
        }
        #expect(store.state.dailyZones.count == 3)
    }

    @Test func swipingAwayTheEditorDoesNotSave() async {
        var state = SettingsReducer.State()
        state.editDayZone = .init(id: UUID(), zones: DayZone.defaults)
        let store = TestStore(initialState: state) { SettingsReducer() }
        await store.send(.dailyZones(.editor(.dismiss))) { $0.editDayZone = nil }
        #expect(store.state.dailyZones == DayZone.defaults)
    }

    @Test func restoringRequiresConfirmationAndPersistsDefaults() async throws {
        let custom = try zone("Custom", start: 5, end: 8)
        userDefaults.set(try JSONEncoder().encode([custom]), forKey: UserDefaultsKeys.dailyZones)
        let store = TestStore(initialState: SettingsReducer.State()) { SettingsReducer() }
        #expect(store.state.dailyZones == [custom])
        await store.send(.dailyZones(.didTapRestoreDefaults)) {
            $0.zonesConfirmation = SettingsReducer.restoreZonesConfirmation
        }
        #expect(store.state.dailyZones == [custom])
        await store.send(.dailyZones(.confirmation(.dismiss))) { $0.zonesConfirmation = nil }
        #expect(store.state.dailyZones == [custom])
        await store.send(.dailyZones(.didTapRestoreDefaults)) {
            $0.zonesConfirmation = SettingsReducer.restoreZonesConfirmation
        }
        await store.send(.dailyZones(.confirmation(.presented(.restoreDefaults)))) {
            $0.$dailyZones.withLock { $0 = DayZone.defaults }
            $0.zonesConfirmation = nil
        }
        let data = try #require(userDefaults.data(forKey: UserDefaultsKeys.dailyZones))
        #expect(try JSONDecoder().decode([DayZone].self, from: data) == DayZone.defaults)
    }

    @Test func parentRevalidatesAgainstChangesMadeWhileEditorWasOpen() async throws {
        let id = UUID()
        let night = try zone("Night", start: 23, end: 7, nextDay: true)
        var state = SettingsReducer.State()
        state.editDayZone = .init(id: id, zones: DayZone.defaults)
        state.editDayZone?.name = "Late night"
        state.$dailyZones.withLock { $0.append(night) }
        let store = TestStore(initialState: state) { SettingsReducer() }

        await store.send(.dailyZones(.editor(.presented(.didTapSave))))
        await store.receive(\.dailyZones.editor.presented.delegate.didSave) {
            $0.editDayZone?.otherZones = DayZone.defaults + [night]
            $0.editDayZone?.saveError = "Zones cannot overlap."
        }
        #expect(store.state.dailyZones == DayZone.defaults + [night])
        #expect(store.state.editDayZone != nil)
    }

    @Test func corruptStorageFallsBackToDefaultsAndEmptyCollectionStaysEmpty() throws {
        userDefaults.set(Data([0xFF]), forKey: UserDefaultsKeys.dailyZones)
        #expect(SettingsReducer.State().dailyZones == DayZone.defaults)
        let emptyStorage = UserDefaults.inMemory
        emptyStorage.set(try JSONEncoder().encode([DayZone]()), forKey: UserDefaultsKeys.dailyZones)
        let state = withDependencies { $0.defaultAppStorage = emptyStorage } operation: {
            SettingsReducer.State()
        }
        #expect(state.dailyZones.isEmpty)
    }

    private func zone(_ name: String, start: Int, end: Int, nextDay: Bool = false) throws -> DayZone {
        try DayZone(name: name, window: TimeWindow(
            start: LocalTime(hour: start, minute: 0), end: LocalTime(hour: end, minute: 0),
            endDay: nextDay ? .nextDay : .sameDay
        ))
    }
}
