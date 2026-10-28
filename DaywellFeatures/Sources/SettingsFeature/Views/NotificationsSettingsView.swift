import SwiftUI
import DesignSystem

struct NotificationsSettingsView: View {
    @Binding var taskRemindersEnabled: Bool
    @Binding var appIconBadgeEnabled: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            Toggle(isOn: $taskRemindersEnabled) {
                label(
                    title: "Task reminders",
                    subtitle: "On this device"
                )
            }
            .padding(.vertical, 16)

            Divider()
                .overlay(DWColor.separator)

            Toggle(isOn: $appIconBadgeEnabled) {
                label(
                    title: "App icon badge",
                    subtitle: "Unfinished tasks for today"
                )
            }
            .padding(.vertical, 16)
        }
        .toggleStyle(.switch)
        .tint(DWColor.accent(colorScheme))
        .padding(.horizontal, 16)
        .settingBackground()
    }

    private func label(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body)
                .foregroundStyle(DWColor.label)

            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(DWColor.secondary(colorScheme))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
