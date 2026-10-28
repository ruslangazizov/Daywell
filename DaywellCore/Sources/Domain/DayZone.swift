import Foundation

public nonisolated struct DayZone: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let window: TimeWindow

    public init(id: UUID = UUID(), name: String, window: TimeWindow) throws {
        self.id = id
        self.name = try validatedName(name)
        self.window = window
    }

    public func isActive(at time: LocalTime) -> Bool { window.contains(time) }

    /// Stable identities keep assignments intact when the standard zones are restored.
    public static let defaults: [Self] = {
        // These literal names and non-overlapping windows satisfy the model invariants.
        try! [
            Self(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 101)),
                 name: "Morning", window: TimeWindow(
                    start: LocalTime(hour: 7, minute: 0), end: LocalTime(hour: 11, minute: 0))),
            Self(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 102)),
                 name: "Day", window: TimeWindow(
                    start: LocalTime(hour: 11, minute: 0), end: LocalTime(hour: 18, minute: 0))),
            Self(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 103)),
                 name: "Evening", window: TimeWindow(
                    start: LocalTime(hour: 18, minute: 0), end: LocalTime(hour: 23, minute: 0)))
        ]
    }()

    /// Cross-entity validation must be called when saving a collection of zones.
    /// Gaps and an empty collection are allowed; duplicate IDs and overlaps are not.
    public static func validate(_ zones: [DayZone]) throws {
        var seen = Set<UUID>()
        for (index, zone) in zones.enumerated() {
            guard seen.insert(zone.id).inserted else {
                throw ModelValidationError.duplicateZoneID(zone.id)
            }
            for other in zones.prefix(index) where zone.window.overlaps(other.window) {
                throw ModelValidationError.overlappingZones(other.id, zone.id)
            }
        }
    }

    private enum CodingKeys: String, CodingKey { case id, name, window }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(UUID.self, forKey: .id),
                      name: c.decode(String.self, forKey: .name),
                      window: c.decode(TimeWindow.self, forKey: .window))
    }
}
