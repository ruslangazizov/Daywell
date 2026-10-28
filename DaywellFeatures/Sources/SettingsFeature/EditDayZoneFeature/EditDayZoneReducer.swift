import ComposableArchitecture
import Domain
import Foundation

public struct EditDayZoneReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        let id: UUID
        let isNew: Bool
        var name: String
        var start: LocalTime
        var end: LocalTime
        var endsNextDay: Bool
        var otherZones: [DayZone]
        var saveError: String?

        init(zone: DayZone, otherZones: [DayZone]) {
            id = zone.id
            isNew = false
            name = zone.name
            start = zone.window.start
            end = zone.window.end
            endsNextDay = zone.window.crossesMidnight
            self.otherZones = otherZones.filter { $0.id != zone.id }
        }

        init(id: UUID, zones: [DayZone]) {
            self.id = id
            isNew = true
            name = ""
            otherZones = zones
            let available = DailyZonesFormatting.gaps(in: zones).first
                ?? DayZone.defaults[0].window
            start = available.start
            let endMinute = available.start.minutesSinceMidnight + min(60, available.durationInMinutes)
            // Derived from a validated local time, capped at a one-hour draft.
            end = try! LocalTime(hour: (endMinute % 1440) / 60, minute: endMinute % 60)
            endsNextDay = endMinute >= 1440
        }

        var validatedZone: Result<DayZone, Error> {
            Result {
                let zone = try DayZone(id: id, name: name, window: TimeWindow(
                    start: start, end: end, endDay: endsNextDay ? .nextDay : .sameDay
                ))
                try DayZone.validate(otherZones + [zone])
                return zone
            }
        }

        var validationMessage: String? {
            if case .failure(let error) = validatedZone { return error.localizedDescription }
            return nil
        }

        var canSave: Bool { validationMessage == nil }
    }

    @CasePathable
    public enum Action {
        case didChangeName(String)
        case didChangeStart(LocalTime)
        case didChangeEnd(LocalTime)
        case didChangeEndsNextDay(Bool)
        case didTapCancel
        case didTapSave
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case didSave(DayZone)
        }
    }

    @Dependency(\.dismiss) var dismiss

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .didChangeName(let name):
                state.name = name
                state.saveError = nil
            case .didChangeStart(let time):
                state.start = time
                state.saveError = nil
            case .didChangeEnd(let time):
                state.end = time
                state.saveError = nil
            case .didChangeEndsNextDay(let value):
                state.endsNextDay = value
                state.saveError = nil
            case .didTapCancel:
                return .run { _ in await dismiss() }
            case .didTapSave:
                guard case .success(let zone) = state.validatedZone else { return .none }
                // The parent revalidates and dismisses only after committing the collection.
                return .run { send in await send(.delegate(.didSave(zone))) }
            case .delegate:
                break
            }
            return .none
        }
    }
}
