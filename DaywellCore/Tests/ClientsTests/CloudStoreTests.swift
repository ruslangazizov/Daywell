import Domain
import Foundation
@testable import Persistence
import SwiftData
import Testing

@MainActor
struct CloudStoreTests {
    private func task(id: UUID = UUID(), title: String = "Read") throws -> DWTask {
        try DWTask(id: id, title: title, schedule: .once(on: LocalDate(year: 2026, month: 11, day: 3)),
                   createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 100))
    }

    private func container(at url: URL) throws -> ModelContainer {
        let schema = Schema([StoredTask.self, StoredOccurrence.self])
        return try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Daywell", schema: schema, url: url, cloudKitDatabase: .none)
        ])
    }

    @Test func duplicateImportsResolveAndUndoSurvivesLateCopies() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daywell.store")
        let task = try task()
        let record = try OccurrenceRecord(id: .init(taskID: task.id, day: LocalDate(year: 2026, month: 11, day: 3)),
                                          outcome: .completed(at: Date(timeIntervalSince1970: 100)))
        let store = try TaskStore(url: url)
        try store.saveTask(task)
        try store.saveOccurrence(record)
        let otherContainer = try container(at: url)
        let remote = ModelContext(otherContainer)
        remote.insert(StoredTask(id: task.id, payload: try JSONEncoder().encode(task)))
        remote.insert(StoredOccurrence(key: TaskStore.key(record.id), taskID: task.id,
                                       payload: try JSONEncoder().encode(record)))
        try remote.save()
        #expect(try store.fetchTasks() == [task])
        #expect(try store.fetchOccurrences() == [record])
        try store.deleteOccurrence(record.id)
        remote.insert(StoredOccurrence(key: TaskStore.key(record.id), taskID: task.id,
                                       payload: try JSONEncoder().encode(record)))
        try remote.save()
        #expect(try store.fetchOccurrences().isEmpty)
        try store.saveOccurrence(record)
        #expect(try store.fetchOccurrences() == [record])
        try store.deleteTask(task.id)
        remote.insert(StoredTask(id: task.id, payload: try JSONEncoder().encode(task)))
        try remote.save()
        #expect(try store.fetchTasks().isEmpty)
        #expect(try store.fetchOccurrences().isEmpty)
    }

    @Test func importsAreVisibleWithoutReopeningStore() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daywell.store")
        let store = try TaskStore(url: url)
        let original = try task()
        try store.saveTask(original)
        #expect(try store.fetchTasks() == [original])
        let updated = try task(id: original.id, title: "Changed on another device")
        let remoteContainer = try container(at: url)
        let remote = ModelContext(remoteContainer)
        let row = try #require(remote.fetch(FetchDescriptor<StoredTask>()).first)
        row.payload = try JSONEncoder().encode(updated)
        try remote.save()
        #expect(try store.fetchTasks() == [updated])
    }

    @Test func legacyLocalStoreMigratesWithoutLosingTasksOrHistory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Daywell.store")
        let task = try task()
        let record = try OccurrenceRecord(id: .init(taskID: task.id, day: LocalDate(year: 2026, month: 11, day: 3)),
                                          outcome: .completed(at: Date(timeIntervalSince1970: 100)))
        try writeLegacyStore(url: url, task: task, record: record)
        let migrated = try TaskStore(url: url)
        #expect(try migrated.fetchTasks() == [task])
        #expect(try migrated.fetchOccurrences() == [record])
        try migrated.deleteOccurrence(record.id)
        #expect(try migrated.fetchOccurrences().isEmpty)
    }

    private func writeLegacyStore(url: URL, task: DWTask, record: OccurrenceRecord) throws {
        let schema = Schema([Legacy.StoredTask.self, Legacy.StoredOccurrence.self])
        let container = try ModelContainer(for: schema, configurations: [
            ModelConfiguration("Daywell", schema: schema, url: url, cloudKitDatabase: .none)
        ])
        let context = ModelContext(container)
        context.insert(Legacy.StoredTask(id: task.id, payload: try JSONEncoder().encode(task)))
        context.insert(Legacy.StoredOccurrence(key: TaskStore.key(record.id), taskID: task.id,
                                              payload: try JSONEncoder().encode(record)))
        try context.save()
    }
}

// Exact pre-iCloud schema, including its unique constraints and required attributes.
private enum Legacy {
    @Model final class StoredTask {
        @Attribute(.unique) var id: UUID
        var payload: Data
        init(id: UUID, payload: Data) { self.id = id; self.payload = payload }
    }
    @Model final class StoredOccurrence {
        @Attribute(.unique) var key: String
        var taskID: UUID
        var payload: Data
        init(key: String, taskID: UUID, payload: Data) {
            self.key = key; self.taskID = taskID; self.payload = payload
        }
    }
}
