import Dependencies
import Domain

extension DependencyValues {
    public var tasksClient: TasksClient {
        get { self[TasksClient.self] }
        set { self[TasksClient.self] = newValue }
    }
}

public nonisolated struct TasksClient: Sendable {
    public var fetch: @Sendable () async throws -> [DWTask]
}

extension TasksClient: DependencyKey {
    public static var liveValue: TasksClient {
        TasksClient(fetch: {
            try ClientPreviewData.shared.get().tasks
        })
    }
#if DEBUG
    public static var previewValue: TasksClient {
        TasksClient(fetch: {
            try ClientPreviewData.shared.get().tasks
        })
    }
#endif
    public static var testValue: TasksClient {
        TasksClient(fetch: unimplemented("TasksClient.fetch"))
    }
}
