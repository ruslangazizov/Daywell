import Foundation

public nonisolated struct AppIconBadgeUpdate: Equatable, Sendable, Identifiable {
    public let fireDate: Date
    public let count: Int
    public var id: String { "app-icon-badge/\(Int(fireDate.timeIntervalSince1970))" }
}

/// Uses the real local day and clock, independently of the date or zone being browsed.
public nonisolated enum AppIconBadge {
    public static func count(
        tasks: [DWTask], occurrences: [OccurrenceRecord], layout: TodayLayout,
        zones: [DayZone], now: Date, timeZone: TimeZone
    ) -> Int {
        guard let today = try? LocalDate(now, in: timeZone) else { return 0 }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let time = try? LocalTime(hour: calendar.component(.hour, from: now),
                                  minute: calendar.component(.minute, from: now))
        let currentZone = time.flatMap { time in zones.first { $0.isActive(at: time) } }
        if layout == .zones, currentZone == nil { return 0 }
        let completed = Set(occurrences.filter(\.isCompleted).map(\.id))
        return tasks.count { task in
            !task.isArchived && task.schedule.occurs(on: today)
                && !completed.contains(TaskOccurrenceID(taskID: task.id, day: today))
                && (layout != .zones || currentZone.map { task.timeWindow?.overlaps($0.window) == true } == true)
        }
    }

    /// Silent, one-shot changes keep the badge current while the app is suspended.
    /// Refilled on every reconciliation; shares the system queue with task reminders.
    public static func updates(
        tasks: [DWTask], occurrences: [OccurrenceRecord], layout: TodayLayout,
        zones: [DayZone], now: Date, timeZone: TimeZone, limit: Int = 64
    ) -> [AppIconBadgeUpdate] {
        guard limit > 0 else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: now)
        var boundaries = Set<Date>()
        for offset in 0...64 {
            guard let midnight = calendar.date(byAdding: .day, value: offset, to: start),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: midnight) else { continue }
            if midnight > now { boundaries.insert(midnight) }
            guard layout == .zones else { continue }
            for time in zones.flatMap({ [$0.window.start, $0.window.end] }) {
                // Include both occurrences of a repeated hour and the first valid instant
                // after a spring gap, matching the wall-clock membership calculation.
                for policy in [Calendar.RepeatedTimePolicy.first, .last] {
                    if let date = calendar.nextDate(
                        after: midnight.addingTimeInterval(-1),
                        matching: time.components,
                        matchingPolicy: .nextTime,
                        repeatedTimePolicy: policy
                    ), date > now, date < nextDay {
                        boundaries.insert(date)
                    }
                }
            }
            if let transition = timeZone.nextDaylightSavingTimeTransition(after: midnight),
               transition > now, transition < nextDay {
                boundaries.insert(transition)
            }
        }
        var previous = count(
            tasks: tasks,
            occurrences: occurrences,
            layout: layout,
            zones: zones,
            now: now,
            timeZone: timeZone
        )
        var updates: [AppIconBadgeUpdate] = []
        for date in boundaries.sorted() {
            let value = count(
                tasks: tasks,
                occurrences: occurrences,
                layout: layout,
                zones: zones,
                now: date,
                timeZone: timeZone
            )
            guard value != previous else { continue }
            updates.append(AppIconBadgeUpdate(fireDate: date, count: value))
            previous = value
            if updates.count == limit { break }
        }
        return updates
    }
}
