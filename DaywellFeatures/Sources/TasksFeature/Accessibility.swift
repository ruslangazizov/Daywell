import Foundation

public nonisolated enum Accessibility {
    public static let todayWeekPager = "today.weekPager"
    public static let todayTimeline = "today.timeline"
    public static let todayOverlappingTasks = "today.overlappingTasks"

    public static func todayTask(_ taskID: UUID) -> String {
        "today.task.\(taskID)"
    }
}
