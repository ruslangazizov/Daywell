import Foundation
import Persistence

/// Lazy initialization keeps storage failures on the clients' throwing API.
/// Both clients must resolve the same store so task deletion also removes outcomes.
@MainActor
enum ClientStore {
    private static var liveStore: TaskStore?

    static func live() throws -> TaskStore {
        if let liveStore { return liveStore }
        let store: TaskStore
        if ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "true" {
            store = try TaskStore(inMemory: true)
        } else {
            #if DEBUG && targetEnvironment(simulator)
            store = try simulatorStore()
            #else
            store = try TaskStore()
            #endif
        }
        liveStore = store
        return store
    }

    #if DEBUG && targetEnvironment(simulator)
    static func simulatorStore() throws -> TaskStore {
        // Keep development data across launches without opening the production store.
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("Daywell-Simulator", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let store = try TaskStore(url: directory.appendingPathComponent("Daywell.store"))
        let seedMarker = directory.appendingPathComponent("preview-data-seeded")
        // Pre-populate store only if it doesn't already exist
        if !FileManager.default.fileExists(atPath: seedMarker.path) {
            let data = try ClientPreviewData.shared.get()
            // Preserve existing edits and allow an interrupted import to resume.
            let taskIDs = Set(try store.fetchTasks().map(\.id))
            for task in data.tasks where !taskIDs.contains(task.id) {
                try store.saveTask(task)
            }
            let occurrenceIDs = Set(try store.fetchOccurrences().map(\.id))
            for occurrence in data.occurrences where !occurrenceIDs.contains(occurrence.id) {
                try store.saveOccurrence(occurrence)
            }
            // A separate marker prevents deleted examples from returning on relaunch.
            try Data().write(to: seedMarker, options: .atomic)
        }
        return store
    }
    #endif

    #if DEBUG
    static let preview: Result<TaskStore, Error> = Result { try TaskStore(inMemory: true) }
    #endif
}
