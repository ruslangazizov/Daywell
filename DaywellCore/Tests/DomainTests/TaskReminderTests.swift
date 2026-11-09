import Foundation
import Testing
@testable import Domain

struct TaskReminderTests {
    private let zone = TimeZone(secondsFromGMT: 0)!
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func task(day: Int = 10, reminder: TaskReminder? = .atStart,
                      schedule: TaskSchedule? = nil, timed: Bool = true) throws -> DWTask {
        try DWTask(title: "Read", schedule: schedule ?? .once(on: LocalDate(year: 2026, month: 11, day: day)),
                   timeWindow: timed ? TimeWindow(start: LocalTime(hour: 0, minute: 10), end: LocalTime(hour: 1, minute: 0)) : nil,
                   reminder: reminder)
    }

    @Test func leadTimeCrossesMidnightWithoutChangingOccurrenceDay() throws {
        let task = try task(reminder: .beforeStart(.fifteenMinutes))
        let requests = TaskReminderPlanner.requests(tasks: [task], occurrences: [],
            now: date("2026-11-09T20:00:00Z"), timeZone: zone)
        #expect(requests.count == 1)
        #expect(requests.first?.fireDate == date("2026-11-09T23:55:00Z"))
        #expect(requests.first?.occurrenceID.day == (try LocalDate(year: 2026, month: 11, day: 10)))
    }

    @Test func excludesPastCompletedSkippedAndUnconfiguredTasks() throws {
        let completed = try task()
        let skipped = try task()
        let records = try [
            OccurrenceRecord(id: TaskOccurrenceID(taskID: completed.id, day: completed.schedule.startsOn), outcome: .completed(at: .now)),
            OccurrenceRecord(id: TaskOccurrenceID(taskID: skipped.id, day: skipped.schedule.startsOn), outcome: .skipped(at: .now))
        ]
        let tasks = try [completed, skipped, task(day: 8), task(reminder: nil), task(timed: false)]
        #expect(TaskReminderPlanner.requests(tasks: tasks, occurrences: records,
            now: date("2026-11-09T20:00:00Z"), timeZone: zone).isEmpty)
    }

    @Test func untimedTaskUsesExplicitClockTime() throws {
        let task = try task(reminder: .atTime(LocalTime(hour: 9, minute: 30)), timed: false)
        let requests = TaskReminderPlanner.requests(tasks: [task], occurrences: [],
            now: date("2026-11-09T20:00:00Z"), timeZone: zone)
        #expect(requests.first?.fireDate == date("2026-11-10T09:30:00Z"))
    }

    @Test func monthlySkipsMissingDatesAndHonorsEndDate() throws {
        let schedule = try TaskSchedule.repeating(Recurrence(
            startsOn: LocalDate(year: 2026, month: 1, day: 31),
            endsOn: LocalDate(year: 2026, month: 4, day: 30), pattern: .monthly(every: 1, day: 31)))
        let requests = TaskReminderPlanner.requests(tasks: [try task(schedule: schedule)], occurrences: [],
            now: date("2026-01-01T00:00:00Z"), timeZone: zone)
        #expect(requests.map(\.fireDate) == [date("2026-01-31T00:10:00Z"), date("2026-03-31T00:10:00Z")])
    }

    @Test func capsQueueAtNearest64AcrossTasks() throws {
        let schedule = try TaskSchedule.repeating(Recurrence(
            startsOn: LocalDate(year: 2026, month: 11, day: 10), pattern: .daily(every: 1)))
        let requests = TaskReminderPlanner.requests(tasks: [try task(schedule: schedule), try task(schedule: schedule)],
            occurrences: [], now: date("2026-11-09T20:00:00Z"), timeZone: zone)
        #expect(requests.count == 64)
        #expect(Set(requests.map(\.id)).count == 64)
        #expect(requests.last?.fireDate == date("2026-12-11T00:10:00Z"))
    }

    @Test func missingDSTTimeMovesForwardWithinSameDay() throws {
        let task = try DWTask(title: "DST", schedule: .once(on: LocalDate(year: 2026, month: 3, day: 29)),
                              reminder: .atTime(LocalTime(hour: 2, minute: 30)))
        let requests = TaskReminderPlanner.requests(tasks: [task], occurrences: [],
            now: date("2026-03-28T00:00:00Z"), timeZone: TimeZone(identifier: "Europe/Belgrade")!)
        #expect(requests.first?.fireDate == date("2026-03-29T01:30:00Z"))
    }

    @Test func reminderRoundTripsAndOldPayloadDefaultsToNone() throws {
        let original = try task(reminder: .beforeStart(.oneHour))
        let encoded = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(DWTask.self, from: encoded).reminder == .beforeStart(.oneHour))
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json.removeValue(forKey: "reminder")
        let legacy = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode(DWTask.self, from: legacy).reminder == nil)
    }
}
