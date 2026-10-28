import Foundation

/// Stable while the time of a task changes. For overnight windows, day is the
/// scheduled START day, even when completion happens after midnight.
public nonisolated struct TaskOccurrenceID: Hashable, Codable, Sendable {
    public let taskID: DWTask.ID
    public let day: LocalDate

    public init(taskID: DWTask.ID, day: LocalDate) {
        self.taskID = taskID
        self.day = day
    }
}

/// Store only recorded outcomes. Absence of a record means no outcome yet,
/// not necessarily overdue. Schedule versions and snapshots are intentionally omitted.
public nonisolated struct OccurrenceRecord: Identifiable, Hashable, Codable, Sendable {
    public nonisolated enum Outcome: Hashable, Codable, Sendable {
        case completed(at: Date)
        case skipped(at: Date)

        public var recordedAt: Date {
            switch self {
            case let .completed(date), let .skipped(date): date
            }
        }
    }

    public let id: TaskOccurrenceID
    public let outcome: Outcome

    public init(id: TaskOccurrenceID, outcome: Outcome) throws {
        try validateTimestamp(outcome.recordedAt)
        self.id = id
        self.outcome = outcome
    }

    // MARK: - Helpers

    public var taskID: DWTask.ID { id.taskID }
    public var day: LocalDate { id.day }
    public var recordedAt: Date { outcome.recordedAt }
    public var completedAt: Date? {
        if case let .completed(date) = outcome { return date }
        return nil
    }
    public var skippedAt: Date? {
        if case let .skipped(date) = outcome { return date }
        return nil
    }
    public var isCompleted: Bool { completedAt != nil }
    public var isSkipped: Bool { skippedAt != nil }

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case id, outcome }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(TaskOccurrenceID.self, forKey: .id),
                      outcome: c.decode(Outcome.self, forKey: .outcome))
    }
}
