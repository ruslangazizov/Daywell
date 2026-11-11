import Domain
import Foundation
import Testing

struct AppIconBadgeTests {
    private let timeZone = TimeZone(secondsFromGMT: 0)!
    private let day = try! LocalDate(year: 2026, month: 11, day: 10)

    @Test func dailyLayoutsCountOnlyUnfinishedOccurrencesToday() throws {
        let morning = try task("Morning", start: 8, end: 9)
        let evening = try task("Evening", start: 19, end: 20)
        let anytime = try task("Anytime")
        let yesterday = try DWTask(title: "Yesterday", schedule: .once(on: LocalDate(year: 2026, month: 11, day: 9)))
        let tomorrow = try DWTask(title: "Tomorrow", schedule: .once(on: LocalDate(year: 2026, month: 11, day: 11)))
        let archived = try DWTask(title: "Archived", schedule: .once(on: day), createdAt: date(0), archivedAt: date(0))
        let completed = try OccurrenceRecord(id: .init(taskID: evening.id, day: day), outcome: .completed(at: date(20)))
        for layout in [TodayLayout.timeline, .agenda] {
            #expect(AppIconBadge.count(tasks: [morning, evening, anytime, yesterday, tomorrow, archived],
                                      occurrences: [completed], layout: layout, zones: DayZone.defaults,
                                      now: date(20), timeZone: timeZone) == 2)
        }
    }

    @Test func eveningIgnoresUnfinishedMorningAndUnzonedTasks() throws {
        let morning = try task("Morning", start: 8, end: 9)
        let evening = try task("Evening", start: 19, end: 20)
        let anytime = try task("Anytime")
        let completed = try OccurrenceRecord(id: .init(taskID: evening.id, day: day), outcome: .completed(at: date(20)))
        #expect(count([morning, evening, anytime], at: 20) == 1)
        #expect(count([morning, evening, anytime], records: [completed], at: 20) == 0)
        #expect(count([morning, evening, anytime], at: 23) == 0)
        #expect(count([morning], at: 8, zones: []) == 0)
    }

    @Test func boundariesAndOverlapsMatchTodayZones() throws {
        let crossing = try task("Crossing", start: 10, end: 12)
        let morningOnly = try task("Morning only", start: 8, end: 11)
        #expect(count([crossing, morningOnly], at: 10) == 2)
        #expect(count([crossing, morningOnly], at: 11) == 1)
        #expect(count([crossing, morningOnly], at: 18) == 0)
    }

    @Test func overnightZoneUsesTodaysScheduledOccurrences() throws {
        let night = try DayZone(name: "Night", window: TimeWindow(start: LocalTime(hour: 22, minute: 0),
                                                                 end: LocalTime(hour: 6, minute: 0), endDay: .nextDay))
        let task = try task("Early", start: 1, end: 2)
        #expect(count([task], at: 1, zones: [night]) == 1)
        #expect(count([task], at: 6, zones: [night]) == 0)
    }

    @Test func futureUpdatesClearAtZoneEndAndRecalculateAtMidnight() throws {
        let task = try task("Evening", start: 19, end: 20)
        let zoneUpdates = AppIconBadge.updates(tasks: [task], occurrences: [], layout: .zones,
                                             zones: DayZone.defaults, now: date(17), timeZone: timeZone)
        #expect(zoneUpdates.first?.fireDate == date(18))
        #expect(zoneUpdates.first?.count == 1)
        #expect(zoneUpdates.dropFirst().first?.fireDate == date(23))
        #expect(zoneUpdates.dropFirst().first?.count == 0)
        let dailyUpdates = AppIconBadge.updates(tasks: [task], occurrences: [], layout: .timeline,
                                              zones: [], now: date(20), timeZone: timeZone)
        #expect(dailyUpdates.first?.fireDate == date(24))
        #expect(dailyUpdates.first?.count == 0)
    }

    @Test func timeZoneUsesTheLocalCalendarDay() throws {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let tomorrow = try LocalDate(year: 2026, month: 11, day: 11)
        let task = try DWTask(title: "Tomorrow", schedule: .once(on: tomorrow))
        // 23:00 UTC is already tomorrow in Berlin.
        #expect(AppIconBadge.count(tasks: [task], occurrences: [], layout: .agenda, zones: [],
                                  now: date(23), timeZone: berlin) == 1)
        #expect(AppIconBadge.count(tasks: [task], occurrences: [], layout: .agenda, zones: [],
                                  now: date(23), timeZone: timeZone) == 0)
    }

    @Test func autumnClockRollbackReentersTheZone() throws {
        let berlin = TimeZone(identifier: "Europe/Berlin")!
        let day = try LocalDate(year: 2026, month: 10, day: 25)
        let window = try TimeWindow(start: LocalTime(hour: 2, minute: 0), end: LocalTime(hour: 2, minute: 30))
        let zone = try DayZone(name: "Early", window: window)
        let task = try DWTask(title: "Read", schedule: .once(on: day), timeWindow: window)
        let now = ISO8601DateFormatter().date(from: "2026-10-24T23:00:00Z")!
        let updates = AppIconBadge.updates(tasks: [task], occurrences: [], layout: .zones,
                                          zones: [zone], now: now, timeZone: berlin)
        #expect(updates.prefix(4).map(\.count) == [1, 0, 1, 0])
        #expect(updates.prefix(4).map(\.fireDate) == [
            "2026-10-25T00:00:00Z", "2026-10-25T00:30:00Z",
            "2026-10-25T01:00:00Z", "2026-10-25T01:30:00Z"
        ].map { ISO8601DateFormatter().date(from: $0)! })
    }

    private func task(_ title: String, start: Int? = nil, end: Int? = nil) throws -> DWTask {
        let window = try start.flatMap { start in
            try end.map { try TimeWindow(start: LocalTime(hour: start, minute: 0), end: LocalTime(hour: $0, minute: 0)) }
        }
        return try DWTask(title: title, schedule: .once(on: day), timeWindow: window)
    }

    private func date(_ hour: Int) -> Date {
        ISO8601DateFormatter().date(from: "2026-11-10T00:00:00Z")!.addingTimeInterval(Double(hour * 3600))
    }

    private func count(_ tasks: [DWTask], records: [OccurrenceRecord] = [], at hour: Int,
                       zones: [DayZone] = DayZone.defaults) -> Int {
        AppIconBadge.count(tasks: tasks, occurrences: records, layout: .zones, zones: zones,
                           now: date(hour), timeZone: timeZone)
    }
}
