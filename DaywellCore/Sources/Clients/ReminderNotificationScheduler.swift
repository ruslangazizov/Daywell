import Domain
import Foundation
import Persistence

struct ReminderStoreSnapshot: Sendable {
    var tasks: [DWTask]
    var occurrences: [OccurrenceRecord]
}

/// Queue whole reconciliations: actor isolation alone cannot prevent interleaving
/// across notification-center awaits. Each run reads storage after its predecessor.
actor ReminderNotificationScheduler {
    static let live = ReminderNotificationScheduler(center: SystemReminderNotificationCenter()) {
        try await MainActor.run {
            let store = try ClientStore.live()
            return ReminderStoreSnapshot(
                tasks: try store.fetchTasks(),
                occurrences: try store.fetchOccurrences()
            )
        }
    }

    private let center: any ReminderNotificationCenter
    private let load: @Sendable () async throws -> ReminderStoreSnapshot
    private let now: @Sendable () -> Date
    private let timeZone: @Sendable () -> TimeZone
    private var tail: Task<Void, Error>?
    private var revision = 0

    init(
        center: any ReminderNotificationCenter,
        now: @escaping @Sendable () -> Date = { .now },
        timeZone: @escaping @Sendable () -> TimeZone = { .current },
        load: @escaping @Sendable () async throws -> ReminderStoreSnapshot
    ) {
        self.center = center
        self.load = load
        self.now = now
        self.timeZone = timeZone
    }

    func synchronize(
        enabled: Bool,
        badgeEnabled: Bool = false,
        layout: TodayLayout = .timeline,
        zones: [DayZone] = DayZone.defaults
    ) async throws {
        revision += 1
        let currentRevision = revision
        let previous = tail
        let work = Task {
            _ = try? await previous?.value
            guard currentRevision == revision else { return }
            try await reconcile(enabled: enabled, badgeEnabled: badgeEnabled, layout: layout, zones: zones)
        }
        tail = work
        defer { if currentRevision == revision { tail = nil } }
        try await work.value
    }

    // MARK: - Private

    private func reconcile(enabled: Bool, badgeEnabled: Bool, layout: TodayLayout, zones: [DayZone]) async throws {
        let remindersAuthorized = enabled ? await center.isAuthorized() : false
        let badgeAuthorized = badgeEnabled ? await center.isBadgeAuthorized() : false
        // Opting out must clear the badge even if loading reminder data later fails.
        if !badgeAuthorized {
            await center.removePending(await center.pendingIdentifiers().filter { $0.hasPrefix("app-icon-badge/") })
            try await center.setBadgeCount(0)
        }
        let snapshot = remindersAuthorized || badgeAuthorized
            ? try await load() : ReminderStoreSnapshot(tasks: [], occurrences: [])
        let zone = timeZone()
        let instant = now()
        let requests = remindersAuthorized
            ? TaskReminderPlanner.requests(tasks: snapshot.tasks, occurrences: snapshot.occurrences,
                                           now: instant, timeZone: zone) : []
        let badgeUpdates = badgeAuthorized
            ? AppIconBadge.updates(tasks: snapshot.tasks, occurrences: snapshot.occurrences,
                                  layout: layout, zones: zones, now: instant, timeZone: zone) : []
        if badgeAuthorized {
            try await center.setBadgeCount(AppIconBadge.count(
                tasks: snapshot.tasks, occurrences: snapshot.occurrences, layout: layout,
                zones: zones, now: instant, timeZone: zone
            ))
        }
        let pendingIDs = await center.pendingIdentifiers()
        let unrelatedCount = pendingIDs.filter { !Self.owns($0) }.count
        let capacity = max(0, 64 - unrelatedCount)
        let queue = (requests.map { ($0.id, $0.fireDate) } + badgeUpdates.map { ($0.id, $0.fireDate) })
            .sorted { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0 < $1.0 }
        let desiredIDs = Set(queue.prefix(capacity).map(\.0))
        await center.removePending(pendingIDs.filter { Self.owns($0) && !desiredIDs.contains($0) })
        let recorded = Set(snapshot.occurrences.map(\.id))
        let activeTasks = Dictionary(uniqueKeysWithValues: snapshot.tasks.filter {
            !$0.isArchived && $0.reminder != nil
        }.map { ($0.id, $0) })
        let delivered = await center.deliveredReminders()
        await center.removeDelivered(delivered.filter { item in
            if item.identifier.hasPrefix("app-icon-badge/") { return true }
            guard item.identifier.hasPrefix("task-reminder/") else { return false }
            guard remindersAuthorized, let id = item.occurrenceID, let task = activeTasks[id.taskID] else { return true }
            return !task.schedule.occurs(on: id.day) || recorded.contains(id)
        }.map(\.identifier))
        for request in requests where desiredIDs.contains(request.id) {
            try await center.add(request)
        }
        for update in badgeUpdates where desiredIDs.contains(update.id) {
            try await center.addBadge(update)
        }
    }

    private static func owns(_ identifier: String) -> Bool {
        identifier.hasPrefix("task-reminder/") || identifier.hasPrefix("app-icon-badge/")
    }
}
