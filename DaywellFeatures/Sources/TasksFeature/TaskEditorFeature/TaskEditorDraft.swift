import Domain
import Foundation
import Persistence

nonisolated struct TaskEditorDraft: Equatable, Sendable {
    enum RepeatOption: String, CaseIterable, Sendable {
        case never = "Does not repeat"
        case daily = "Every day"
        case weekdays = "Weekdays"
        case weekends = "Weekends"
        case weekly = "Every week"
        case monthly = "Every month"
        case custom = "Custom"
    }

    enum Frequency: String, CaseIterable, Sendable {
        case daily = "Days", weekly = "Weeks", monthly = "Months"
    }

    var title = ""
    var notes = ""
    var hasTimeWindow = true
    var start: LocalTime
    var end: LocalTime
    var endsNextDay: Bool
    var repeatOption: RepeatOption = .never
    var scheduledDate: Date
    var hasEndDate = false
    var endDate: Date
    var frequency: Frequency = .weekly
    var interval = 1
    var weekdays: Set<Weekday>
    var monthDay: Int
    var color: TaskColorToken = .lilac

    init(selectedDate: Date, now: Date, calendar: Calendar, duration: TaskDuration) {
        scheduledDate = selectedDate
        endDate = selectedDate
        // Use local wall-clock minutes; a default duration may cross midnight.
        let minutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let endMinutes = minutes + min(max(duration.minutes, 1), 1440)
        start = try! LocalTime(hour: minutes / 60, minute: minutes % 60)
        end = try! LocalTime(hour: (endMinutes % 1440) / 60, minute: endMinutes % 60)
        endsNextDay = endMinutes >= 1440
        let day = try? LocalDate(selectedDate, in: calendar.timeZone)
        weekdays = [day?.weekday ?? .monday]
        monthDay = day?.day ?? 1
    }

    init(task: DWTask, calendar: Calendar) {
        // Domain dates are Gregorian, regardless of the user's display calendar.
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        func date(_ day: LocalDate) -> Date {
            var components = day.components
            components.hour = 12
            return gregorian.date(from: components)!
        }
        self.init(selectedDate: date(task.schedule.startsOn), now: task.createdAt,
                  calendar: calendar, duration: .defaultValue)
        title = task.title
        notes = task.description ?? ""
        color = task.color
        hasTimeWindow = task.timeWindow != nil
        if let window = task.timeWindow {
            start = window.start
            end = window.end
            endsNextDay = window.crossesMidnight
        }
        if let recurrence = task.schedule.recurrence {
            // Preserve the exact rule when only the name, color or window changes.
            repeatOption = .custom
            interval = recurrence.pattern.interval
            hasEndDate = recurrence.endsOn != nil
            endDate = date(recurrence.endsOn ?? recurrence.startsOn)
            switch recurrence.pattern {
            case .daily:
                frequency = .daily
            case .weekly(_, let days):
                frequency = .weekly
                weekdays = days
            case .monthly(_, let day):
                frequency = .monthly
                monthDay = day
            }
        }
    }

    var isHabit: Bool { repeatOption != .never }

    func schedule(in calendar: Calendar) throws -> TaskSchedule {
        let day = try LocalDate(scheduledDate, in: calendar.timeZone)
        guard isHabit else { return .once(on: day) }
        let pattern: Recurrence.Pattern
        switch repeatOption {
        case .never: return .once(on: day)
        case .daily: pattern = .daily(every: 1)
        case .weekdays: pattern = .weekly(every: 1, weekdays: [.monday, .tuesday, .wednesday, .thursday, .friday])
        case .weekends: pattern = .weekly(every: 1, weekdays: [.saturday, .sunday])
        case .weekly: pattern = .weekly(every: 1, weekdays: [day.weekday])
        case .monthly: pattern = .monthly(every: 1, day: day.day)
        case .custom:
            switch frequency {
            case .daily: pattern = .daily(every: interval)
            case .weekly: pattern = .weekly(every: interval, weekdays: weekdays)
            case .monthly: pattern = .monthly(every: interval, day: monthDay)
            }
        }
        return try .repeating(Recurrence(
            startsOn: day,
            endsOn: hasEndDate ? LocalDate(endDate, in: calendar.timeZone) : nil,
            pattern: pattern
        ))
    }

    func timeWindow() throws -> TimeWindow? {
        guard hasTimeWindow else { return nil }
        return try TimeWindow(start: start, end: end, endDay: endsNextDay ? .nextDay : .sameDay)
    }

    func task(id: UUID, now: Date, calendar: Calendar, original: DWTask? = nil) throws -> DWTask {
        try DWTask(id: id, title: title, description: notes, schedule: schedule(in: calendar),
                   timeWindow: timeWindow(), color: color, createdAt: original?.createdAt ?? now,
                   updatedAt: max(now, original?.updatedAt ?? now), archivedAt: original?.archivedAt)
    }

    func validationMessage(calendar: Calendar) -> String? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Add a name for this task."
        }
        do {
            _ = try timeWindow()
            _ = try schedule(in: calendar)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
