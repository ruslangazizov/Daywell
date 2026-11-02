import Dependencies
import Domain
import Persistence
import IdentifiedCollections

extension DependencyValues {
    public var occurrencesClient: OccurrencesClient {
        get { self[OccurrencesClient.self] }
        set { self[OccurrencesClient.self] = newValue }
    }
}

public nonisolated struct OccurrencesClient: Sendable {
    public var fetch: @Sendable () async throws -> IdentifiedArrayOf<OccurrenceRecord>
    /// Inserts or replaces a record with the same identity.
    public var save: @Sendable (OccurrenceRecord) async throws -> Void
    public var delete: @Sendable (TaskOccurrenceID) async throws -> Void

    public static func swiftData(_ store: TaskStore) -> Self {
        storage { store }
    }

    private static func storage(_ store: @escaping @MainActor @Sendable () throws -> TaskStore) -> Self {
        Self(
            fetch: { try await IdentifiedArray(uniqueElements: store().fetchOccurrences()) },
            save: { try await store().saveOccurrence($0) },
            delete: { try await store().deleteOccurrence($0) }
        )
    }
}

extension OccurrencesClient: DependencyKey {
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
            fetch: unimplemented("OccurrencesClient.fetch"),
            save: unimplemented("OccurrencesClient.save"),
            delete: unimplemented("OccurrencesClient.delete")
        )
    }
}
