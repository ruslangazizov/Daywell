import Foundation

public nonisolated enum Accessibility {
    public static let taskDetailsTitle = "taskDetails.title"
    public static let taskDetailsStatus = "taskDetails.status"
    public static let taskDetailsEdit = "taskDetails.edit"
    public static let taskDetailsComplete = "taskDetails.complete"
    public static let taskDetailsHistory = "taskDetails.history"
    public static let taskDetailsMoreStats = "taskDetails.moreStats"
    public static let taskDetailsError = "taskDetails.error"
    public static let taskEditorTitle = "taskEditor.title"
    public static let taskEditorNotes = "taskEditor.notes"
    public static let taskEditorTimeWindow = "taskEditor.timeWindow"
    public static let taskEditorRepeat = "taskEditor.repeat"
    public static let taskEditorError = "taskEditor.error"
    public static let taskEditorCancel = "taskEditor.cancel"
    public static let taskEditorSave = "taskEditor.save"
    public static let taskEditorAdd = "taskEditor.add"
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
