import Domain
import Foundation
import IdentifiedCollections

struct TodayTaskModel: Equatable, Identifiable {
    let id: TaskOccurrenceID
    let title: String
    let time: String
    let recurrence: String?
    let color: TaskColorToken
    let isCompleted: Bool
    let timeWindow: TimeWindow?

    var startMinute: Int? { timeWindow?.start.minutesSinceMidnight }
    var endMinute: Int? {
        timeWindow.map { $0.start.minutesSinceMidnight + $0.durationInMinutes }
    }
}

struct TodayTimelineViewModel: Equatable {
    struct Hour: Equatable, Identifiable {
        let value: Int
        let label: String
        var id: String { TodayTimelineViewModel.hourID(value) }
    }

    struct CurrentTime: Equatable {
        let label: String
        let minute: Int
    }

    let hours: [Hour]
    let tasks: [TodayTaskModel]
    let untimedTasks: [TodayTaskModel]
    let currentTime: CurrentTime?

    var isEmpty: Bool { tasks.isEmpty && untimedTasks.isEmpty }
    var scrollTargetID: String {
        if tasks.isEmpty && !untimedTasks.isEmpty { return "today-untimed" }
        return Self.hourID((currentTime?.minute ?? tasks.first?.startMinute ?? 0) / 60)
    }

    static func hourID(_ hour: Int) -> String { "today-hour-\(hour)" }

    init(
        tasks: [DWTask],
        day: LocalDate?,
        occurrences: IdentifiedArrayOf<OccurrenceRecord>,
        todayLayout: TodayLayout,
        now: Date,
        calendar: Calendar
    ) {
        // Format wall-clock times without applying DST normalization to an abstract
        // task window. Actual local time is extracted with the injected calendar.
        let formatter = DateFormatter()
        formatter.locale = calendar.locale ?? .current
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let hourFormatter = DateFormatter()
        hourFormatter.locale = formatter.locale
        hourFormatter.calendar = formatter.calendar
        hourFormatter.timeZone = formatter.timeZone
        hourFormatter.setLocalizedDateFormatFromTemplate("j")

        var referenceCalendar = Calendar(identifier: .gregorian)
        referenceCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        func referenceDate(_ minute: Int) -> Date {
            referenceCalendar.date(from: DateComponents(
                year: 2001, month: 1, day: 15, hour: (minute / 60) % 24, minute: minute % 60
            ))!
        }
        func timeLabel(_ minute: Int) -> String {
            formatter.string(from: referenceDate(minute))
        }

        let cards: [TodayTaskModel] = tasks.compactMap { task in
            guard let day else { return nil }

            let id = TaskOccurrenceID(taskID: task.id, day: day)
            let window = task.timeWindow
            let start = window?.start.minutesSinceMidnight
            let end = window.map { $0.start.minutesSinceMidnight + $0.durationInMinutes }

            let label: String
            if let start, let end {
                label = "\(timeLabel(start)) – \(timeLabel(end))"
                    + (window?.crossesMidnight == true ? " (+1 day)" : "")
            } else {
                label = "Any time"
            }

            var recurrence: String?
            if todayLayout != .timeline {
                recurrence = task.schedule.recurrence?.pattern.stringValue
            }

            return TodayTaskModel(
                id: id,
                title: task.title,
                time: label,
                recurrence: recurrence,
                color: task.color,
                isCompleted: occurrences[id: id]?.isCompleted == true,
                timeWindow: window
            )
        }
        self.tasks = cards.filter { $0.startMinute != nil }.sorted {
            if $0.startMinute != $1.startMinute { return $0.startMinute! < $1.startMinute! }
            if $0.endMinute != $1.endMinute { return $0.endMinute! < $1.endMinute! }
            return $0.id.taskID.uuidString < $1.id.taskID.uuidString
        }

        self.untimedTasks = cards.filter { $0.startMinute == nil }

        // Keep overnight tasks on their scheduled start day, extending the ruler.
        let lastMinute = max(1440, self.tasks.compactMap(\.endMinute).max() ?? 1440)
        self.hours = (0..<Int(ceil(Double(lastMinute) / 60))).map { hour in
            Hour(
                value: hour,
                label: hourFormatter.string(from: referenceDate(hour * 60)) + (hour >= 24 ? "\n+1d" : "")
            )
        }

        if let day, day == (try? LocalDate(now, in: calendar.timeZone)) {
            let minute = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
            let style = Date.FormatStyle(
                locale: calendar.locale ?? .current,
                calendar: calendar,
                timeZone: calendar.timeZone
            ).hour(.defaultDigits(amPM: .omitted)).minute(.twoDigits)
            self.currentTime = CurrentTime(label: now.formatted(style), minute: minute)
        } else {
            self.currentTime = nil
        }
    }
}

/// Connected overlap groups share a horizontal scroll area. Within a group,
/// reuse a column as soon as the previous card in it ends.
struct TodayTaskWindowGroup: Identifiable {
    struct Placement: Identifiable {
        let task: TodayTaskModel
        let column: Int
        let startMinute: Double
        let endMinute: Double
        var id: TaskOccurrenceID { task.id }
    }

    let placements: [Placement]
    let startMinute: Double
    let endMinute: Double
    let columnCount: Int
    var id: TaskOccurrenceID { placements[0].id }

    static func layout(_ tasks: [TodayTaskModel], minimumMinutes: Double) -> [Self] {
        var groups: [Self] = []
        var placements: [Placement] = []
        var columnEnds: [Double] = []
        var groupStart = 0.0
        var groupEnd = 0.0

        func finishGroup() {
            guard !placements.isEmpty else { return }
            groups.append(Self(
                placements: placements,
                startMinute: groupStart,
                endMinute: groupEnd,
                columnCount: columnEnds.count
            ))
        }

        for task in tasks.sorted(by: {
            if $0.startMinute != $1.startMinute { return ($0.startMinute ?? 0) < ($1.startMinute ?? 0) }
            return $0.id.taskID.uuidString < $1.id.taskID.uuidString
        }) {
            guard let start = task.startMinute, let end = task.endMinute else { continue }

            let visualStart = Double(start)
            let visualEnd = max(Double(end), visualStart + minimumMinutes)
            if !placements.isEmpty && visualStart >= groupEnd {
                finishGroup()
                placements = []
                columnEnds = []
            }
            if placements.isEmpty { groupStart = visualStart; groupEnd = visualEnd }
            let column = columnEnds.firstIndex(where: { $0 <= visualStart }) ?? columnEnds.count
            if column == columnEnds.count { columnEnds.append(visualEnd) }
            else { columnEnds[column] = visualEnd }
            groupEnd = max(groupEnd, visualEnd)
            placements.append(Placement(task: task, column: column,
                                        startMinute: visualStart, endMinute: visualEnd))
        }
        finishGroup()
        return groups
    }
}
