import SwiftUI
import DesignSystem
import Persistence

struct PlanningSettingsView: View {
    @Binding var firstDayOfWeek: FirstDayOfWeek
    let taskDurations: [TaskDuration]
    @Binding var defaultTaskDuration: TaskDuration
    let onCustomDuration: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            LabeledContent {
                Picker("First day of week", selection: $firstDayOfWeek) {
                    ForEach(FirstDayOfWeek.allCases) { day in
                        Text(day.title).tag(day)
                    }
                }
                .labelsHidden()
            } label: {
                Text("First day of week")
                    .foregroundStyle(DWColor.label)
            }
            .frame(minHeight: 44)
            .padding(.vertical, 8)

            Divider()
                .overlay(DWColor.separator)

            LabeledContent {
                Menu {
                    Picker("Task window", selection: $defaultTaskDuration) {
                        ForEach(taskDurations) { duration in
                            Text(duration.title).tag(duration)
                        }
                    }
                    .pickerStyle(.inline)

                    Divider()
                    Button("Custom…", systemImage: "plus", action: onCustomDuration)
                        .accessibilityIdentifier(Accessibility.customDuration)
                } label: {
                    HStack(spacing: 4) {
                        Text(defaultTaskDuration.title)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                }
                .menuOrder(.fixed)
                .accessibilityLabel("Task window, \(defaultTaskDuration.title)")
                .accessibilityIdentifier(Accessibility.taskWindow)
            } label: {
                Text("Task window")
                    .foregroundStyle(DWColor.label)
            }
            .frame(minHeight: 44)
            .padding(.vertical, 8)
        }
        .pickerStyle(.menu)
        .tint(DWColor.accent(colorScheme))
        .padding(.horizontal, 16)
        .settingBackground()
    }
}
