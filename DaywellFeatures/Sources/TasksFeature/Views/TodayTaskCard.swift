import DesignSystem
import Domain
import SwiftUI

struct TodayTaskCard: View {
    let model: TodayTaskModel
    var minHeight: CGFloat = UIConstants.minTaskCardHeight
    var onOpen: (TaskOccurrenceID) -> Void = { _ in }
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    var body: some View {
        TaskCard(
            title: model.title,
            time: model.time,
            recurrence: model.recurrence,
            colorGroup: model.color.toDWColorGroup,
            isCompleted: Binding(
                get: { model.isCompleted },
                set: { onCompletionChanged(model.id, $0) }
            ),
            minHeight: minHeight,
            onOpen: { onOpen(model.id) }
        )
        .accessibilityIdentifier(Accessibility.todayTask(model.id.taskID))
    }
}
