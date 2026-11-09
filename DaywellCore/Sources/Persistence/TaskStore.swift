import Domain
import Foundation
import SwiftData

@MainActor
public final class TaskStore {
    public nonisolated static let cloudContainerIdentifier = "iCloud.com.ruslangazizov.Daywell"
    private let container: ModelContainer

    /// Cloud sync is explicit so temporary stores, previews and tests stay local.
    public init(inMemory: Bool = false, url: URL? = nil, cloudSync: Bool = false) throws {
        let schema = Schema([StoredTask.self, StoredOccurrence.self])
        let cloud: ModelConfiguration.CloudKitDatabase = cloudSync && !inMemory
            ? .private(Self.cloudContainerIdentifier) : .none
        let configuration: ModelConfiguration
        if let url {
            configuration = ModelConfiguration("Daywell", schema: schema, url: url, cloudKitDatabase: cloud)
        } else {
            configuration = ModelConfiguration(
                "Daywell", schema: schema, isStoredInMemoryOnly: inMemory,
                groupContainer: .none, cloudKitDatabase: cloud
            )
        }
        container = try ModelContainer(for: schema, configurations: [configuration])
    }

    // A fresh context sees CloudKit imports instead of retaining cached model instances.
    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    public func fetchTasks() throws -> [DWTask] {
        try taskWinners(in: makeContext()).values.filter { !$0.isDeleted }.map {
            try JSONDecoder().decode(DWTask.self, from: $0.payload)
        }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    public func saveTask(_ task: DWTask) throws {
        let payload = try Self.encode(task)
        try write { context in
            let id = task.id
            let rows = try context.fetch(FetchDescriptor<StoredTask>(predicate: #Predicate { $0.id == id }))
            let now = Date.now
            if rows.isEmpty { context.insert(StoredTask(id: id, payload: payload, modifiedAt: now)) }
            for row in rows {
                row.payload = payload
                row.modifiedAt = now
                row.isDeleted = false
            }
        }
    }

    /// Tombstones prevent a late-arriving duplicate from resurrecting a deleted task.
    public func deleteTask(_ id: DWTask.ID) throws {
        try write { context in
            let rows = try context.fetch(FetchDescriptor<StoredTask>(predicate: #Predicate { $0.id == id }))
            let now = Date.now
            if rows.isEmpty {
                let row = StoredTask(id: id, payload: Data(), modifiedAt: now)
                row.isDeleted = true
                context.insert(row)
            }
            for row in rows {
                row.isDeleted = true
                row.modifiedAt = now
                row.payload = Data()
            }
            let occurrences = try context.fetch(FetchDescriptor<StoredOccurrence>(predicate: #Predicate { $0.taskID == id }))
            for row in occurrences {
                row.isDeleted = true
                row.modifiedAt = now
                row.payload = Data()
            }
        }
    }

    public func fetchOccurrences() throws -> [OccurrenceRecord] {
        let context = makeContext()
        let taskIDs = Set(try taskWinners(in: context).values.filter { !$0.isDeleted }.map(\.id))
        let rows = try context.fetch(FetchDescriptor<StoredOccurrence>())
        let winners = Dictionary(grouping: rows, by: \.key).values.compactMap { $0.max(by: Self.isOlder) }
        return try winners.filter { !$0.isDeleted && taskIDs.contains($0.taskID) }.map {
            try JSONDecoder().decode(OccurrenceRecord.self, from: $0.payload)
        }.sorted {
            if $0.day != $1.day { return $0.day < $1.day }
            return $0.taskID.uuidString < $1.taskID.uuidString
        }
    }

    public func saveOccurrence(_ occurrence: OccurrenceRecord) throws {
        let payload = try Self.encode(occurrence)
        try write { context in
            guard let task = try taskWinners(in: context)[occurrence.taskID], !task.isDeleted else {
                throw TaskStoreError.taskNotFound(occurrence.taskID)
            }
            let key = Self.key(occurrence.id)
            let rows = try context.fetch(FetchDescriptor<StoredOccurrence>(predicate: #Predicate { $0.key == key }))
            let now = Date.now
            if rows.isEmpty {
                context.insert(StoredOccurrence(key: key, taskID: occurrence.taskID, payload: payload, modifiedAt: now))
            }
            for row in rows {
                row.payload = payload
                row.modifiedAt = now
                row.isDeleted = false
            }
        }
    }

    public func deleteOccurrence(_ id: TaskOccurrenceID) throws {
        try write { context in
            let key = Self.key(id)
            let rows = try context.fetch(FetchDescriptor<StoredOccurrence>(predicate: #Predicate { $0.key == key }))
            let now = Date.now
            if rows.isEmpty {
                let row = StoredOccurrence(key: key, taskID: id.taskID, payload: Data(), modifiedAt: now)
                row.isDeleted = true
                context.insert(row)
            }
            for row in rows {
                row.isDeleted = true
                row.modifiedAt = now
                row.payload = Data()
            }
        }
    }

    private func taskWinners(in context: ModelContext) throws -> [UUID: StoredTask] {
        let rows = try context.fetch(FetchDescriptor<StoredTask>())
        return Dictionary(grouping: rows, by: \.id).compactMapValues { $0.max(by: Self.isOlder) }
    }

    // CloudKit does not support unique constraints. Resolve logical duplicates identically
    // on every device, including equal timestamps; retain rows to avoid delete/update races.
    private static func isOlder<T: SyncRecord>(_ lhs: T, _ rhs: T) -> Bool {
        if lhs.modifiedAt != rhs.modifiedAt { return lhs.modifiedAt < rhs.modifiedAt }
        if lhs.isDeleted != rhs.isDeleted { return !lhs.isDeleted }
        return lhs.payload.lexicographicallyPrecedes(rhs.payload)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(value)
    }

    static func key(_ id: TaskOccurrenceID) -> String {
        "\(id.taskID.uuidString)/\(id.day.year)/\(id.day.month)/\(id.day.day)"
    }

    private func write(_ mutation: (ModelContext) throws -> Void) throws {
        let context = makeContext()
        do {
            try mutation(context)
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}

public nonisolated enum TaskStoreError: LocalizedError, Equatable {
    case taskNotFound(UUID)
    public var errorDescription: String? { "The task no longer exists." }
}

private protocol SyncRecord {
    var payload: Data { get }
    var modifiedAt: Date { get }
    var isDeleted: Bool { get }
}

@Model
final class StoredTask: SyncRecord {
    var id: UUID = UUID()
    var payload: Data = Data()
    var modifiedAt: Date = Date.distantPast
    var isDeleted: Bool = false

    init(id: UUID, payload: Data, modifiedAt: Date = .distantPast) {
        self.id = id
        self.payload = payload
        self.modifiedAt = modifiedAt
    }
}

@Model
final class StoredOccurrence: SyncRecord {
    var key: String = ""
    var taskID: UUID = UUID()
    var payload: Data = Data()
    var modifiedAt: Date = Date.distantPast
    var isDeleted: Bool = false

    init(key: String, taskID: UUID, payload: Data, modifiedAt: Date = .distantPast) {
        self.key = key
        self.taskID = taskID
        self.payload = payload
        self.modifiedAt = modifiedAt
    }
}
