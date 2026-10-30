import DesignSystem
import Domain
import SwiftUI

struct TodayTaskWindows: View {
    let tasks: [TodayTaskModel]
    let hourHeight: CGFloat
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    private var groups: [TodayTaskWindowGroup] {
        TodayTaskWindowGroup.layout(
            tasks, minimumMinutes: Double((UIConstants.minTaskCardHeight + 5) / hourHeight * 60)
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(groups) { group in
                TodayOverlappingTaskWindows(
                    group: group, hourHeight: hourHeight,
                    onCompletionChanged: onCompletionChanged
                )
                .offset(y: CGFloat(group.startMinute / 60) * hourHeight)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: CGFloat((groups.last?.endMinute ?? 0) / 60) * hourHeight, alignment: .topLeading)
        .padding(.top, 12)
    }
}

private struct TodayOverlappingTaskWindows: View {
    let group: TodayTaskWindowGroup
    let hourHeight: CGFloat
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    private var height: CGFloat {
        CGFloat((group.endMinute - group.startMinute) / 60) * hourHeight
    }

    var body: some View {
        GeometryReader { geometry in
            let scrolls = group.columnCount > 2
            let cardWidth = scrolls
                ? geometry.size.width * 0.4
                : (geometry.size.width - CGFloat(group.columnCount - 1) * 8) / CGFloat(group.columnCount)
            let contentWidth = cardWidth * CGFloat(group.columnCount) + CGFloat(group.columnCount - 1) * 8

            if scrolls {
                ScrollView(.horizontal) {
                    TodayTaskWindowColumns(
                        group: group,
                        cardWidth: cardWidth,
                        hourHeight: hourHeight,
                        onCompletionChanged: onCompletionChanged
                    )
                    .frame(width: contentWidth, height: height, alignment: .topLeading)
                }
                .accessibilityIdentifier(Accessibility.todayOverlappingTasks)
            } else {
                TodayTaskWindowColumns(
                    group: group,
                    cardWidth: cardWidth,
                    hourHeight: hourHeight,
                    onCompletionChanged: onCompletionChanged
                )
            }
        }
        .frame(height: height)
    }
}

private struct TodayTaskWindowColumns: View {
    let group: TodayTaskWindowGroup
    let cardWidth: CGFloat
    let hourHeight: CGFloat
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(group.placements) { placement in
                TodayTaskCard(
                    model: placement.task,
                    minHeight: CGFloat((placement.endMinute - placement.startMinute) / 60) * hourHeight - 5,
                    onCompletionChanged: onCompletionChanged
                )
                .frame(width: cardWidth)
                .offset(
                    x: CGFloat(placement.column) * (cardWidth + 8),
                    y: CGFloat((placement.startMinute - group.startMinute) / 60) * hourHeight
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
