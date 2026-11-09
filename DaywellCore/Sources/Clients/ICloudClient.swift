import CloudKit
import CoreData
import Dependencies
import Foundation
import Persistence

public nonisolated struct ICloudSnapshot: Equatable, Sendable {
    public var status: ICloudSyncStatus
    public var lastConfirmedSync: Date?
    /// Changes when an import or account change requires the features to reload.
    public var dataRevision: Int
    public var version: Int

    public init(status: ICloudSyncStatus, lastConfirmedSync: Date? = nil, dataRevision: Int = 0, version: Int = 0) {
        self.status = status
        self.lastConfirmedSync = lastConfirmedSync
        self.dataRevision = dataRevision
        self.version = version
    }
}

public nonisolated struct ICloudClient: Sendable {
    public var observe: @Sendable () async -> AsyncStream<ICloudSnapshot>
    public var refresh: @Sendable () async -> ICloudSnapshot

    public init(
        observe: @escaping @Sendable () async -> AsyncStream<ICloudSnapshot>,
        refresh: @escaping @Sendable () async -> ICloudSnapshot
    ) {
        self.observe = observe
        self.refresh = refresh
    }
}

extension DependencyValues {
    public var iCloudClient: ICloudClient {
        get { self[ICloudClient.self] }
        set { self[ICloudClient.self] = newValue }
    }
}

extension ICloudClient: DependencyKey {
    public static var liveValue: Self {
        if ProcessInfo.processInfo.environment["IS_UI_TESTING"] == "true" {
            #if DEBUG
            let status = ProcessInfo.processInfo.environment["ICLOUD_UI_TEST_STATUS"]
                .flatMap(ICloudSyncStatus.init(rawValue:)) ?? .localOnly
            return fixed(.init(status: status))
            #else
            return fixed(.init(status: .localOnly))
            #endif
        }
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["DAYWELL_ENABLE_CLOUD_SYNC"] != "true" {
            return fixed(.init(status: .localOnly))
        }
        #endif
        return Self(
            observe: { await ICloudMonitor.shared.observe() },
            refresh: { await ICloudMonitor.shared.refresh() }
        )
    }

    public static let previewValue = fixed(.init(status: .noConfirmedSync))
    public static let testValue = Self(
        observe: unimplemented("ICloudClient.observe", placeholder: AsyncStream { $0.finish() }),
        refresh: unimplemented("ICloudClient.refresh", placeholder: .init(status: .notChecked))
    )

    static func fixed(_ snapshot: ICloudSnapshot) -> Self {
        Self(observe: { AsyncStream { $0.yield(snapshot); $0.finish() } }, refresh: { snapshot })
    }
}

/// Tracks observed transfers only. Account availability and setup success never imply
/// that all records have reached iCloud, or that another device has received them.
nonisolated struct ICloudTransferState {
    var active: Set<UUID> = []
    private enum Kind { case setup, importing, exporting }
    private var failures: [Kind: ICloudSyncStatus] = [:]
    var failure: ICloudSyncStatus? {
        failures[.exporting] ?? failures[.importing] ?? failures[.setup]
    }
    var lastConfirmedSync: Date?
    var dataRevision = 0

    mutating func receive(id: UUID, isTransfer: Bool, isImport: Bool, end: Date?, failure: ICloudSyncStatus?) {
        guard let end else { active.insert(id); return }
        active.remove(id)
        let kind: Kind = isImport ? .importing : (isTransfer ? .exporting : .setup)
        failures[kind] = failure
        if failure == nil {
            // Success clears only the same operation's failure. An import cannot
            // hide an export failure (for example, exhausted iCloud storage).
            if isTransfer {
                lastConfirmedSync = max(lastConfirmedSync ?? end, end)
            }
            if isImport { dataRevision += 1 }
        }
    }

    func snapshot(account: ICloudSyncStatus) -> ICloudSnapshot {
        let status: ICloudSyncStatus
        if account != .available { status = account }
        else if let failure { status = failure }
        else if !active.isEmpty { status = .syncing }
        else { status = lastConfirmedSync == nil ? .noConfirmedSync : .available }
        return .init(status: status, lastConfirmedSync: lastConfirmedSync, dataRevision: dataRevision)
    }
}

@MainActor
final class ICloudMonitor {
    static let shared = ICloudMonitor()
    private var account: ICloudSyncStatus = .notChecked
    private var transfers = ICloudTransferState()
    private var observers: [NSObjectProtocol] = []
    private var continuations: [UUID: AsyncStream<ICloudSnapshot>.Continuation] = [:]
    private var requestGeneration = 0
    private var version = 0

    private init() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .CKAccountChanged, object: nil, queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let revision = self.transfers.dataRevision + 1
                self.transfers = ICloudTransferState()
                self.transfers.dataRevision = revision
                self.account = .checking
                self.publish()
                _ = await self.refresh()
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: nil
        ) { [weak self] notification in
            guard let container = notification.object as? NSPersistentCloudKitContainer,
                  container.persistentStoreDescriptions.contains(where: {
                      $0.cloudKitContainerOptions?.containerIdentifier == TaskStore.cloudContainerIdentifier
                  }),
                  let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event else { return }
            let id = event.identifier
            let isImport = event.type == .import
            let isTransfer = isImport || event.type == .export
            let end = event.endDate
            let failure: ICloudSyncStatus? = end != nil && !event.succeeded
                ? Self.failureStatus(event.error) : nil
            Task { @MainActor in
                guard let self else { return }
                self.transfers.receive(id: id, isTransfer: isTransfer, isImport: isImport, end: end, failure: failure)
                self.publish()
            }
        })
    }

    func observe() -> AsyncStream<ICloudSnapshot> {
        let id = UUID()
        let (stream, continuation) = AsyncStream<ICloudSnapshot>.makeStream(bufferingPolicy: .bufferingNewest(1))
        continuations[id] = continuation
        continuation.yield(snapshot)
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations.removeValue(forKey: id) }
        }
        return stream
    }

    func refresh() async -> ICloudSnapshot {
        requestGeneration += 1
        let generation = requestGeneration
        let result: ICloudSyncStatus
        do {
            // Ensure setup errors become a visible state, rather than reporting an
            // available account while the model container could not be opened.
            _ = try ClientStore.live()
            result = Self.accountStatus(try await CKContainer(identifier: TaskStore.cloudContainerIdentifier).accountStatus())
        } catch {
            result = Self.failureStatus(error)
        }
        if generation == requestGeneration {
            account = result
            publish()
        }
        return snapshot
    }

    private var snapshot: ICloudSnapshot {
        var value = transfers.snapshot(account: account)
        value.version = version
        return value
    }

    private func publish() {
        version += 1
        let snapshot = snapshot
        for continuation in continuations.values { continuation.yield(snapshot) }
    }

    nonisolated static func accountStatus(_ status: CKAccountStatus) -> ICloudSyncStatus {
        switch status {
        case .available: .available
        case .noAccount: .signedOut
        case .restricted: .restricted
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .couldNotDetermine: .needsAttention
        @unknown default: .needsAttention
        }
    }

    nonisolated static func failureStatus(_ error: Error?) -> ICloudSyncStatus {
        guard let error else { return .needsAttention }
        let nsError = error as NSError
        if nsError.domain != CKErrorDomain {
            if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
                return failureStatus(underlying)
            }
            return .needsAttention
        }
        switch CKError.Code(rawValue: nsError.code) {
        case .partialFailure:
            let errors = nsError.userInfo[CKPartialErrorsByItemIDKey] as? [AnyHashable: Error] ?? [:]
            let statuses = Set(errors.values.map(failureStatus))
            return [.storageFull, .signedOut, .waitingForConnection, .temporarilyUnavailable]
                .first(where: statuses.contains) ?? .needsAttention
        case .notAuthenticated: return .signedOut
        case .networkFailure, .networkUnavailable: return .waitingForConnection
        case .serviceUnavailable, .requestRateLimited, .zoneBusy: return .temporarilyUnavailable
        case .quotaExceeded: return .storageFull
        default: return .needsAttention
        }
    }
}
