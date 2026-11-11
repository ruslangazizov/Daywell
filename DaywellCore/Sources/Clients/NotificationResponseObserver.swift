import Domain
import Foundation
import UserNotifications

@MainActor
final class NotificationResponseObserver: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationResponseObserver()
    let stream: AsyncStream<TaskOccurrenceID>
    private let continuation: AsyncStream<TaskOccurrenceID>.Continuation

    private override init() {
        (stream, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier.hasPrefix("app-icon-badge/") ? [.badge] : [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let id = SystemReminderNotificationCenter.occurrenceID(
                from: response.notification.request.content.userInfo
              ) else { return }

        continuation.yield(id)
    }
}

extension NotificationsClient {
    /// Install during app construction so cold-launch taps are buffered until UI is ready.
    @MainActor public static func installDelegate() {
        UNUserNotificationCenter.current().delegate = NotificationResponseObserver.shared
    }
}
