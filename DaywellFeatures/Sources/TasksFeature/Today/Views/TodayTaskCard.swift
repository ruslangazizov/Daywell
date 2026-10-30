import DesignSystem
import Domain
import SwiftUI

struct TodayTaskCard: View {
    let model: TodayTaskModel
    var minHeight: CGFloat = UIConstants.minTaskCardHeight
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void

    var body: some View {
        TaskCard(
            title: model.title,
            time: model.time,
            recurrence: model.recurrence,
            colorGroup: colorGroup,
            isCompleted: Binding(
                get: { model.isCompleted },
                set: { onCompletionChanged(model.id, $0) }
            ),
            minHeight: minHeight
        )
        .accessibilityIdentifier(Accessibility.todayTask(model.id.taskID))
    }

    private var colorGroup: DWColorGroup {
        switch model.color {
        case .lilac: DWColorGroup(bg: DWColor.lilacBg, label: DWColor.lilacLabel, border: DWColor.lilacBorder)
        case .mint: DWColorGroup(bg: DWColor.mintBg, label: DWColor.mintLabel, border: DWColor.mintBorder)
        case .peach: DWColorGroup(bg: DWColor.peachBg, label: DWColor.peachLabel, border: DWColor.peachBorder)
        case .blue: DWColorGroup(bg: DWColor.blueBg, label: DWColor.blueLabel, border: DWColor.blueBorder)
        case .rose: DWColorGroup(bg: DWColor.roseBg, label: DWColor.roseLabel, border: DWColor.roseBorder)
        }
    }
}
