import Domain
import Foundation
import IdentifiedCollections

/// A live projection of the same task and outcomes used by Today. The route
/// retains its start day even if midnight passes while details are open.
struct TaskDetailsModel {
    struct HistoryDay: Identifiable {
        let id: LocalDate
        let date: Date
        let outcome: OccurrenceRecord.Outcome?
        let isSelected: Bool

        var status: String {
            switch outcome {
            case .completed: "Completed"
            case .skipped: "Skipped"
            case nil: "No recorded outcome"
            }
        }
        var symbol: String {
            switch outcome {
            case .completed: "checkmark"
            case .skipped: "minus"
            case nil: "circle.dotted"
            }
        }
    }

    let task: DWTask
    let id: TaskOccurrenceID
    let records: IdentifiedArrayOf<OccurrenceRecord>
    let now: Date
    let calendar: Calendar

    var isCompleted: Bool { records[id: id]?.isCompleted == true }
    var canComplete: Bool { !task.isArchived && task.schedule.occurs(on: id.day) }
    var repeatLabel: String { task.schedule.recurrence?.pattern.stringValue ?? "Does not repeat" }
    var dayLabel: String { dateLabel(id.day) }
    var reminderLabel: String? {
        switch task.reminder {
        case nil:
            return nil
        case .atStart:
            return "At start"
        case .beforeStart(let lead):
            return lead == .oneHour ? "1 hour before start" : "\(lead.rawValue) minutes before start"
        case .atTime(let time):
            // Format the saved wall-clock time without daylight-saving adjustments.
            var referenceCalendar = Calendar(identifier: .gregorian)
            referenceCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
            let date = referenceCalendar.date(from: DateComponents(
                year: 2001, month: 1, day: 15, hour: time.hour, minute: time.minute
            ))!
            let formatter = DateFormatter()
            formatter.locale = calendar.locale ?? .current
            formatter.calendar = referenceCalendar
            formatter.timeZone = referenceCalendar.timeZone
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return "At \(formatter.string(from: date))"
        }
    }
    var status: String {
        if isCompleted {
            return id.day == (try? LocalDate(now, in: calendar.timeZone))
                ? "Completed today" : "Completed for \(dayLabel)"
        }
        if !canComplete { return "Not scheduled for this day" }
        if records[id: id]?.isSkipped == true { return "Skipped for this day" }
        return "Ready when you are"
    }
    var timeLabel: String {
        let timeline = TodayTimelineViewModel(
            tasks: [task],
            day: id.day,
            occurrences: records,
            todayLayout: .agenda,
            now: now,
            calendar: calendar
        )
        return (timeline.tasks.first ?? timeline.untimedTasks.first)?.time ?? "Any time"
    }

    // History shows recorded facts only. Current schedules cannot establish
    // historical misses or streaks without schedule snapshots.
    var history: [HistoryDay] {
        let anchor = date(id.day)
        return (-6...0).compactMap { offset in
            guard let date = gregorian.date(byAdding: .day, value: offset, to: anchor),
                  let day = try? LocalDate(date, in: calendar.timeZone) else { return nil }
            return HistoryDay(id: day, date: date,
                              outcome: records[id: TaskOccurrenceID(taskID: task.id, day: day)]?.outcome,
                              isSelected: day == id.day)
        }
    }
    func dateLabel(_ day: LocalDate) -> String {
        date(day).formatted(
            Date.FormatStyle(
                locale: calendar.locale ?? .current,
                calendar: calendar, timeZone: calendar.timeZone
            ).month(.abbreviated).day().year()
        )
    }
    private var gregorian: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = calendar.timeZone
        return value
    }
    private func date(_ day: LocalDate) -> Date {
        var components = day.components
        components.hour = 12
        return gregorian.date(from: components)!
    }
}
