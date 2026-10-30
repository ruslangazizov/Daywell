import Domain
import Foundation

struct TodayListViewModel {
    struct Section: Identifiable {
        let id: String
        let title: String
        let tasks: [TodayTaskModel]
        var isCurrent = false
        var window: TimeWindow?
    }

    let agenda: [Section]
    let zones: [Section]
    let agendaScrollTargetID: String
    let zonesScrollTargetID: String

    static let topID = "today-list-top"

    static func taskID(_ task: TodayTaskModel) -> String {
        "today-list-task-\(task.id.taskID)"
    }

    init(timeline: TodayTimelineViewModel, zones: [DayZone]) {
        agenda = [
            Section(id: "today-scheduled", title: "Scheduled", tasks: timeline.tasks),
            Section(id: "today-anytime", title: "Any time", tasks: timeline.untimedTasks)
        ].filter { !$0.tasks.isEmpty }

        let cards = timeline.tasks + timeline.untimedTasks
        let currentTime = timeline.currentTime.flatMap {
            try? LocalTime(hour: $0.minute / 60, minute: $0.minute % 60)
        }
        var sections = zones.sorted {
            if $0.window.start != $1.window.start { return $0.window.start < $1.window.start }
            return $0.id.uuidString < $1.id.uuidString
        }.map { zone in
            Section(
                id: "today-zone-\(zone.id)",
                title: zone.name,
                tasks: cards.filter { $0.timeWindow?.overlaps(zone.window) == true },
                isCurrent: currentTime.map { zone.isActive(at: $0) } ?? false,
                window: zone.window
            )
        }
        // Cards may appear in several zones, sharing the same occurrence and completion state.
        // No zone contains only cards with no matches at all, including untimed cards.
        let matchedIDs = Set(sections.flatMap(\.tasks).map(\.id))
        let unmatched = cards.filter { !matchedIDs.contains($0.id) }
        if !unmatched.isEmpty {
            sections.append(Section(id: "today-no-zone", title: "No zone", tasks: unmatched))
        }
        self.zones = sections

        let agendaTarget: TodayTaskModel?
        if let minute = timeline.currentTime?.minute {
            agendaTarget = timeline.tasks.first { ($0.endMinute ?? 0) > minute }
                ?? timeline.untimedTasks.first ?? timeline.tasks.last
        } else {
            agendaTarget = cards.first
        }
        agendaScrollTargetID = agendaTarget.map(Self.taskID) ?? Self.topID
        zonesScrollTargetID = cards.isEmpty ? Self.topID : (sections.first(where: \.isCurrent)?.id
            ?? sections.first(where: { !$0.tasks.isEmpty })?.id ?? Self.topID)
    }
}
