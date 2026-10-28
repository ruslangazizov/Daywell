import Foundation

public nonisolated enum Weekday: Int, CaseIterable, Codable, Sendable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    /// Monday = 0. Scheduling is independent of the UI's preferred first weekday.
    public var mondayBasedIndex: Int { (rawValue + 5) % 7 }
    public var isWeekend: Bool { self == .saturday || self == .sunday }
}

public nonisolated struct Recurrence: Hashable, Codable, Sendable {
    public nonisolated enum Pattern: Hashable, Codable, Sendable {
        case daily(every: Int)
        case weekly(every: Int, weekdays: Set<Weekday>)
        case monthly(every: Int, day: Int)

        public var interval: Int {
            switch self {
            case let .daily(every), let .weekly(every, _), let .monthly(every, _): every
            }
        }

        /// Enum cases can be constructed freely; Recurrence validates the pattern
        /// before accepting it, including when decoding a saved schedule.
        public func validate() throws {
            guard interval > 0 else { throw ModelValidationError.invalidRepeatInterval }
            switch self {
            case .daily: break
            case let .weekly(_, weekdays):
                guard !weekdays.isEmpty else { throw ModelValidationError.emptyWeekdays }
            case let .monthly(_, day):
                guard (1...31).contains(day) else { throw ModelValidationError.invalidDayOfMonth }
            }
        }
    }

    public let startsOn: LocalDate
    /// Inclusive; nil means no scheduled ending.
    public let endsOn: LocalDate?
    public let pattern: Pattern

    public init(startsOn: LocalDate, endsOn: LocalDate? = nil, pattern: Pattern) throws {
        try pattern.validate()
        if let endsOn, endsOn < startsOn { throw ModelValidationError.invalidDateRange }
        self.startsOn = startsOn
        self.endsOn = endsOn
        self.pattern = pattern
    }

    public var hasEndDate: Bool { endsOn != nil }

    /// At most one occurrence per calendar day. Monthly dates missing from a
    /// month (e.g. February 31) are skipped, never moved into another month.
    public func occurs(on day: LocalDate) -> Bool {
        guard day >= startsOn, endsOn.map({ day <= $0 }) ?? true else { return false }
        switch pattern {
        case let .daily(every):
            return day.daysSince(startsOn).isMultiple(of: every)
        case let .weekly(every, weekdays):
            let weekOffset = (day.daysSince(startsOn) + startsOn.weekday.mondayBasedIndex) / 7
            return weekOffset.isMultiple(of: every) && weekdays.contains(day.weekday)
        case let .monthly(every, targetDay):
            let months = (day.year - startsOn.year) * 12 + day.month - startsOn.month
            return months.isMultiple(of: every) && day.day == targetDay
        }
    }

    private enum CodingKeys: String, CodingKey { case startsOn, endsOn, pattern }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(startsOn: c.decode(LocalDate.self, forKey: .startsOn),
                      endsOn: c.decodeIfPresent(LocalDate.self, forKey: .endsOn),
                      pattern: c.decode(Pattern.self, forKey: .pattern))
    }
}

public nonisolated enum TaskSchedule: Hashable, Codable, Sendable {
    case once(on: LocalDate)
    case repeating(Recurrence)

    public var isRepeating: Bool {
        if case .repeating = self { return true }
        return false
    }

    public var startsOn: LocalDate {
        switch self {
        case let .once(day): day
        case let .repeating(recurrence): recurrence.startsOn
        }
    }

    public var endsOn: LocalDate? {
        switch self {
        case let .once(day): day
        case let .repeating(recurrence): recurrence.endsOn
        }
    }

    public func occurs(on day: LocalDate) -> Bool {
        switch self {
        case let .once(scheduledDay): scheduledDay == day
        case let .repeating(recurrence): recurrence.occurs(on: day)
        }
    }
}
