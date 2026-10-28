public nonisolated enum Accessibility {
    public static let addZone = "settings.zones.add"
    public static let restoreZones = "settings.zones.restore"
    public static let zoneName = "settings.zones.name"
    public static let zoneValidation = "settings.zones.validation"
    public static func zone(_ id: String) -> String { "settings.zones.\(id)" }
    public static let taskWindow = "settings.taskWindow"
    public static let customDuration = "settings.customDuration"
    public static let customDurationSummary = "customDuration.summary"
}
