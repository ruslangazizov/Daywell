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
}
