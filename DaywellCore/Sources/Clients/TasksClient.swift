import Dependencies
import Domain
import Persistence

extension DependencyValues {
    public var tasksClient: TasksClient {
        get { self[TasksClient.self] }
        set { self[TasksClient.self] = newValue }
    }
}

public nonisolated struct TasksClient: Sendable {
    public var fetch: @Sendable () async throws -> [DWTask]
    /// Inserts or replaces a record with the same identity.
    public var save: @Sendable (DWTask) async throws -> Void
    public var delete: @Sendable (DWTask.ID) async throws -> Void

    public static func swiftData(_ store: TaskStore) -> Self {
        storage { store }
    }

    private static func storage(_ store: @escaping @MainActor @Sendable () throws -> TaskStore) -> Self {
        Self(
            fetch: { try await store().fetchTasks() },
            save: { try await store().saveTask($0) },
            delete: { try await store().deleteTask($0) }
        )
    }
}

extension TasksClient: DependencyKey {
    public static var liveValue: Self {
        storage { try ClientStore.live() }
    }

    #if DEBUG
    public static var previewValue: Self {
        storage { try ClientStore.preview.get() }
    }
    #endif

    public static var testValue: Self {
        Self(
            fetch: unimplemented("TasksClient.fetch"),
            save: unimplemented("TasksClient.save"),
            delete: unimplemented("TasksClient.delete")
        )
    }
}
