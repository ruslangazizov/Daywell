import Foundation

/// A Gregorian calendar day, independent of the device's calendar and time zone.
public nonisolated struct LocalDate: Hashable, Codable, Sendable, Comparable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) throws {
        guard (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day) else {
            throw ModelValidationError.invalidDate
        }
        let components = DateComponents(year: year, month: month, day: day)
        let calendar = gregorianUTC
        guard let date = calendar.date(from: components),
              calendar.dateComponents([.year, .month, .day], from: date) == components else {
            throw ModelValidationError.invalidDate
        }
        self.year = year
        self.month = month
        self.day = day
    }

    public init(_ date: Date, in timeZone: TimeZone) throws {
        try validateTimestamp(date)
        var calendar = gregorianUTC
        calendar.timeZone = timeZone
        let values = calendar.dateComponents([.era, .year, .month, .day], from: date)
        guard values.era == 1, let year = values.year,
              let month = values.month, let day = values.day else {
            throw ModelValidationError.invalidDate
        }
        try self.init(year: year, month: month, day: day)
    }

    public var components: DateComponents {
        DateComponents(year: year, month: month, day: day)
    }

    public var weekday: Weekday {
        // Calendar returns 1...7; construction and decoding validate the date.
        Weekday(rawValue: gregorianUTC.component(.weekday, from: referenceDate))!
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Calendar-day distance, not an elapsed number of 86,400-second periods.
    public func daysSince(_ other: LocalDate) -> Int {
        gregorianUTC.dateComponents([.day], from: other.referenceDate, to: referenceDate).day!
    }

    // This UTC date is only an arithmetic anchor, not a scheduled execution time.
    private var referenceDate: Date {
        // Guaranteed by the validated initializer, including during decoding.
        gregorianUTC.date(from: components)!
    }

    private enum CodingKeys: String, CodingKey { case year, month, day }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(year: c.decode(Int.self, forKey: .year),
                      month: c.decode(Int.self, forKey: .month),
                      day: c.decode(Int.self, forKey: .day))
    }
}

public nonisolated struct LocalTime: Hashable, Codable, Sendable, Comparable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            throw ModelValidationError.invalidTime
        }
        self.hour = hour
        self.minute = minute
    }

    public var components: DateComponents { DateComponents(hour: hour, minute: minute) }
    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    private enum CodingKeys: String, CodingKey { case hour, minute }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(hour: c.decode(Int.self, forKey: .hour),
                      minute: c.decode(Int.self, forKey: .minute))
    }
}

public nonisolated struct TimeWindow: Hashable, Codable, Sendable {
    public enum EndDay: String, Codable, Sendable { case sameDay, nextDay }

    public let start: LocalTime
    public let end: LocalTime
    public let endDay: EndDay

    public init(start: LocalTime, end: LocalTime, endDay: EndDay = .sameDay) throws {
        switch endDay {
        case .sameDay:
            guard start < end else { throw ModelValidationError.invalidTimeWindow }
        case .nextDay:
            guard end <= start else { throw ModelValidationError.invalidTimeWindow }
        }
        self.start = start
        self.end = end
        self.endDay = endDay
    }

    public var crossesMidnight: Bool { endDay == .nextDay }
    /// Wall-clock minutes. Actual elapsed duration can differ on a DST transition.
    public var durationInMinutes: Int {
        end.minutesSinceMidnight - start.minutesSinceMidnight + (crossesMidnight ? 1440 : 0)
    }
    public var isFullDay: Bool { durationInMinutes == 1440 }

    /// Includes the start and excludes the end; adjacent zones do not overlap.
    public func contains(_ time: LocalTime) -> Bool {
        minuteRanges.contains { $0.contains(time.minutesSinceMidnight) }
    }

    public func overlaps(_ other: TimeWindow) -> Bool {
        minuteRanges.contains { a in
            other.minuteRanges.contains { b in
                max(a.lowerBound, b.lowerBound) < min(a.upperBound, b.upperBound)
            }
        }
    }

    private var minuteRanges: [Range<Int>] {
        if crossesMidnight {
            return [start.minutesSinceMidnight..<1440, 0..<end.minutesSinceMidnight]
                .filter { !$0.isEmpty }
        }
        return [start.minutesSinceMidnight..<end.minutesSinceMidnight]
    }

    private enum CodingKeys: String, CodingKey { case start, end, endDay }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(start: c.decode(LocalTime.self, forKey: .start),
                      end: c.decode(LocalTime.self, forKey: .end),
                      endDay: c.decode(EndDay.self, forKey: .endDay))
    }
}

private nonisolated var gregorianUTC: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    return calendar
}
