@testable import Clients
import Domain
import Foundation
import Persistence
import Testing

@MainActor
struct SwiftDataClientsTests {
    private let day = try! LocalDate(year: 2026, month: 10, day: 30)
    private let timestamp = Date(timeIntervalSince1970: 1_793_361_600)

    private func task(id: UUID = UUID(), title: String = "Read", archived: Bool = false) throws -> DWTask {
        try DWTask(
            id: id, title: title, description: "A chapter",
            schedule: .repeating(Recurrence(startsOn: day, pattern: .weekly(every: 2, weekdays: [.friday]))),
            timeWindow: TimeWindow(start: LocalTime(hour: 23, minute: 30),
                                   end: LocalTime(hour: 1, minute: 0), endDay: .nextDay),
            color: .mint, createdAt: timestamp, updatedAt: timestamp,
            archivedAt: archived ? timestamp : nil
        )
    }

    @Test func startsEmptyAndStoresAreIsolated() async throws {
        let first = try TaskStore(inMemory: true)
        let second = try TaskStore(inMemory: true)
        #expect(try await TasksClient.swiftData(first).fetch().isEmpty)
        #expect(try await OccurrencesClient.swiftData(first).fetch().isEmpty)
        try await TasksClient.swiftData(first).save(task())
        #expect(try await TasksClient.swiftData(second).fetch().isEmpty)
    }

    #if DEBUG && targetEnvironment(simulator)
    @Test func simulatorSeedsOnceAndPreservesEditsAndDeletionsOnReopening() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let samples = try ClientPreviewData.shared.get()
        let store = try ClientStore.simulatorStore(in: directory)
        #expect(Set(try store.fetchTasks()) == Set(samples.tasks))
        #expect(Set(try store.fetchOccurrences()) == Set(samples.occurrences))

        let edited = try task(id: samples.tasks[0].id, title: "My edited example")
        try store.saveTask(edited)
        let reopened = try ClientStore.simulatorStore(in: directory)
        #expect(try reopened.fetchTasks().first { $0.id == edited.id } == edited)
        for task in try reopened.fetchTasks() {
            try reopened.deleteTask(task.id)
        }
        let empty = try ClientStore.simulatorStore(in: directory)
        #expect(try empty.fetchTasks().isEmpty)
        #expect(try empty.fetchOccurrences().isEmpty)
    }

    @Test func simulatorImportPreservesExistingRecords() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let samples = try ClientPreviewData.shared.get()
        let existing = try task(id: samples.tasks[0].id, title: "Existing task")
        let custom = try task(title: "Custom task")
        do {
            let store = try TaskStore(url: directory.appendingPathComponent("Daywell.store"))
            try store.saveTask(existing)
            try store.saveTask(custom)
        }
        let seeded = try ClientStore.simulatorStore(in: directory)
        let tasks = try seeded.fetchTasks()
        #expect(tasks.count == samples.tasks.count + 1)
        #expect(tasks.contains(existing))
        #expect(tasks.contains(custom))
    }
    #endif

    @Test func tasksAndOutcomesSurviveReopeningIncludingUpdatesAndDeletes() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("test.store")
        let original = try task()
        let updated = try task(id: original.id, title: "Updated", archived: true)
        let id = TaskOccurrenceID(taskID: original.id, day: day)
        let completed = try OccurrenceRecord(id: id, outcome: .completed(at: timestamp))
        let skipped = try OccurrenceRecord(id: id, outcome: .skipped(at: timestamp.addingTimeInterval(10)))

        do {
            let store = try TaskStore(url: url)
            try await TasksClient.swiftData(store).save(original)
            try await OccurrencesClient.swiftData(store).save(completed)
        }
        do {
            let store = try TaskStore(url: url)
            let tasks = TasksClient.swiftData(store)
            let outcomes = OccurrencesClient.swiftData(store)
            #expect(try await tasks.fetch() == [original])
            #expect(try await outcomes.fetch() == [completed])
            try await tasks.save(updated)
            try await outcomes.save(skipped)
        }
        do {
            let store = try TaskStore(url: url)
            #expect(try await TasksClient.swiftData(store).fetch() == [updated])
            #expect(try await OccurrencesClient.swiftData(store).fetch() == [skipped])
            try await OccurrencesClient.swiftData(store).delete(id)
        }
        do {
            let store = try TaskStore(url: url)
            #expect(try await OccurrencesClient.swiftData(store).fetch().isEmpty)
            try await TasksClient.swiftData(store).delete(original.id)
        }
        let reopened = try TaskStore(url: url)
        #expect(try await TasksClient.swiftData(reopened).fetch().isEmpty)
    }

    @Test func occurrenceIdentityIncludesTaskAndDayAndUndoIsIdempotent() async throws {
        let store = try TaskStore(inMemory: true)
        let tasks = TasksClient.swiftData(store)
        let outcomes = OccurrencesClient.swiftData(store)
        let first = try task()
        let second = try task()
        try await tasks.save(first)
        try await tasks.save(second)
        let tomorrow = try LocalDate(year: 2026, month: 10, day: 31)
        let records = try [
            TaskOccurrenceID(taskID: first.id, day: day),
            TaskOccurrenceID(taskID: first.id, day: tomorrow),
            TaskOccurrenceID(taskID: second.id, day: day)
        ].map { try OccurrenceRecord(id: $0, outcome: .completed(at: timestamp)) }
        for record in records {
            try await outcomes.save(record)
            try await outcomes.save(record)
        }
        #expect(try await outcomes.fetch().count == 3)
        try await outcomes.delete(records[0].id)
        try await outcomes.delete(records[0].id)
        #expect(Set(try await outcomes.fetch()) == Set(records.dropFirst()))
    }

    @Test func deletingTaskDeletesOnlyItsHistoryAndRejectsOrphanOutcomes() async throws {
        let store = try TaskStore(inMemory: true)
        let tasks = TasksClient.swiftData(store)
        let outcomes = OccurrencesClient.swiftData(store)
        let first = try task()
        let second = try task()
        try await tasks.save(first)
        try await tasks.save(second)
        let firstRecord = try OccurrenceRecord(id: TaskOccurrenceID(taskID: first.id, day: day),
                                               outcome: .completed(at: timestamp))
        let secondRecord = try OccurrenceRecord(id: TaskOccurrenceID(taskID: second.id, day: day),
                                                outcome: .skipped(at: timestamp))
        try await outcomes.save(firstRecord)
        try await outcomes.save(secondRecord)
        try await tasks.delete(first.id)
        try await tasks.delete(first.id)
        #expect(try await tasks.fetch() == [second])
        #expect(try await outcomes.fetch() == [secondRecord])
        await #expect(throws: TaskStoreError.taskNotFound(first.id)) {
            try await outcomes.save(firstRecord)
        }
        #expect(try await outcomes.fetch() == [secondRecord])
        // The store remains usable after a failed mutation.
        try await tasks.save(first)
        try await outcomes.save(firstRecord)
        #expect(try await outcomes.fetch().count == 2)
    }
}
