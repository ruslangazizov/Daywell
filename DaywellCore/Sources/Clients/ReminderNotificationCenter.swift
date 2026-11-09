import Domain
import Foundation
import UserNotifications

struct DeliveredTaskReminder: Sendable {
    var identifier: String
    var occurrenceID: TaskOccurrenceID?
}

protocol ReminderNotificationCenter: Sendable {
    func isAuthorized() async -> Bool
    func pendingIdentifiers() async -> [String]
    func deliveredReminders() async -> [DeliveredTaskReminder]
    func removePending(_ identifiers: [String]) async
    func removeDelivered(_ identifiers: [String]) async
    func add(_ request: TaskReminderRequest) async throws
}

struct SystemReminderNotificationCenter: ReminderNotificationCenter {
    func isAuthorized() async -> Bool {
        NotificationAuthorization(await UNUserNotificationCenter.current().notificationSettings().authorizationStatus) == .authorized
    }

    func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    func deliveredReminders() async -> [DeliveredTaskReminder] {
        await UNUserNotificationCenter.current().deliveredNotifications().map {
            DeliveredTaskReminder(identifier: $0.request.identifier,
                                  occurrenceID: Self.occurrenceID(from: $0.request.content.userInfo))
        }
    }

    func removePending(_ identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func removeDelivered(_ identifiers: [String]) async {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func add(_ request: TaskReminderRequest) async throws {
        guard request.fireDate > .now else { return }
        // Use an absolute UTC trigger: an ambiguous autumn wall-clock hour must
        // refer to the exact instant chosen by the planner.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = "Your task reminder."
        content.sound = .default
        content.threadIdentifier = "task-reminders"
        let day = request.occurrenceID.day
        content.userInfo = [
            "taskID": request.occurrenceID.taskID.uuidString,
            "year": day.year,
            "month": day.month,
            "day": day.day
        ]
        var components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: request.fireDate)
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        )
    }

    static func occurrenceID(from info: [AnyHashable: Any]) -> TaskOccurrenceID? {
        guard let raw = info["taskID"] as? String, let id = UUID(uuidString: raw),
              let year = info["year"] as? Int, let month = info["month"] as? Int,
              let day = info["day"] as? Int,
              let date = try? LocalDate(year: year, month: month, day: day) else { return nil }
        return TaskOccurrenceID(taskID: id, day: date)
    }
}
