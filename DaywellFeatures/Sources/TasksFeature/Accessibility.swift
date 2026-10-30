import Foundation

public nonisolated enum Accessibility {
    public static let todayWeekPager = "today.weekPager"
    public static let todayAgenda = "today.agenda"
    public static let todayZones = "today.zones"
    public static let todayNow = "today.now"
    public static let todayZoneTitle = "today.zone.title"
    public static let todayZoneStatus = "today.zone.status"
    public static let todayPreviousZone = "today.zone.previous"
    public static let todayNextZone = "today.zone.next"
    public static let todayTimeline = "today.timeline"
    public static let todayOverlappingTasks = "today.overlappingTasks"

    public static func todayTask(_ taskID: UUID) -> String {
        "today.task.\(taskID)"
    }
}
