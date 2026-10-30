import ComposableArchitecture
import Domain
import DesignSystem
import UIKit
import Foundation
import Persistence
import Testing
@testable import TasksFeature

struct TodayLayoutTests {
    @Dependency(\.defaultAppStorage) var userDefaults

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var date: Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: 12))!
    }

    private func task(_ title: String, hour: Int? = nil, window: TimeWindow? = nil) throws -> DWTask {
        try DWTask(
            title: title,
            schedule: .once(on: LocalDate(date, in: calendar.timeZone)),
            timeWindow: window ?? hour.map {
                try TimeWindow(start: LocalTime(hour: $0, minute: 0), end: LocalTime(hour: $0 + 1, minute: 0))
            }
        )
    }

    @Test func taskColorsResolveOnBackgroundRenderer() async {
        let color = UIColor(DWColor.lilacBg)
        // Deliberately cross actors to reproduce SwiftUI's asynchronous color resolution.
        let matches = await Task.detached {
            let light = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
            let dark = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))
            return light == UIColor(red: 238.0 / 255, green: 233.0 / 255, blue: 250.0 / 255, alpha: 1)
                && dark == UIColor(red: 53.0 / 255, green: 44.0 / 255, blue: 73.0 / 255, alpha: 1)
        }.value
        #expect(matches)
    }

    @Test(arguments: TodayLayout.allCases)
    func loadsSavedLayout(_ layout: TodayLayout) {
        userDefaults.set(layout.rawValue, forKey: UserDefaultsKeys.todayLayout)
        #expect(TasksReducer.State().todayLayout == layout)
    }

    @Test func preferenceChangesReachExistingTodayStateWithoutLosingSelectionOrCompletion() throws {
        @Shared(Preferences.todayLayout) var layout
        @Shared(Preferences.dailyZones) var zones
        let read = try task("Read", hour: 8)
        let occurrence = try OccurrenceRecord(
            id: TaskOccurrenceID(taskID: read.id, day: LocalDate(date, in: calendar.timeZone)),
            outcome: .completed(at: date)
        )
        let state = TasksReducer.State(selectedDate: date, tasks: [read], tasksOccurrences: [occurrence], calendar: calendar)
        $layout.withLock { $0 = .zones }
        let renamed = try DayZone(id: DayZone.defaults[0].id, name: "Early morning", window: DayZone.defaults[0].window)
        $zones.withLock { $0 = [renamed] }

        #expect(state.todayLayout == .zones)
        #expect(state.selectedDate == date)
        #expect(state.timeline.tasks.first?.isCompleted == true)
        #expect(state.completionSummary == nil)
        #expect(TodayZonesViewModel(timeline: state.timeline, zones: state.zones)
            .sections.first?.tasks.count { $0.isCompleted } == 1)
        #expect(TodayListViewModel(timeline: state.timeline, zones: state.zones).zones.first?.title == "Early morning")

        $zones.withLock { $0 = [] }
        #expect(state.timeline.tasks.map(\.title) == ["Read"])
        #expect(state.timeline.tasks.first?.startMinute == 480)
        #expect(state.timeline.tasks.first?.isCompleted == true)
        #expect(TodayListViewModel(timeline: state.timeline, zones: state.zones).zones.first?.title == "No zone")
    }

    @Test func agendaSortsTimedTasksAndKeepsUntimedTasks() throws {
        let tasks = try [task("Late", hour: 17), task("Any time"), task("Early", hour: 8)]
        let state = TasksReducer.State(selectedDate: date, tasks: tasks, calendar: calendar)
        let model = TodayListViewModel(timeline: state.timeline, zones: state.zones)
        #expect(model.agenda.map(\.title) == ["Scheduled", "Any time"])
        #expect(model.agenda[0].tasks.map(\.title) == ["Early", "Late"])
        #expect(model.agenda[1].tasks.map(\.title) == ["Any time"])
        #expect(model.agendaScrollTargetID == TodayListViewModel.taskID(state.timeline.tasks[1]))
    }

    @Test func zonesUseTimeOverlapsAndAgendaKeepsEachTaskOnce() throws {
        let morning = DayZone.defaults[0]
        let day = DayZone.defaults[1]
        let evening = DayZone.defaults[2]
        let tasks = try [
            task("Morning task", hour: 8),
            task("Monthly reflection", hour: 17),
            task("Across zones", window: TimeWindow(start: LocalTime(hour: 17, minute: 0),
                                                   end: LocalTime(hour: 19, minute: 0))),
            task("Outside zones", hour: 4),
            task("Any time")
        ]
        let state = TasksReducer.State(selectedDate: date, tasks: tasks, zones: [evening, day, morning], calendar: calendar)
        let model = TodayListViewModel(timeline: state.timeline, zones: state.zones)
        #expect(model.zones.map(\.title) == ["Morning", "Day", "Evening", "No zone"])
        #expect(model.zones[0].tasks.map(\.title) == ["Morning task"])
        #expect(model.zones[1].tasks.map(\.title) == ["Monthly reflection", "Across zones"])
        #expect(model.zones[2].tasks.map(\.title) == ["Across zones"])
        #expect(model.zones[3].tasks.map(\.title) == ["Outside zones", "Any time"])
        let ids = model.zones.flatMap(\.tasks).map(\.id)
        #expect(ids.count == tasks.count + 1)
        #expect(Set(ids).count == tasks.count)
        #expect(model.agenda.flatMap(\.tasks).count == tasks.count)
    }

    @Test func overnightZoneIsCurrentOnlyOnSelectedToday() throws {
        let night = try DayZone(name: "Night", window: TimeWindow(
            start: LocalTime(hour: 22, minute: 0), end: LocalTime(hour: 6, minute: 0), endDay: .nextDay
        ))
        let now = calendar.date(bySettingHour: 1, minute: 0, second: 0, of: date)!
        var state = TasksReducer.State(selectedDate: date, tasks: [try task("Night task", window: night.window)],
                                       zones: [night], now: now, calendar: calendar)
        let model = TodayListViewModel(timeline: state.timeline, zones: state.zones)
        #expect(model.zones.first?.isCurrent == true)
        #expect(model.zonesScrollTargetID == model.zones.first?.id)
        state.now = calendar.date(byAdding: .day, value: 1, to: now)!
        #expect(TodayListViewModel(timeline: state.timeline, zones: state.zones).zones.first?.isCurrent == false)
    }

    @Test func emptyLayoutsHaveReachableTopAnchor() {
        let state = TasksReducer.State(selectedDate: date, calendar: calendar, hasLoadedData: true)
        let model = TodayListViewModel(timeline: state.timeline, zones: state.zones)
        #expect(model.agenda.isEmpty)
        #expect(model.zones.allSatisfy { $0.tasks.isEmpty })
        #expect(model.agendaScrollTargetID == TodayListViewModel.topID)
        #expect(model.zonesScrollTargetID == TodayListViewModel.topID)
    }
}
