import Foundation
import Testing
@testable import Domain

@MainActor
struct DaywellModelsTests {
    private func date(_ day: Int) throws -> LocalDate {
        try date(2026, 10, day)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> LocalDate {
        try LocalDate(year: year, month: month, day: day)
    }

    private func window(_ start: Int, _ end: Int, overnight: Bool = false) throws -> TimeWindow {
        try TimeWindow(start: LocalTime(hour: start, minute: 0),
                       end: LocalTime(hour: end, minute: 0),
                       endDay: overnight ? .nextDay : .sameDay)
    }

    @Test(arguments: [(2026, 2, 29), (2026, 4, 31), (2026, 13, 1), (0, 1, 1), (10000, 1, 1)])
    func invalidDates(values: (Int, Int, Int)) {
        #expect(throws: ModelValidationError.invalidDate) {
            try LocalDate(year: values.0, month: values.1, day: values.2)
        }
    }

    @Test func leapDateAndCalendarArithmetic() throws {
        let leapDay = try date(2024, 2, 29)
        #expect(try date(2024, 3, 1).daysSince(leapDay) == 1)
        #expect(try date(2026, 10, 24).weekday == .saturday)
        #expect(try date(2026, 10, 26).daysSince(date(2026, 10, 24)) == 2)
        #expect(try date(2026, 10, 24).daysSince(date(2026, 10, 26)) == -2)
    }

    @Test(arguments: [(-1, 0), (24, 0), (12, -1), (12, 60)])
    func invalidTimes(values: (Int, Int)) {
        #expect(throws: ModelValidationError.invalidTime) {
            try LocalTime(hour: values.0, minute: values.1)
        }
    }

    @Test func windowBoundariesAndMidnight() throws {
        let morning = try window(7, 11)
        let daytime = try window(11, 18)
        #expect(morning.durationInMinutes == 240)
        #expect(try morning.contains(LocalTime(hour: 7, minute: 0)))
        #expect(try !morning.contains(LocalTime(hour: 11, minute: 0)))
        #expect(!morning.overlaps(daytime))

        let night = try window(22, 2, overnight: true)
        #expect(night.crossesMidnight)
        #expect(night.durationInMinutes == 240)
        #expect(try night.contains(LocalTime(hour: 0, minute: 0)))
        #expect(try !night.contains(LocalTime(hour: 2, minute: 0)))
        #expect(try night.overlaps(window(1, 3)))
        #expect(try !night.overlaps(window(2, 7)))

        let fullDay = try window(7, 7, overnight: true)
        #expect(fullDay.isFullDay)
        #expect(fullDay.overlaps(morning))
        #expect(try window(22, 0, overnight: true).durationInMinutes == 120)
        #expect(throws: ModelValidationError.invalidTimeWindow) { try window(7, 7) }
        #expect(throws: ModelValidationError.invalidTimeWindow) { try window(22, 2) }
        #expect(throws: ModelValidationError.invalidTimeWindow) { try window(7, 11, overnight: true) }
    }

    @Test func zoneCollectionValidation() throws {
        let morning = try DayZone(name: "  Morning\n", window: window(7, 11))
        let day = try DayZone(name: "Day", window: window(11, 18))
        #expect(morning.name == "Morning")
        try DayZone.validate([morning, day])
        try DayZone.validate([])
        #expect(throws: ModelValidationError.duplicateZoneID(morning.id)) {
            try DayZone.validate([morning, morning])
        }
        let overlapping = try DayZone(name: "Overlap", window: window(10, 12))
        #expect(throws: ModelValidationError.overlappingZones(morning.id, overlapping.id)) {
            try DayZone.validate([morning, overlapping])
        }
        #expect(throws: ModelValidationError.emptyName) {
            try DayZone(name: " \n", window: morning.window)
        }
    }

    @Test func recurrenceValidation() throws {
        let start = try date(24)
        #expect(throws: ModelValidationError.invalidRepeatInterval) {
            try Recurrence(startsOn: start, pattern: .daily(every: 0))
        }
        #expect(throws: ModelValidationError.emptyWeekdays) {
            try Recurrence(startsOn: start, pattern: .weekly(every: 1, weekdays: []))
        }
        #expect(throws: ModelValidationError.invalidDayOfMonth) {
            try Recurrence(startsOn: start, pattern: .monthly(every: 1, day: 32))
        }
        #expect(throws: ModelValidationError.invalidDateRange) {
            try Recurrence(startsOn: start, endsOn: date(23), pattern: .daily(every: 1))
        }
    }

    @Test func dailyAndOnceSchedules() throws {
        let rule = try Recurrence(startsOn: date(24), endsOn: date(28), pattern: .daily(every: 2))
        for day in [24, 26, 28] { #expect(try rule.occurs(on: date(day))) }
        for day in [23, 25, 27, 29, 30] { #expect(try !rule.occurs(on: date(day))) }
        let once = try TaskSchedule.once(on: date(24))
        #expect(!once.isRepeating)
        #expect(try once.occurs(on: date(24)))
        #expect(try !once.occurs(on: date(25)))
        #expect(once.startsOn == once.endsOn)
    }

    @Test func weeklyAnchorsUseMondayAcrossYearBoundary() throws {
        // Wednesday start: the partial start week counts as week zero.
        let rule = try Recurrence(startsOn: date(2025, 12, 31),
                                  pattern: .weekly(every: 2, weekdays: [.monday, .wednesday]))
        #expect(try rule.occurs(on: date(2025, 12, 31)))
        #expect(try !rule.occurs(on: date(2025, 12, 29)))
        #expect(try !rule.occurs(on: date(2026, 1, 5)))
        #expect(try rule.occurs(on: date(2026, 1, 12)))
        #expect(try rule.occurs(on: date(2026, 1, 14)))
        #expect(try !rule.occurs(on: date(2026, 1, 13)))
    }

    @Test func monthlyMissingDaysAreSkipped() throws {
        let rule = try Recurrence(startsOn: date(2026, 1, 31), pattern: .monthly(every: 1, day: 31))
        #expect(try !rule.occurs(on: date(2026, 2, 28)))
        #expect(try !rule.occurs(on: date(2026, 3, 1)))
        #expect(try rule.occurs(on: date(2026, 3, 31)))
        let everyTwo = try Recurrence(startsOn: date(2025, 12, 15), pattern: .monthly(every: 2, day: 15))
        #expect(try !everyTwo.occurs(on: date(2026, 1, 15)))
        #expect(try everyTwo.occurs(on: date(2026, 2, 15)))
    }

    @Test func taskValidationAndDerivedProperties() throws {
        let zone = try DayZone(name: "Morning", window: window(7, 11))
        let createdAt = Date(timeIntervalSince1970: 100)
        let schedule = try TaskSchedule.repeating(Recurrence(startsOn: date(24), pattern: .daily(every: 1)))
        let task = try DWTask(
            title: " Read ",
            description: " \n",
            schedule: schedule,
            zoneID: zone.id,
            createdAt: createdAt
        )
        #expect(task.title == "Read")
        #expect(task.description == nil)
        #expect(task.isHabit)
        #expect(!task.isArchived)
        #expect(task.updatedAt == createdAt)
        #expect(try task.effectiveTimeWindow(in: [zone]) == zone.window)
        #expect(throws: ModelValidationError.unknownZone(zone.id)) { try task.validateZone(in: []) }
        #expect(throws: ModelValidationError.invalidTimestampOrder) {
            try DWTask(title: "Read", schedule: schedule, createdAt: createdAt,
                            updatedAt: createdAt.addingTimeInterval(-1))
        }
        #expect(throws: ModelValidationError.invalidTimestampOrder) {
            try DWTask(title: "Read", schedule: schedule, createdAt: createdAt,
                            archivedAt: createdAt.addingTimeInterval(1))
        }
        #expect(throws: ModelValidationError.invalidTimestamp) {
            try DWTask(title: "Read", schedule: schedule, createdAt: Date(timeIntervalSince1970: .infinity))
        }
        #expect(throws: ModelValidationError.emptyName) { try DWTask(title: " ", schedule: schedule) }
    }

    @Test func taskWindowOverridesZoneAndUnassignedHasNoWindow() throws {
        let zone = try DayZone(name: "Morning", window: window(7, 11))
        let custom = try window(8, 9)
        let schedule = try TaskSchedule.once(on: date(24))
        let task = try DWTask(title: "Read", schedule: schedule, zoneID: zone.id, timeWindow: custom)
        #expect(try task.effectiveTimeWindow(in: [zone]) == custom)
        let unassigned = try DWTask(title: "Read", schedule: schedule)
        #expect(try unassigned.effectiveTimeWindow(in: []) == nil)
    }

    @Test func occurrenceIdentityAndOutcome() throws {
        let id = try TaskOccurrenceID(taskID: UUID(), day: date(24))
        let instant = Date(timeIntervalSince1970: 1_792_882_800)
        let completed = try OccurrenceRecord(id: id, outcome: .completed(at: instant))
        let skipped = try OccurrenceRecord(id: id, outcome: .skipped(at: instant))
        #expect(completed.isCompleted && !completed.isSkipped)
        #expect(skipped.isSkipped && !skipped.isCompleted)
        #expect(completed.id == skipped.id)
        #expect(completed.completedAt == instant)
        #expect(completed.day == id.day)
        #expect(throws: ModelValidationError.invalidTimestamp) {
            try OccurrenceRecord(id: id, outcome: .completed(at: Date(timeIntervalSince1970: .nan)))
        }
    }

    @Test func decodingCannotBypassValidation() throws {
        let decoder = JSONDecoder()
        #expect(throws: ModelValidationError.invalidDate) {
            try decoder.decode(LocalDate.self, from: Data(#"{"year":2026,"month":2,"day":30}"#.utf8))
        }
        #expect(throws: ModelValidationError.invalidTime) {
            try decoder.decode(LocalTime.self, from: Data(#"{"hour":24,"minute":0}"#.utf8))
        }
        #expect(throws: ModelValidationError.invalidTimeWindow) {
            try decoder.decode(TimeWindow.self, from: Data(#"{"start":{"hour":7,"minute":0},"end":{"hour":6,"minute":0},"endDay":"sameDay"}"#.utf8))
        }
        let recurrence = try Recurrence(startsOn: date(24), pattern: .daily(every: 1))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(recurrence)) as? [String: Any])
        json["pattern"] = ["daily": ["every": 0]]
        let invalid = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: ModelValidationError.invalidRepeatInterval) {
            try decoder.decode(Recurrence.self, from: invalid)
        }
        let task = try DWTask(title: "Read", schedule: .repeating(recurrence))
        json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(task)) as? [String: Any])
        json["title"] = "  "
        let invalidTask = try JSONSerialization.data(withJSONObject: json)
        #expect(throws: ModelValidationError.emptyName) {
            try decoder.decode(DWTask.self, from: invalidTask)
        }
    }

    @Test func codableRoundTrips() throws {
        let rule = try Recurrence(startsOn: date(24), pattern: .weekly(every: 2, weekdays: [.monday, .friday]))
        let task = try DWTask(title: "Read", schedule: .repeating(rule), timeWindow: window(22, 2, overnight: true))
        let decoded = try JSONDecoder().decode(DWTask.self, from: JSONEncoder().encode(task))
        #expect(decoded == task)
        let record = try OccurrenceRecord(id: TaskOccurrenceID(taskID: task.id, day: date(24)), outcome: .skipped(at: .now))
        #expect(try JSONDecoder().decode(OccurrenceRecord.self, from: JSONEncoder().encode(record)) == record)
    }
}
