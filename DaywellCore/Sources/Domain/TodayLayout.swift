public enum TodayLayout: String, CaseIterable, Sendable {
    case timeline, agenda, zones

    public nonisolated static let defaultValue: Self = .timeline

    public var title: String { rawValue.capitalized }

    public var icon: String {
        switch self {
        case .timeline: "calendar"
        case .agenda: "chart.bar.xaxis"
        case .zones: "rectangle.3.offgrid"
        }
    }
}
