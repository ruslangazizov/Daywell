import Domain
import DesignSystem
import SwiftUI

struct TodayTimelineView: View {
    let model: TodayTimelineViewModel
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    @ScaledMetric(relativeTo: .subheadline) private var hourHeight: CGFloat = 84

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 16) {
                if model.isEmpty {
                    ContentUnavailableView(
                        "No tasks for this day",
                        systemImage: "calendar",
                        description: Text("Your scheduled tasks will appear here.")
                    )
                    .frame(minHeight: 250)
                }

                if !model.untimedTasks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Any time")
                            .font(.subheadline.weight(.semibold))
                        ForEach(model.untimedTasks) { task in
                            TodayTaskCard(model: task, onCompletionChanged: onCompletionChanged)
                        }
                    }
                    .padding(.horizontal, 20)
                    .id("today-untimed")
                }

                if !model.tasks.isEmpty {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            ForEach(model.hours) { hour in
                                TodayHourRow(hour: hour.label, height: hourHeight)
                                    .id(hour.id)
                            }
                        }

                        TodayTaskWindows(
                            tasks: model.tasks,
                            hourHeight: hourHeight,
                            onCompletionChanged: onCompletionChanged
                        )
                        .padding(.leading, 59)
                        .padding(.trailing, 17)

                        if let currentTime = model.currentTime {
                            TodayCurrentTimeRule(time: currentTime.label)
                                .offset(y: CGFloat(currentTime.minute) / 60 * hourHeight + 4)
                        }
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 84)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier(Accessibility.todayTimeline)
    }
}

private struct TodayHourRow: View {
    let hour: String
    let height: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var labelSize: CGFloat = 11

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Text(hour)
                .font(.system(size: labelSize))
                .foregroundStyle(DWColor.secondary(colorScheme))
                .frame(width: 43, alignment: .leading)
                .padding(.top, 2)

            VStack(spacing: 0) {
                Rectangle()
                    .fill(DWColor.separator)
                    .frame(height: 0.5)

                Spacer(minLength: 0)

                Rectangle()
                    .fill(DWColor.separator.opacity(0.4))
                    .frame(height: 0.5)
            }
            .frame(height: height / 2 + 0.5)
            .padding(.top, 11)
        }
        .padding(.leading, 5)
        .padding(.trailing, 17)
        .frame(height: height, alignment: .top)
        .accessibilityHidden(true)
    }
}

private struct TodayCurrentTimeRule: View {
    let time: String

    var body: some View {
        HStack(spacing: 1) {
            Text(time)
                .font(.system(size: 11))
                .frame(width: 40, height: 16, alignment: .leading)

            Rectangle()
                .frame(height: 1)
        }
        .foregroundStyle(DWColor.red)
        .padding(.leading, 2)
        .padding(.trailing, 17)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current time, \(time)")
    }
}
