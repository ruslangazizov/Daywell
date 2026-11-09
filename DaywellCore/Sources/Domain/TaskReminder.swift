import Foundation

/// Nil on DWTask means no reminder. Relative reminders require a time window.
public nonisolated enum TaskReminder: Hashable, Codable, Sendable {
    public enum LeadTime: Int, CaseIterable, Codable, Sendable {
        case fiveMinutes = 5, fifteenMinutes = 15, thirtyMinutes = 30, oneHour = 60
    }

    case atStart
    case beforeStart(LeadTime)
    case atTime(LocalTime)
}

public nonisolated struct TaskReminderRequest: Equatable, Sendable, Identifiable {
    public let occurrenceID: TaskOccurrenceID
    public let title: String
    public let fireDate: Date

    public var id: String {
        let day = occurrenceID.day
        return "task-reminder/\(occurrenceID.taskID.uuidString)/\(day.year)/\(day.month)/\(day.day)"
    }
}

public nonisolated enum TaskReminderPlanner {
    public static func requests(
        tasks: [DWTask], occurrences: [OccurrenceRecord], now: Date,
        timeZone: TimeZone, limit: Int = 64
    ) -> [TaskReminderRequest] {
        guard limit > 0, let today = try? LocalDate(now, in: timeZone) else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let recorded = Set(occurrences.map(\.id))
        var requests: [TaskReminderRequest] = []
        for task in tasks where !task.isArchived {
            guard let reminder = task.reminder else { continue }
            let time: LocalTime
            let leadMinutes: Int
            switch reminder {
            case .atStart:
                guard let start = task.timeWindow?.start else { continue }
                time = start
                leadMinutes = 0
            case .beforeStart(let lead):
                guard let start = task.timeWindow?.start else { continue }
                time = start
                leadMinutes = lead.rawValue
            case .atTime(let chosen):
                time = chosen
                leadMinutes = 0
            }
            var day = task.schedule.nextReminderDay(onOrAfter: today)
            var count = 0
            while let current = day, count < limit {
                let id = TaskOccurrenceID(taskID: task.id, day: current)
                // Preserve wall-clock minutes in a spring DST gap and use the first
                // occurrence of a repeated autumn hour. Identity stays on the task day.
                if !recorded.contains(id), let midnight = calendar.date(from: current.components),
                   let start = calendar.nextDate(after: midnight.addingTimeInterval(-1),
                                                 matching: time.components,
                                                 matchingPolicy: .nextTimePreservingSmallerComponents,
                                                 repeatedTimePolicy: .first, direction: .forward),
                   (try? LocalDate(start, in: timeZone)) == current {
                    let fireDate = start.addingTimeInterval(-Double(leadMinutes * 60))
                    if fireDate > now {
                        requests.append(.init(occurrenceID: id, title: task.title, fireDate: fireDate))
                        count += 1
                    }
                }
                guard let next = current.reminderAddingDays(1) else { break }
                day = task.schedule.nextReminderDay(onOrAfter: next)
            }
        }
        return Array(requests.sorted {
            if $0.fireDate != $1.fireDate { return $0.fireDate < $1.fireDate }
            return $0.id < $1.id
        }.prefix(limit))
    }
}

private extension TaskSchedule {
    /// Jump by recurrence periods so a sparse schedule doesn't require scanning years.
    nonisolated func nextReminderDay(onOrAfter lowerBound: LocalDate) -> LocalDate? {
        let lower = max(startsOn, lowerBound)
        if let end = endsOn, lower > end { return nil }
        guard case .repeating(let rule) = self else { return lower <= startsOn ? startsOn : nil }
        let candidate: LocalDate?
        switch rule.pattern {
        case .daily(let interval):
            let remainder = lower.daysSince(rule.startsOn) % interval
            candidate = lower.reminderAddingDays(remainder == 0 ? 0 : interval - remainder)
        case .weekly(let interval, let weekdays):
            let elapsed = lower.daysSince(rule.startsOn) + rule.startsOn.weekday.mondayBasedIndex
            let week = elapsed / 7
            let remainder = week % interval
            let jump = remainder == 0 ? 0 : interval - remainder
            guard jump <= 520_000,
                  let activeWeek = lower.reminderAddingDays(jump * 7 - lower.weekday.mondayBasedIndex)
            else { return nil }
            let days = weekdays.sorted { $0.mondayBasedIndex < $1.mondayBasedIndex }
            if let match = days.compactMap({ activeWeek.reminderAddingDays($0.mondayBasedIndex) })
                .first(where: { $0 >= lower }) {
                candidate = match
            } else if interval <= 520_000, let first = days.first {
                candidate = activeWeek.reminderAddingDays(interval * 7 + first.mondayBasedIndex)
            } else { candidate = nil }
        case .monthly(let interval, let targetDay):
            let startMonth = (rule.startsOn.year - 1) * 12 + rule.startsOn.month - 1
            let lowerMonth = (lower.year - 1) * 12 + lower.month - 1
            let remainder = (lowerMonth - startMonth) % interval
            let jump = remainder == 0 ? 0 : interval - remainder
            guard jump < 120_000 else { return nil }
            var month = lowerMonth + jump
            var match: LocalDate?
            while month < 9999 * 12 {
                if let value = try? LocalDate(year: month / 12 + 1, month: month % 12 + 1, day: targetDay),
                   value >= lower {
                    match = value
                    break
                }
                guard interval < 120_000 else { break }
                month += interval
            }
            candidate = match
        }
        guard let candidate, endsOn.map({ candidate <= $0 }) ?? true else { return nil }
        return candidate
    }
}

private extension LocalDate {
    nonisolated func reminderAddingDays(_ count: Int) -> LocalDate? {
        guard count <= 3_652_059 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let anchor = calendar.date(from: components),
              let date = calendar.date(byAdding: .day, value: count, to: anchor) else { return nil }
        return try? LocalDate(date, in: calendar.timeZone)
    }
}
