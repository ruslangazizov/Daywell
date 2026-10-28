import Foundation

public nonisolated enum TaskColorToken: String, CaseIterable, Codable, Sendable {
    case lilac, mint, peach, blue, rose
}

public nonisolated struct DWTask: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let schedule: TaskSchedule
    public let zoneID: DayZone.ID?
    public let timeWindow: TimeWindow?
    public let color: TaskColorToken
    public let createdAt: Date
    public let updatedAt: Date
    public let archivedAt: Date?

    public init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        schedule: TaskSchedule,
        zoneID: DayZone.ID? = nil,
        timeWindow: TimeWindow? = nil,
        color: TaskColorToken = .lilac,
        createdAt: Date = .now,
        updatedAt: Date? = nil,
        archivedAt: Date? = nil
    ) throws {
        let updatedAt = updatedAt ?? createdAt
        try validateTimestamp(createdAt)
        try validateTimestamp(updatedAt)
        guard updatedAt >= createdAt else { throw ModelValidationError.invalidTimestampOrder }
        if let archivedAt {
            try validateTimestamp(archivedAt)
            guard archivedAt >= createdAt, archivedAt <= updatedAt else {
                throw ModelValidationError.invalidTimestampOrder
            }
        }
        self.id = id
        self.title = try validatedName(title)
        self.description = description.flatMap {
            let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        self.schedule = schedule
        self.zoneID = zoneID
        self.timeWindow = timeWindow
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    public var isHabit: Bool { schedule.isRepeating }
    public var isArchived: Bool { archivedAt != nil }
    public var hasAssignedZone: Bool { zoneID != nil }
    public var hasCustomTimeWindow: Bool { timeWindow != nil }

    /// Referential integrity is checked separately, once the zone collection is available.
    public func validateZone(in zones: [DayZone]) throws {
        if let zoneID, !zones.contains(where: { $0.id == zoneID }) {
            throw ModelValidationError.unknownZone(zoneID)
        }
    }

    /// An explicit task window takes precedence; otherwise use the assigned zone.
    /// An unassigned task without a custom window has no time restriction.
    public func effectiveTimeWindow(in zones: [DayZone]) throws -> TimeWindow? {
        try validateZone(in: zones)
        return timeWindow ?? zones.first(where: { $0.id == zoneID })?.window
    }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, title, description, schedule, zoneID, timeWindow, color, createdAt, updatedAt, archivedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(UUID.self, forKey: .id), title: c.decode(String.self, forKey: .title),
            description: c.decodeIfPresent(String.self, forKey: .description),
            schedule: c.decode(TaskSchedule.self, forKey: .schedule),
            zoneID: c.decodeIfPresent(UUID.self, forKey: .zoneID),
            timeWindow: c.decodeIfPresent(TimeWindow.self, forKey: .timeWindow),
            color: c.decode(TaskColorToken.self, forKey: .color),
            createdAt: c.decode(Date.self, forKey: .createdAt),
            updatedAt: c.decode(Date.self, forKey: .updatedAt),
            archivedAt: c.decodeIfPresent(Date.self, forKey: .archivedAt)
        )
    }
}
