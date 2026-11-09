import Domain
import Foundation

enum DailyZonesFormatting {
    // A fixed UTC day represents wall-clock values without DST or time-zone conversion.
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func date(for time: LocalTime) -> Date {
        Date(timeIntervalSinceReferenceDate: Double(time.minutesSinceMidnight * 60))
    }

    static func time(from date: Date) -> LocalTime {
        // Calendar components are always within LocalTime's valid ranges.
        try! LocalTime(hour: calendar.component(.hour, from: date),
                       minute: calendar.component(.minute, from: date))
    }

    static func interval(_ window: TimeWindow, locale: Locale) -> String {
        let format = Date.FormatStyle(date: .omitted, time: .shortened,
                                     locale: locale, calendar: calendar,
                                     timeZone: calendar.timeZone)
        return "\(date(for: window.start).formatted(format)) – \(date(for: window.end).formatted(format))"
    }

    static func symbol(for zone: DayZone) -> String {
        switch zone.window.start.hour {
        case 5..<11: "sunrise"
        case 11..<18: "sun.max"
        default: "moon"
        }
    }

    /// Returns the uncovered intervals, joining the first and last gap across midnight.
    static func gaps(in zones: [DayZone]) -> [TimeWindow] {
        let ranges = zones.flatMap { zone -> [Range<Int>] in
            let start = zone.window.start.minutesSinceMidnight
            let end = zone.window.end.minutesSinceMidnight
            return zone.window.crossesMidnight ? [start..<1440, 0..<end] : [start..<end]
        }.filter { !$0.isEmpty }.sorted { $0.lowerBound < $1.lowerBound }

        var gaps: [Range<Int>] = []
        var cursor = 0
        for range in ranges {
            if cursor < range.lowerBound { gaps.append(cursor..<range.lowerBound) }
            cursor = max(cursor, range.upperBound)
        }
        if cursor < 1440 { gaps.append(cursor..<1440) }

        if gaps.count > 1, let first = gaps.first, let last = gaps.last,
           first.lowerBound == 0, last.upperBound == 1440 {
            gaps.removeLast()
            gaps.removeFirst()
            gaps.append(last.lowerBound..<(1440 + first.upperBound))
        }

        return gaps.map { range in
            // Bounds above represent a positive interval no longer than one day.
            let start = range.lowerBound % 1440
            let end = range.upperBound % 1440
            return try! TimeWindow(
                start: LocalTime(hour: start / 60, minute: start % 60),
                end: LocalTime(hour: end / 60, minute: end % 60),
                endDay: range.upperBound >= 1440 ? .nextDay : .sameDay
            )
        }
    }
}
