import Foundation

public nonisolated enum TaskColorToken: String, CaseIterable, Codable, Sendable {
    case lilac, mint, peach, blue, rose
}

public nonisolated struct DWTask: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let description: String?
    public let schedule: TaskSchedule
    /// The task owns its time; changing daily zones only changes how it is grouped.
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
        self.timeWindow = timeWindow
        self.color = color
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.archivedAt = archivedAt
    }

    public var isHabit: Bool { schedule.isRepeating }
    public var isArchived: Bool { archivedAt != nil }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case id, title, description, schedule, timeWindow, color, createdAt, updatedAt, archivedAt
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(UUID.self, forKey: .id), title: c.decode(String.self, forKey: .title),
            description: c.decodeIfPresent(String.self, forKey: .description),
            schedule: c.decode(TaskSchedule.self, forKey: .schedule),
            timeWindow: c.decodeIfPresent(TimeWindow.self, forKey: .timeWindow),
            color: c.decode(TaskColorToken.self, forKey: .color),
            createdAt: c.decode(Date.self, forKey: .createdAt),
            updatedAt: c.decode(Date.self, forKey: .updatedAt),
            archivedAt: c.decodeIfPresent(Date.self, forKey: .archivedAt)
        )
    }
}
