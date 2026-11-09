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

    func synchronize(enabled: Bool) async throws {
        revision += 1
        let currentRevision = revision
        let previous = tail
        let work = Task {
            _ = try? await previous?.value
            guard currentRevision == revision else { return }
            try await reconcile(enabled: enabled)
        }
        tail = work
        defer { if currentRevision == revision { tail = nil } }
        try await work.value
    }

    private func reconcile(enabled: Bool) async throws {
        let snapshot: ReminderStoreSnapshot
        if enabled, await center.isAuthorized() {
            snapshot = try await load()
        } else {
            snapshot = ReminderStoreSnapshot(tasks: [], occurrences: [])
        }
        let zone = timeZone()
        let requests = TaskReminderPlanner.requests(tasks: snapshot.tasks, occurrences: snapshot.occurrences,
                                                    now: now(), timeZone: zone)
        let desiredIDs = Set(requests.map(\.id))
        let pendingIDs = await center.pendingIdentifiers()
        await center.removePending(pendingIDs.filter {
            $0.hasPrefix("task-reminder/") && !desiredIDs.contains($0)
        })
        let recorded = Set(snapshot.occurrences.map(\.id))
        let activeTasks = Dictionary(uniqueKeysWithValues: snapshot.tasks.filter {
            !$0.isArchived && $0.reminder != nil
        }.map { ($0.id, $0) })
        let delivered = await center.deliveredReminders()
        await center.removeDelivered(delivered.filter { item in
            guard item.identifier.hasPrefix("task-reminder/") else { return false }
            guard let id = item.occurrenceID, let task = activeTasks[id.taskID] else { return true }
            return !task.schedule.occurs(on: id.day) || recorded.contains(id)
        }.map(\.identifier))
        for request in requests {
            try await center.add(request)
        }
    }
}
