import Domain
import Foundation
import Testing
@testable import TasksFeature

struct TodayZonesTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func model(hour: Int, dayOffset: Int = 0, zones: [DayZone] = DayZone.defaults,
                       tasks: [DWTask] = []) -> TodayZonesViewModel {
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: hour))!
        let day = try! LocalDate(calendar.date(byAdding: .day, value: dayOffset, to: now)!, in: calendar.timeZone)
        return TodayZonesViewModel(timeline: TodayTimelineViewModel(
            tasks: tasks, day: day, occurrences: [], todayLayout: .zones, now: now, calendar: calendar
        ), zones: zones)
    }

    @Test func currentZoneIsSelectedEvenWhenEmpty() {
        let model = model(hour: 12)
        #expect(model.section(browsing: nil)?.title == "Day")
        #expect(model.section(browsing: nil)?.isCurrent == true)
        #expect(model.section(browsing: nil)?.tasks.isEmpty == true)
    }

    @Test func followsClockUnlessBrowsingAndNowRestoresCurrentZone() {
        let morning = model(hour: 9)
        let eveningID = morning.sections[2].id
        #expect(morning.section(browsing: nil)?.title == "Morning")
        #expect(morning.section(browsing: eveningID)?.isCurrent == false)
        let afternoon = model(hour: 12)
        #expect(afternoon.section(browsing: eveningID)?.title == "Evening")
        #expect(afternoon.section(browsing: nil)?.title == "Day")
    }

    @Test func bothDirectionsStopAtDayBoundaries() throws {
        let model = model(hour: 12)
        let day = try #require(model.section(browsing: nil))
        let morning = try #require(model.neighbor(of: day, direction: .previous))
        let evening = try #require(model.neighbor(of: day, direction: .next))
        #expect(morning.title == "Morning")
        #expect(evening.title == "Evening")
        #expect(model.neighbor(of: morning, direction: .previous) == nil)
        #expect(model.neighbor(of: evening, direction: .next) == nil)
        #expect(model.neighbor(of: evening, direction: .previous)?.id == day.id)
    }

    @Test(arguments: [-1, 1]) func otherDaysStartAtFirstZoneWithoutNowBadge(_ dayOffset: Int) {
        let model = model(hour: 19, dayOffset: dayOffset)
        #expect(model.section(browsing: nil)?.title == "Morning")
        #expect(model.sections.allSatisfy { !$0.isCurrent })
    }

    @Test func gapsDoNotPretendAnotherZoneIsCurrent() {
        let before = model(hour: 6)
        #expect(before.section(browsing: nil) == nil)
        #expect(before.neighbor(of: nil, direction: .previous) == nil)
        #expect(before.neighbor(of: nil, direction: .next)?.title == "Morning")
        let after = model(hour: 23)
        #expect(after.section(browsing: nil) == nil)
        #expect(after.neighbor(of: nil, direction: .previous)?.title == "Evening")
        #expect(after.neighbor(of: nil, direction: .next) == nil)
        #expect(after.gapDescription.contains("tomorrow"))
        let middle = model(hour: 12, zones: [DayZone.defaults[0], DayZone.defaults[2]])
        #expect(middle.neighbor(of: nil, direction: .previous)?.title == "Morning")
        #expect(middle.neighbor(of: nil, direction: .next)?.title == "Evening")
    }

    @Test func overnightZoneUsesBothSidesOfMidnight() throws {
        let night = try DayZone(name: "Night", window: TimeWindow(
            start: LocalTime(hour: 22, minute: 0), end: LocalTime(hour: 6, minute: 0), endDay: .nextDay
        ))
        for hour in [23, 1] {
            #expect(model(hour: hour, zones: [night]).section(browsing: nil)?.isCurrent == true)
        }
        #expect(model(hour: 6, zones: [night]).section(browsing: nil) == nil)
    }

    @Test func deletedSelectionFallsBackAndUntimedTasksRemainReachable() throws {
        let task = try DWTask(title: "Any time", schedule: .once(on: LocalDate(year: 2026, month: 10, day: 29)))
        let model = model(hour: 12, tasks: [task])
        let evening = model.sections[2]
        #expect(model.neighbor(of: evening, direction: .next)?.tasks.map(\.title) == ["Any time"])
        #expect(model.section(browsing: "deleted-zone")?.title == "Day")
        let noZones = self.model(hour: 12, zones: [], tasks: [task])
        #expect(noZones.section(browsing: nil)?.title == "No zone")
        #expect(self.model(hour: 12, zones: []).section(browsing: nil) == nil)
    }

    @Test func scrollingWithinLongListDoesNotArmAndEarlyReleaseCancels() {
        // Insets and short lists must use the same release threshold as long lists.
        let within = TodayZonePull.distance(offset: 500, contentHeight: 1200, containerHeight: 600,
                                            topInset: 20, bottomInset: 10)
        #expect(within == 0)
        #expect(TodayZonePull.destination(distance: within) == nil)
        let pastEnd = TodayZonePull.distance(offset: 680, contentHeight: 1200, containerHeight: 600,
                                             topInset: 20, bottomInset: 10)
        #expect(TodayZonePull.destination(distance: pastEnd) == .next)
        let pastStart = TodayZonePull.distance(offset: -90, contentHeight: 400, containerHeight: 600,
                                               topInset: 20, bottomInset: 10)
        #expect(TodayZonePull.destination(distance: pastStart) == .previous)
        #expect(TodayZonePull.destination(distance: 63) == nil)
        #expect(TodayZonePull.destination(distance: -63) == nil)
        // Returning below the threshold before release cancels, even after it was crossed.
        #expect(TodayZonePull.destination(distance: 80) == .next)
        #expect(TodayZonePull.destination(distance: 20) == nil)
    }
}
