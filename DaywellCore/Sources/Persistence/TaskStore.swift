import Domain
import Foundation
import SwiftData

/// Owns the context shared by both clients. Only domain values leave this boundary.
@MainActor
public final class TaskStore {
    private let context: ModelContext

    public init(inMemory: Bool = false, url: URL? = nil) throws {
        let schema = Schema([StoredTask.self, StoredOccurrence.self])
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("Daywell", schema: schema, url: url, cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(
                "Daywell", schema: schema, isStoredInMemoryOnly: inMemory,
                groupContainer: .none, cloudKitDatabase: .none
            )
        }
        let container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    public func fetchTasks() throws -> [DWTask] {
        try context.fetch(FetchDescriptor<StoredTask>()).map {
            try JSONDecoder().decode(DWTask.self, from: $0.payload)
        }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    /// Inserts or replaces the task with this ID, preserving its occurrence history.
    public func saveTask(_ task: DWTask) throws {
        let payload = try JSONEncoder().encode(task)
        try write {
            if let stored = try storedTask(task.id) {
                stored.payload = payload
            } else {
                context.insert(StoredTask(id: task.id, payload: payload))
            }
        }
    }

    /// Permanently deletes a task and its recorded outcomes in one save.
    public func deleteTask(_ id: DWTask.ID) throws {
        try write {
            let occurrences = try context.fetch(FetchDescriptor<StoredOccurrence>(
                predicate: #Predicate { $0.taskID == id }
            ))
            for occurrence in occurrences { context.delete(occurrence) }
            if let task = try storedTask(id) { context.delete(task) }
        }
    }

    public func fetchOccurrences() throws -> [OccurrenceRecord] {
        try context.fetch(FetchDescriptor<StoredOccurrence>()).map {
            try JSONDecoder().decode(OccurrenceRecord.self, from: $0.payload)
        }.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.taskID.uuidString < $1.taskID.uuidString
        }
    }

    /// One outcome per task and calendar day; saving again replaces that outcome.
    public func saveOccurrence(_ occurrence: OccurrenceRecord) throws {
        let payload = try JSONEncoder().encode(occurrence)
        try write {
            guard try storedTask(occurrence.taskID) != nil else {
                throw TaskStoreError.taskNotFound(occurrence.taskID)
            }
            if let stored = try storedOccurrence(occurrence.id) {
                stored.payload = payload
            } else {
                context.insert(StoredOccurrence(
                    key: Self.key(occurrence.id), taskID: occurrence.taskID, payload: payload
                ))
            }
        }
    }

    /// Removing the record restores the unrecorded state (it does not mean skipped).
    public func deleteOccurrence(_ id: TaskOccurrenceID) throws {
        try write {
            if let occurrence = try storedOccurrence(id) { context.delete(occurrence) }
        }
    }

    private func storedTask(_ id: UUID) throws -> StoredTask? {
        var query = FetchDescriptor<StoredTask>(predicate: #Predicate { $0.id == id })
        query.fetchLimit = 1
        return try context.fetch(query).first
    }

    private func storedOccurrence(_ id: TaskOccurrenceID) throws -> StoredOccurrence? {
        let key = Self.key(id)
        var query = FetchDescriptor<StoredOccurrence>(predicate: #Predicate { $0.key == key })
        query.fetchLimit = 1
        return try context.fetch(query).first
    }

    private static func key(_ id: TaskOccurrenceID) -> String {
        "\(id.taskID.uuidString)/\(id.day.year)/\(id.day.month)/\(id.day.day)"
    }

    private func write(_ mutation: () throws -> Void) throws {
        do {
            try mutation()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

public nonisolated enum TaskStoreError: LocalizedError, Equatable {
    case taskNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .taskNotFound: "The task no longer exists."
        }
    }
}

// Keep validated domain models independent of SwiftData. Codable payloads preserve
// schedules and overnight windows; separate keys support unique upserts and deletion.
@Model
final class StoredTask {
    @Attribute(.unique) var id: UUID
    var payload: Data

    init(id: UUID, payload: Data) {
        self.id = id
        self.payload = payload
    }
}

@Model
final class StoredOccurrence {
    @Attribute(.unique) var key: String
    var taskID: UUID
    var payload: Data

    init(key: String, taskID: UUID, payload: Data) {
        self.key = key
        self.taskID = taskID
        self.payload = payload
    }
}
