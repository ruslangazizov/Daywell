import IdentifiedCollections
import Dependencies
import Domain

extension DependencyValues {
    public var occurrencesClient: OccurrencesClient {
        get { self[OccurrencesClient.self] }
        set { self[OccurrencesClient.self] = newValue }
    }
}

public nonisolated struct OccurrencesClient: Sendable {
    public var fetch: @Sendable () async throws -> IdentifiedArrayOf<OccurrenceRecord>
}

extension OccurrencesClient: DependencyKey {
    public static var liveValue: OccurrencesClient {
        OccurrencesClient(fetch: {
            try ClientPreviewData.shared.get().occurrences
        })
    }
#if DEBUG
    public static var previewValue: OccurrencesClient {
        OccurrencesClient(fetch: {
            try ClientPreviewData.shared.get().occurrences
        })
    }
#endif
    public static var testValue: OccurrencesClient {
        OccurrencesClient(fetch: unimplemented("OccurrencesClient.fetch"))
    }
}
