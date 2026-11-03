import Domain
import Foundation

public nonisolated enum StatisticsPeriod: String, CaseIterable, Sendable {
    case week = "7 days", month = "4 weeks", allTime = "All time"

    var days: Int? {
        switch self {
        case .week: 7
        case .month: 28
        case .allTime: nil
        }
    }
}

public nonisolated enum StatisticsDestination: Hashable, Identifiable, Sendable {
    case about, hour, weekday, habits
    case habit(UUID)
    case activity(StatisticsActivityFilter)
    public var id: Self { self }
}

public nonisolated enum StatisticsActivityFilter: Hashable, Sendable {
    case period, weekday(Int), habit(UUID)
}

/// Read-only projection of persisted outcomes. Never infer missed sessions from
/// today's schedule: the store does not yet retain historical schedule snapshots.
struct StatisticsSummary: Equatable {
    struct Bucket: Equatable, Identifiable {
        let id: Int
        let label: String
        let accessibilityLabel: String
        let count: Int
    }

    struct Habit: Equatable, Identifiable {
        let id: UUID
        let title: String
        let count: Int
        let lifetimeCount: Int
        let firstCompletion: Date?
    }

    struct Activity: Equatable, Identifiable {
        let id: TaskOccurrenceID
        let title: String
        let day: Date
        let isCompleted: Bool
        let recordedAt: Date
    }

    let activity: [Activity]
    let period: StatisticsPeriod
    let start: Date
    let end: Date
    let historyDays: Int
    let hasAnyCompletions: Bool
    let total: Int
    let previousTotal: Int?
    let bars: [Bucket]
    let hours: [Bucket]
    let weekdays: [Bucket]
    let weekdayOccurrences: [Int]
    let habits: [Habit]
    let calendar: Calendar

    func activity(matching filter: StatisticsActivityFilter) -> [Activity] {
        activity.filter { item in
            switch filter {
            case .habit(let id): return item.id.taskID == id
            case .period: return item.isCompleted && item.day >= start
            case .weekday(let index):
                return item.isCompleted && item.day >= start && (calendar.component(.weekday, from: item.day) + 5) % 7 == index
            }
        }
    }

    func hourLabel(_ hour: Int) -> String {
        var utc = calendar
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = utc.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: hour))!
        let formatter = DateFormatter()
        formatter.calendar = utc
        formatter.timeZone = utc.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate("j")
        return formatter.string(from: date)
    }

    var timedCompletionCount: Int { hours.reduce(0) { $0 + $1.count } }
    var topHour: Bucket? {
        guard historyDays >= 7, timedCompletionCount >= 20 else { return nil }
        return hours.max { $0.count < $1.count }
    }
    var hourIsTied: Bool { hours.filter { $0.count == topHour?.count }.count > 1 }
    var topDay: Bucket? { total > 0 ? bars.max { $0.count < $1.count } : nil }
    var dayIsTied: Bool { bars.filter { $0.count == topDay?.count }.count > 1 }
    var mostRepeated: Habit? { habits.filter { $0.lifetimeCount > 0 }.first }
    var repetitionIsTied: Bool {
        guard let mostRepeated else { return false }
        return habits.filter { $0.lifetimeCount == mostRepeated.lifetimeCount }.count > 1
    }
    var periodHabit: Habit? {
        habits.filter { $0.count > 0 }.sorted {
            $0.count == $1.count ? $0.title < $1.title : $0.count > $1.count
        }.first
    }
    var hasWeekdayPattern: Bool { historyDays >= 28 && total >= 40 && period != .week }
    var topWeekdayIndex: Int? {
        guard hasWeekdayPattern else { return nil }
        return weekdays.indices.max { weekdayAverage($0) < weekdayAverage($1) }
    }
    var weekdayIsTied: Bool {
        guard let topWeekdayIndex else { return false }
        return weekdays.indices.filter { weekdayAverage($0) == weekdayAverage(topWeekdayIndex) }.count > 1
    }
    func weekdayAverage(_ index: Int) -> Double {
        Double(weekdays[index].count) / Double(max(1, weekdayOccurrences[index]))
    }
    var rangeLabel: String {
        guard start < end, let lastDay = calendar.date(byAdding: .day, value: -1, to: end) else {
            return "Through yesterday"
        }
        return "\(format(start, template: "MMM d")) – \(format(lastDay, template: "MMM d, yyyy"))"
    }

    func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = calendar.locale ?? .current
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    init(
        tasks: [DWTask],
        occurrences: [OccurrenceRecord],
        period: StatisticsPeriod,
        now: Date,
        calendar: Calendar
    ) {
        self.period = period
        self.calendar = calendar
        let end = calendar.startOfDay(for: now)
        self.end = end
        let taskIDs = Set(tasks.map(\.id))
        // Occurrence identity is unique in persistence; retain that invariant for
        // injected data too. Skips and unknown/deleted tasks never count as done.
        let unique = Dictionary(occurrences.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        var occurrenceCalendar = Calendar(identifier: .gregorian)
        occurrenceCalendar.timeZone = calendar.timeZone
        let titles = Dictionary(tasks.map { ($0.id, $0.title) }, uniquingKeysWith: { first, _ in first })
        activity = unique.values.compactMap { record -> Activity? in
            guard let title = titles[record.taskID], record.recordedAt <= now,
                  let day = occurrenceCalendar.date(from: record.day.components), day < end else { return nil }
            return Activity(id: record.id, title: title, day: day,
                            isCompleted: record.isCompleted, recordedAt: record.recordedAt)
        }.sorted {
            if $0.day != $1.day { return $0.day > $1.day }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.id.taskID.uuidString < $1.id.taskID.uuidString
        }
        // Attribute a check-in to its scheduled day, including retrospective marks.
        // Keep recordedAt as the real timestamp; never rewrite saved history.
        let completed = unique.values.compactMap { record -> (record: OccurrenceRecord, day: Date)? in
            guard taskIDs.contains(record.taskID), record.isCompleted, record.recordedAt <= now,
                  let day = occurrenceCalendar.date(from: record.day.components)
            else { return nil }
            return (record, calendar.startOfDay(for: day))
        }
        hasAnyCompletions = !completed.isEmpty
        let earliest = (tasks.map(\.createdAt) + completed.map(\.day)).min() ?? end
        let historyStart = min(end, calendar.startOfDay(for: earliest))
        historyDays = max(0, calendar.dateComponents([.day], from: historyStart, to: end).day ?? 0)
        let start = period.days.flatMap { calendar.date(byAdding: .day, value: -$0, to: end) } ?? historyStart
        self.start = start
        let selected = completed.filter { $0.day >= start && $0.day < end }
        total = selected.count
        if let days = period.days, historyDays >= days * 2,
           let previousStart = calendar.date(byAdding: .day, value: -days, to: start) {
            previousTotal = completed.filter { $0.day >= previousStart && $0.day < start }.count
        } else {
            previousTotal = nil
        }

        let dayCounts = Dictionary(grouping: selected, by: \.day).mapValues(\.count)
        let dayCount = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        // Keep the overview readable over long histories, with exact totals in
        // up to seven equal calendar-day groups (four weekly groups for 4 weeks).
        let groupSize = period == .month ? 7 : max(1, Int(ceil(Double(dayCount) / 7)))
        var bins: [Bucket] = []
        var weekdayDays = Array(repeating: 0, count: 7)
        var weekdayTotals = Array(repeating: 0, count: 7)
        var offset = 0
        while offset < dayCount {
            let binStart = calendar.date(byAdding: .day, value: offset, to: start)!
            var count = 0
            let upper = min(dayCount, offset + groupSize)
            for dayOffset in offset..<upper {
                let day = calendar.date(byAdding: .day, value: dayOffset, to: start)!
                let value = dayCounts[day, default: 0]
                count += value
                let weekday = (calendar.component(.weekday, from: day) + 5) % 7
                weekdayDays[weekday] += 1
                weekdayTotals[weekday] += value
            }
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = calendar.locale ?? .current
            formatter.setLocalizedDateFormatFromTemplate(groupSize == 1 ? "EEEEE" : "MMM d")
            let label = formatter.string(from: binStart)
            formatter.setLocalizedDateFormatFromTemplate("EEEE MMM d")
            var fullLabel = formatter.string(from: binStart)
            if groupSize > 1 {
                let binEnd = calendar.date(byAdding: .day, value: upper - 1, to: start)!
                fullLabel += " – \(formatter.string(from: binEnd))"
            }
            bins.append(Bucket(id: offset, label: label, accessibilityLabel: fullLabel, count: count))
            offset = upper
        }
        bars = bins
        weekdayOccurrences = weekdayDays
        let symbols = calendar.weekdaySymbols
        weekdays = (0..<7).map { index in
            let label = symbols[(index + 1) % 7]
            return Bucket(id: index, label: String(label.prefix(3)), accessibilityLabel: label, count: weekdayTotals[index])
        }
        // A retrospective mark tells us the task's day, but not its completion hour.
        let timed = selected.filter { calendar.isDate($0.record.recordedAt, inSameDayAs: $0.day) }
        let hourCounts = Dictionary(grouping: timed, by: { calendar.component(.hour, from: $0.record.recordedAt) }).mapValues(\.count)
        hours = (0..<24).map { hour in
            let formatter = DateFormatter()
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.locale = calendar.locale ?? .current
            formatter.setLocalizedDateFormatFromTemplate("j")
            // Use a fixed ordinary date for labels, so DST cannot erase an hour.
            var utc = calendar
            utc.timeZone = TimeZone(secondsFromGMT: 0)!
            formatter.timeZone = utc.timeZone
            let date = utc.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: hour))!
            let next = utc.date(byAdding: .hour, value: 1, to: date)!
            let label = "\(formatter.string(from: date))–\(formatter.string(from: next))"
            return Bucket(id: hour, label: label, accessibilityLabel: label, count: hourCounts[hour, default: 0])
        }
        // Lifetime facts also stop at yesterday, matching the visible contract.
        let lifetime = Dictionary(grouping: completed.filter { $0.day < end }, by: { $0.record.taskID })
        let inPeriod = Dictionary(grouping: selected, by: { $0.record.taskID })
        habits = tasks.filter { $0.isHabit && !$0.isArchived }.map { task in
            let records = lifetime[task.id, default: []]
            return Habit(id: task.id, title: task.title, count: inPeriod[task.id, default: []].count,
                         lifetimeCount: records.count, firstCompletion: records.map(\.day).min())
        }.sorted {
            if $0.lifetimeCount != $1.lifetimeCount { return $0.lifetimeCount > $1.lifetimeCount }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
