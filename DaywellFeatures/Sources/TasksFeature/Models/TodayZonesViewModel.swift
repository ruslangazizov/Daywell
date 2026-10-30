import Domain
import Foundation

struct TodayZonesViewModel {
    typealias Section = TodayListViewModel.Section

    let sections: [Section]
    let currentMinute: Int?

    init(timeline: TodayTimelineViewModel, zones: [DayZone]) {
        sections = TodayListViewModel(timeline: timeline, zones: zones).zones
        currentMinute = timeline.currentTime?.minute
    }

    /// A nil selection follows the clock. Browsing stays put until the user taps Now.
    func section(browsing id: String?) -> Section? {
        if let id, let section = sections.first(where: { $0.id == id }) { return section }
        if currentMinute == nil || sections.allSatisfy({ $0.window == nil }) { return sections.first }
        return sections.first(where: \.isCurrent)
    }

    func neighbor(of section: Section?, direction: ZoneDirection) -> Section? {
        if let section, let index = sections.firstIndex(where: { $0.id == section.id }) {
            let nextIndex = index + direction.rawValue
            return sections.indices.contains(nextIndex) ? sections[nextIndex] : nil
        }
        guard let currentMinute else { return nil }
        switch direction {
        case .previous:
            return sections.last { ($0.window?.start.minutesSinceMidnight ?? Int.max) < currentMinute }
        case .next:
            return sections.first { ($0.window?.start.minutesSinceMidnight ?? Int.max) > currentMinute }
        }
    }

    var gapDescription: String {
        guard let first = sections.first(where: { $0.window != nil }), let currentMinute else {
            return "Your tasks will appear here."
        }
        let upcoming = sections.first { ($0.window?.start.minutesSinceMidnight ?? -1) > currentMinute }
        let next = upcoming ?? first
        guard let time = next.window?.start else { return "Enjoy a little breathing room." }
        let when = upcoming == nil ? "tomorrow at" : "at"
        return "\(next.title) starts \(when) \(Self.timeLabel(time))."
    }

    static func intervalLabel(_ window: TimeWindow) -> String {
        "\(timeLabel(window.start)) – \(timeLabel(window.end))\(window.crossesMidnight ? " (+1 day)" : "")"
    }

    private static func timeLabel(_ time: LocalTime) -> String {
        // Format wall-clock values without applying the device's daylight-saving transitions.
        let utc = TimeZone(secondsFromGMT: 0)!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let date = calendar.date(from: DateComponents(year: 2001, month: 1, day: 15,
                                                      hour: time.hour, minute: time.minute))!
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: utc))
    }
}

nonisolated enum ZoneDirection: Int {
    case previous = -1
    case next = 1
}

/// Only the distance beyond an edge counts; scrolling within a long list never advances a zone.
nonisolated enum TodayZonePull {
    static let threshold: Double = 64

    static func distance(
        offset: Double,
        contentHeight: Double,
        containerHeight: Double,
        topInset: Double,
        bottomInset: Double
    ) -> Double {
        let top = -topInset
        let bottom = max(top, contentHeight - containerHeight + bottomInset)
        if offset < top { return offset - top }
        if offset > bottom { return offset - bottom }
        return 0
    }

    static func destination(distance: Double) -> ZoneDirection? {
        if distance <= -threshold { return .previous }
        if distance >= threshold { return .next }
        return nil
    }
}
