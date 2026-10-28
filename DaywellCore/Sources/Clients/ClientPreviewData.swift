import Domain
import Foundation
import IdentifiedCollections

#if DEBUG
/// One snapshot shared by all three clients, even if their fetches straddle midnight.
/// Dates follow the preview's launch day; IDs and the relative scenarios stay stable.
/// In the date strip: yesterday is complete, today is mixed, tomorrow is pending,
/// +8 days has only untimed tasks, and +9 days is empty. Relaunch after changing time zone.
nonisolated struct ClientPreviewData: Sendable {
    static let shared: Result<Self, Error> = Result {
        try Self(now: .now, timeZone: .current)
    }

    let tasks: [DWTask]
    let occurrences: IdentifiedArrayOf<OccurrenceRecord>
    let zones: [DayZone]

    init(now: Date, timeZone: TimeZone) throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startOfToday = calendar.startOfDay(for: now)

        func date(_ offset: Int, hour: Int = 0, minute: Int = 0) -> Date {
            let day = calendar.date(byAdding: .day, value: offset, to: startOfToday)!
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        func day(_ offset: Int) throws -> LocalDate {
            try LocalDate(date(offset), in: timeZone)
        }

        func window(_ start: Int, _ end: Int, overnight: Bool = false) throws -> TimeWindow {
            try TimeWindow(
                start: LocalTime(hour: start / 60, minute: start % 60),
                end: LocalTime(hour: end / 60, minute: end % 60),
                endDay: overnight ? .nextDay : .sameDay
            )
        }

        // Disjoint, fixed IDs for tasks (1...15) and zones (101...104).
        func id(_ value: UInt8) -> UUID {
            UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
        }

        let morning = try DayZone(id: id(101), name: "Morning", window: window(360, 720))
        let afternoon = try DayZone(id: id(102), name: "Afternoon", window: window(720, 1080))
        let evening = try DayZone(id: id(103), name: "Evening", window: window(1080, 1320))
        let night = try DayZone(id: id(104), name: "Night", window: window(1320, 120, overnight: true))
        zones = [morning, afternoon, evening, night]

        let today = try day(0)
        let daily = try TaskSchedule.repeating(Recurrence(
            startsOn: day(-14), endsOn: day(7), pattern: .daily(every: 1)
        ))
        let everyOtherDay = try TaskSchedule.repeating(Recurrence(
            startsOn: day(-14), endsOn: day(7), pattern: .daily(every: 2)
        ))
        let weekly = try TaskSchedule.repeating(Recurrence(
            startsOn: day(-14), endsOn: day(7),
            pattern: .weekly(every: 1, weekdays: [today.weekday, day(2).weekday])
        ))
        let monthly = try TaskSchedule.repeating(Recurrence(
            startsOn: day(-14), endsOn: day(7), pattern: .monthly(every: 1, day: today.day)
        ))

        func task(
            _ number: UInt8,
            _ title: String,
            description: String? = nil,
            schedule: TaskSchedule? = nil,
            zone: DayZone? = nil,
            time: TimeWindow? = nil,
            color: TaskColorToken = .lilac,
            archived: Bool = false
        ) throws -> DWTask {
            try DWTask(
                id: id(number), title: title, description: description,
                schedule: schedule ?? .once(on: today), zoneID: zone?.id,
                timeWindow: time, color: color, createdAt: date(-30),
                updatedAt: archived ? date(-1) : date(-14),
                archivedAt: archived ? date(-1) : nil
            )
        }

        tasks = try [
            task(1, "Water", schedule: daily, zone: morning,
                 time: window(420, 425), color: .blue),
            task(2, "Stretch and breathe", description: "A gentle start before checking the phone.",
                 schedule: daily, zone: morning, time: window(435, 465), color: .mint),
            // Inherits the zone window; the next two tasks overlap it and each other.
            task(3, "Make room for a slow morning", schedule: everyOtherDay,
                 zone: morning, color: .peach),
            task(4, "Prepare the presentation and review all feedback before the team planning session",
                 description: "Review the draft, check the figures, and write down open questions.\n"
                    + "Leave time for a final read-through and share the notes with the team.",
                 zone: morning, time: window(540, 660), color: .lilac),
            task(5, "Design review", zone: morning, time: window(570, 615), color: .rose),
            task(6, "Lunch away from the desk", schedule: daily, zone: afternoon,
                 time: window(750, 795), color: .peach),
            task(7, "Walk outside 🌿", schedule: weekly, zone: afternoon,
                 time: window(900, 945), color: .mint),
            task(8, "Read a chapter", schedule: daily, zone: evening, color: .lilac),
            task(9, "Late-night wind down", description: "The window continues into the next day.",
                 zone: night, time: window(1410, 30, overnight: true), color: .blue),
            task(10, "Call Mum", color: .rose),
            task(11, "Collect ideas for a weekend trip, including places to visit and things to pack",
                 description: "An untimed task with a long title to check wrapping.", color: .peach),
            task(12, "Monthly reflection", schedule: monthly,
                 time: window(1020, 1080), color: .blue),
            task(13, "Pick up groceries", schedule: .once(on: day(1)),
                 time: window(1080, 1110), color: .mint),
            task(14, "Plan something just for yourself", schedule: .once(on: day(8)), color: .rose),
            // Kept in the client response to exercise the UI's archived-task filter.
            task(15, "Archived routine", schedule: daily, zone: morning, archived: true),
        ]

        let yesterday = try day(-1)
        var records: IdentifiedArrayOf<OccurrenceRecord> = []
        for task in tasks where !task.isArchived && task.schedule.occurs(on: yesterday) {
            records.append(try OccurrenceRecord(
                id: TaskOccurrenceID(taskID: task.id, day: yesterday),
                outcome: .completed(at: date(-1, hour: 21))
            ))
        }
        for number: UInt8 in [1, 2, 10] {
            records.append(try OccurrenceRecord(
                id: TaskOccurrenceID(taskID: id(number), day: today),
                outcome: .completed(at: min(now, date(0, hour: 8)))
            ))
        }
        records.append(try OccurrenceRecord(
            id: TaskOccurrenceID(taskID: id(7), day: today),
            outcome: .skipped(at: min(now, date(0, hour: 9)))
        ))
        occurrences = records
    }
}
#endif
