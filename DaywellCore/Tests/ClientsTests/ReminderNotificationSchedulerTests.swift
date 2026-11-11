import Domain
import Foundation
import Testing
@testable import Clients

struct ReminderNotificationSchedulerTests {
    private let now = ISO8601DateFormatter().date(from: "2026-11-09T00:00:00Z")!
    private let zone = TimeZone(secondsFromGMT: 0)!

    @Test func badgeWorksWithoutRemindersAndDisableClearsIt() async throws {
        let center = RecordingNotificationCenter()
        let day = try LocalDate(year: 2026, month: 11, day: 9)
        let task = try DWTask(title: "Read", schedule: .once(on: day))
        let scheduler = ReminderNotificationScheduler(center: center, now: { now }, timeZone: { zone }) {
            ReminderStoreSnapshot(tasks: [task], occurrences: [])
        }
        try await scheduler.synchronize(enabled: false, badgeEnabled: true)
        #expect(await center.badgeCount == 1)
        #expect(await center.badgeUpdates.values.first?.count == 0)
        #expect(await center.requests.isEmpty)
        try await scheduler.synchronize(enabled: false)
        #expect(await center.badgeCount == 0)
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func badgeFollowsPersistedCompletionAndUndo() async throws {
        let center = RecordingNotificationCenter()
        let day = try LocalDate(year: 2026, month: 11, day: 9)
        let task = try DWTask(title: "Read", schedule: .once(on: day))
        let source = ReminderTestStore(tasks: [task])
        let scheduler = ReminderNotificationScheduler(center: center, now: { now }, timeZone: { zone }) {
            await source.snapshot
        }
        try await scheduler.synchronize(enabled: false, badgeEnabled: true)
        #expect(await center.badgeCount == 1)
        await source.complete(try OccurrenceRecord(id: .init(taskID: task.id, day: day), outcome: .completed(at: now)))
        try await scheduler.synchronize(enabled: false, badgeEnabled: true)
        #expect(await center.badgeCount == 0)
        #expect(await center.badgeUpdates.isEmpty)
        await source.undo()
        try await scheduler.synchronize(enabled: false, badgeEnabled: true)
        #expect(await center.badgeCount == 1)
    }

    @Test func badgeStorageFailurePreservesCountAndOptOutStillClears() async throws {
        let center = RecordingNotificationCenter()
        await center.setBadgeCount(3)
        await center.seed(pending: ["app-icon-badge/old", "unrelated"], delivered: [])
        let scheduler = ReminderNotificationScheduler(center: center) { throw TestError.failed }
        await #expect(throws: TestError.self) { try await scheduler.synchronize(enabled: false, badgeEnabled: true) }
        #expect(await center.badgeCount == 3)
        #expect(await center.pendingIdentifiers() == ["app-icon-badge/old", "unrelated"])
        try await scheduler.synchronize(enabled: false)
        #expect(await center.badgeCount == 0)
        #expect(await center.pendingIdentifiers() == ["unrelated"])
    }

    @Test func combinedQueueStaysWithinSystemCapacity() async throws {
        let center = RecordingNotificationCenter()
        let day = try LocalDate(year: 2026, month: 11, day: 9)
        let tasks = try (0..<80).map { index in
            try DWTask(title: "Task \(index)", schedule: .once(on: day),
                       reminder: .atTime(LocalTime(hour: 12, minute: 0)))
        }
        let scheduler = ReminderNotificationScheduler(center: center, now: { now }, timeZone: { zone }) {
            ReminderStoreSnapshot(tasks: tasks, occurrences: [])
        }
        try await scheduler.synchronize(enabled: true, badgeEnabled: true)
        #expect(await center.pendingIdentifiers().count == 64)
        #expect(await center.badgeCount == 80)
    }

    @Test func reconciliationReplacesEditedRequestsAndRemovesCompletedDeletedAndDelivered() async throws {
        let day = try LocalDate(year: 2026, month: 11, day: 10)
        let task = try DWTask(title: "New title", schedule: .once(on: day), reminder: .atTime(LocalTime(hour: 11, minute: 0)))
        let id = TaskOccurrenceID(taskID: task.id, day: day)
        let center = RecordingNotificationCenter()
        let source = ReminderTestStore(tasks: [task])
        let scheduler = ReminderNotificationScheduler(center: center, now: { now }, timeZone: { zone }) {
            await source.snapshot
        }
        await center.seed(pending: ["task-reminder/deleted", "unrelated"], delivered: [
            DeliveredTaskReminder(identifier: "task-reminder/deleted", occurrenceID: nil),
            DeliveredTaskReminder(identifier: "unrelated", occurrenceID: nil)
        ])
        try await scheduler.synchronize(enabled: true)
        #expect(await center.pendingIdentifiers().count == 2)
        #expect(await center.requests.values.first?.title == "New title")
        #expect(await center.requests.values.first?.fireDate == ISO8601DateFormatter().date(from: "2026-11-10T11:00:00Z"))
        #expect(await center.deliveredReminders().map(\.identifier) == ["unrelated"])
        let edited = try DWTask(id: task.id, title: "Edited title", schedule: .once(on: day),
                                reminder: .atTime(LocalTime(hour: 12, minute: 0)))
        await source.replace(edited)
        try await scheduler.synchronize(enabled: true)
        #expect(await center.pendingIdentifiers().count == 2)
        #expect(await center.requests.values.first?.title == "Edited title")
        #expect(await center.requests.values.first?.fireDate == ISO8601DateFormatter().date(from: "2026-11-10T12:00:00Z"))
        await source.complete(try OccurrenceRecord(id: id, outcome: .completed(at: now)))
        try await scheduler.synchronize(enabled: true)
        #expect(await center.pendingIdentifiers() == ["unrelated"])
        await source.undo()
        try await scheduler.synchronize(enabled: true)
        #expect(await center.requests.count == 1)
        await source.deleteAll()
        try await scheduler.synchronize(enabled: true)
        #expect(await center.pendingIdentifiers() == ["unrelated"])
    }

    @Test func disablingClearsQueueWithoutLoadingTasksAndKeepsUnrelatedNotifications() async throws {
        let center = RecordingNotificationCenter()
        await center.seed(pending: ["task-reminder/old", "unrelated"], delivered: [
            DeliveredTaskReminder(identifier: "task-reminder/old", occurrenceID: nil)
        ])
        let scheduler = ReminderNotificationScheduler(center: center) {
            Issue.record("Disabling must not depend on successful storage access")
            throw TestError.failed
        }
        try await scheduler.synchronize(enabled: false)
        #expect(await center.pendingIdentifiers() == ["unrelated"])
        #expect(await center.deliveredReminders().isEmpty)
    }

    @Test func revokedPermissionClearsPendingWithoutAskingForPermission() async throws {
        let center = RecordingNotificationCenter(authorized: false)
        await center.seed(pending: ["task-reminder/old"], delivered: [])
        let scheduler = ReminderNotificationScheduler(center: center) {
            Issue.record("Revoked authorization must not load tasks")
            throw TestError.failed
        }
        try await scheduler.synchronize(enabled: true)
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func disableWaitsForInflightSchedulingAndLeavesNoReminders() async throws {
        let (started, startSignal) = AsyncStream<Void>.makeStream()
        let (release, releaseSignal) = AsyncStream<Void>.makeStream()
        let center = RecordingNotificationCenter(beforeAdd: {
            startSignal.yield()
            for await _ in release { break }
        })
        let task = try DWTask(title: "Read", schedule: .once(on: LocalDate(year: 2026, month: 11, day: 10)),
                              reminder: .atTime(LocalTime(hour: 9, minute: 0)))
        let scheduler = ReminderNotificationScheduler(center: center, now: { now }, timeZone: { zone }) {
            ReminderStoreSnapshot(tasks: [task], occurrences: [])
        }
        let enable = Task { try await scheduler.synchronize(enabled: true) }
        for await _ in started { break }
        let disable = Task { try await scheduler.synchronize(enabled: false) }
        // Give the competing request a turn while add is deliberately suspended.
        for _ in 0..<10 { await Task.yield() }
        releaseSignal.yield()
        try await enable.value
        try await disable.value
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func storageFailureRetainsQueueAndNextRefreshRecovers() async throws {
        let center = RecordingNotificationCenter()
        await center.seed(pending: ["task-reminder/old"], delivered: [])
        let scheduler = ReminderNotificationScheduler(center: center) { throw TestError.failed }
        await #expect(throws: TestError.self) { try await scheduler.synchronize(enabled: true) }
        #expect(await center.pendingIdentifiers() == ["task-reminder/old"])
        try await scheduler.synchronize(enabled: false)
        #expect(await center.pendingIdentifiers().isEmpty)
    }
}

private enum TestError: Error { case failed }

private actor ReminderTestStore {
    var snapshot: ReminderStoreSnapshot
    init(tasks: [DWTask]) { snapshot = ReminderStoreSnapshot(tasks: tasks, occurrences: []) }
    func complete(_ record: OccurrenceRecord) { snapshot.occurrences = [record] }
    func replace(_ task: DWTask) { snapshot.tasks = [task] }
    func undo() { snapshot.occurrences = [] }
    func deleteAll() { snapshot.tasks = [] }
}

private actor RecordingNotificationCenter: ReminderNotificationCenter {
    let authorized: Bool
    let beforeAdd: @Sendable () async -> Void
    var pending: Set<String> = []
    var delivered: [DeliveredTaskReminder] = []
    var requests: [String: TaskReminderRequest] = [:]
    var badgeCount = 0
    var badgeUpdates: [String: AppIconBadgeUpdate] = [:]
    func isBadgeAuthorized() -> Bool { authorized }
    func setBadgeCount(_ count: Int) { badgeCount = count }
    func addBadge(_ update: AppIconBadgeUpdate) {
        pending.insert(update.id)
        badgeUpdates[update.id] = update
    }
    init(authorized: Bool = true, beforeAdd: @escaping @Sendable () async -> Void = {}) {
        self.authorized = authorized
        self.beforeAdd = beforeAdd
    }
    func seed(pending: [String], delivered: [DeliveredTaskReminder]) {
        self.pending = Set(pending)
        self.delivered = delivered
    }
    func isAuthorized() -> Bool { authorized }
    func pendingIdentifiers() -> [String] { pending.sorted() }
    func deliveredReminders() -> [DeliveredTaskReminder] { delivered }
    func removePending(_ identifiers: [String]) {
        pending.subtract(identifiers)
        for id in identifiers { requests[id] = nil; badgeUpdates[id] = nil }
    }
    func removeDelivered(_ identifiers: [String]) { delivered.removeAll { identifiers.contains($0.identifier) } }
    func add(_ request: TaskReminderRequest) async throws {
        await beforeAdd()
        pending.insert(request.id)
        requests[request.id] = request
    }
}
