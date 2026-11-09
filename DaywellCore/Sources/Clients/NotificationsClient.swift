import Dependencies
import Domain
import Foundation
import Persistence
import UIKit
import UserNotifications

public nonisolated enum NotificationAuthorization: Equatable, Sendable {
    case notDetermined, denied, authorized

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .authorized, .provisional, .ephemeral: self = .authorized
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        @unknown default: self = .denied
        }
    }
}

public nonisolated struct NotificationsClient: Sendable {
    public var authorizationStatus: @Sendable () async -> NotificationAuthorization
    public var requestAuthorization: @Sendable () async throws -> NotificationAuthorization
    public var openSettings: @Sendable () async -> Void
    public var responses: @Sendable () async -> AsyncStream<TaskOccurrenceID>
    public var synchronize: @Sendable (Bool) async throws -> Void
}

extension DependencyValues {
    public var notificationsClient: NotificationsClient {
        get { self[NotificationsClient.self] }
        set { self[NotificationsClient.self] = newValue }
    }
}

extension NotificationsClient: DependencyKey {
    public static let liveValue = Self(
        authorizationStatus: {
            NotificationAuthorization(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus)
        },
        requestAuthorization: {
            let center = UNUserNotificationCenter.current()
            if await center.notificationSettings().authorizationStatus == .notDetermined {
                _ = try await center.requestAuthorization(options: [.alert, .sound])
            }
            return NotificationAuthorization(await center.notificationSettings().authorizationStatus)
        },
        openSettings: {
            await MainActor.run {
                guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        },
        responses: { await NotificationResponseObserver.shared.stream },
        synchronize: { try await ReminderNotificationScheduler.live.synchronize(enabled: $0) }
    )

    public static let previewValue = Self(
        authorizationStatus: { .authorized }, requestAuthorization: { .authorized },
        openSettings: {}, responses: { AsyncStream { $0.finish() } }, synchronize: { _ in }
    )
    public static let testValue = Self(
        authorizationStatus: unimplemented("NotificationsClient.authorizationStatus", placeholder: .notDetermined),
        requestAuthorization: unimplemented("NotificationsClient.requestAuthorization"),
        openSettings: unimplemented("NotificationsClient.openSettings"),
        responses: unimplemented("NotificationsClient.responses", placeholder: AsyncStream { $0.finish() }),
        synchronize: unimplemented("NotificationsClient.synchronize")
    )
}
