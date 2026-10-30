import Foundation

public nonisolated enum ModelValidationError: Error, Equatable, Sendable {
    case invalidDate
    case invalidTime
    case invalidTimeWindow
    case invalidRepeatInterval
    case emptyWeekdays
    case invalidDayOfMonth
    case invalidDateRange
    case emptyName
    case invalidTimestamp
    case invalidTimestampOrder
    case duplicateZoneID(UUID)
    case overlappingZones(UUID, UUID)
}

extension ModelValidationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidDate: "Enter a valid Gregorian date between years 1 and 9999."
        case .invalidTime: "Hours must be 0–23 and minutes must be 0–59."
        case .invalidTimeWindow: "Choose a positive time window of at most 24 hours."
        case .invalidRepeatInterval: "The repeat interval must be greater than zero."
        case .emptyWeekdays: "Choose at least one weekday."
        case .invalidDayOfMonth: "The day of the month must be between 1 and 31."
        case .invalidDateRange: "The end date cannot precede the start date."
        case .emptyName: "Enter a nonempty name."
        case .invalidTimestamp: "The timestamp must be finite."
        case .invalidTimestampOrder: "Creation, archive and update timestamps are out of order."
        case .duplicateZoneID: "Each zone must have a unique identifier."
        case .overlappingZones: "Zones cannot overlap."
        }
    }
}
