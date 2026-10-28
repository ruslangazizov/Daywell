import Foundation

public enum FirstDayOfWeek: String, CaseIterable, Identifiable, Sendable {
    case system
    case monday
    case tuesday
    case wednesday
    case thursday
    case friday
    case saturday
    case sunday

    public static let defaultValue: Self = .system

    public var id: Self { self }
    public var title: String { rawValue.capitalized }
}

public nonisolated struct TaskDuration: Codable, Hashable, Identifiable, Sendable {
    public let minutes: Int

    public init(minutes: Int) {
        self.minutes = minutes
    }

    public var id: Int { minutes }

    public static let defaultValue = Self(minutes: 30)

    public static let defaults: [Self] = [15, 30, 45, 60, 90, 120].map {
        Self(minutes: $0)
    }

    public var title: String {
        guard minutes >= 60 else { return "\(minutes) min" }

        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        let hoursTitle = "\(hours) \(hours == 1 ? "hour" : "hours")"

        switch remainingMinutes {
        case 0: return hoursTitle
        case 30: return "\(hours).5 hours"
        default: return "\(hoursTitle) \(remainingMinutes) min"
        }
    }
}

/// Presentation state only. A future client will supply observed iCloud status.
public enum ICloudSyncStatus: String, CaseIterable, Identifiable, Sendable {
    case notChecked
    case checking
    case available
    case syncing
    case signedOut
    case waitingForConnection
    case needsAttention
    case noConfirmedSync

    public var id: Self { self }

    public var title: String {
        switch self {
        case .notChecked: "iCloud sync"
        case .checking: "Checking status…"
        case .available: "iCloud sync"
        case .syncing: "Syncing…"
        case .signedOut: "Sign in to iCloud"
        case .waitingForConnection: "Waiting for connection"
        case .needsAttention: "Sync needs attention"
        case .noConfirmedSync: "No confirmed sync yet"
        }
    }

    public var description: String {
        switch self {
        case .notChecked:
            "Your tasks, habits and completion history sync automatically across your devices. iCloud availability has not been checked yet."
        case .checking:
            "Checking iCloud availability. Your saved tasks stay available."
        case .available:
            "Your tasks, habits and completion history sync automatically across your devices."
        case .syncing:
            "Changes are being sent or received."
        case .signedOut:
            "Sign in from your iPhone settings to sync tasks across your devices."
        case .waitingForConnection:
            "Your changes are saved on this device. Sync will resume automatically."
        case .needsAttention:
            "iCloud could not finish the last sync. Your changes are saved on this device."
        case .noConfirmedSync:
            "iCloud is available. No completed exchange has been observed yet."
        }
    }

    public var isBusy: Bool {
        self == .checking || self == .syncing
    }
}
