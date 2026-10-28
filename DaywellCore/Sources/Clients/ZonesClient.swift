import Dependencies
import Domain

extension DependencyValues {
    public var zonesClient: ZonesClient {
        get { self[ZonesClient.self] }
        set { self[ZonesClient.self] = newValue }
    }
}

public nonisolated struct ZonesClient: Sendable {
    public var fetch: @Sendable () async throws -> [DayZone]
}

extension ZonesClient: DependencyKey {
    public static var liveValue: ZonesClient {
        ZonesClient(fetch: {
            try ClientPreviewData.shared.get().zones
        })
    }
#if DEBUG
    public static var previewValue: ZonesClient {
        ZonesClient(fetch: {
            try ClientPreviewData.shared.get().zones
        })
    }
#endif
    public static var testValue: ZonesClient {
        ZonesClient(fetch: unimplemented("ZonesClient.fetch"))
    }
}
