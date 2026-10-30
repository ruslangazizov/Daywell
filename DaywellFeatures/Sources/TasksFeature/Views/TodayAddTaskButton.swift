import SwiftUI
import DesignSystem

struct TodayAddTaskButton: View {
    let onTap: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            Image(systemName: "plus")
                .font(.system(size: 21, weight: .light))
                .foregroundStyle(DWColor.white)
                .frame(width: 54, height: 54)
                .background(DWColor.accent(colorScheme), in: Circle())
                .overlay {
                    Circle().strokeBorder(DWColor.accentSoft, lineWidth: 1)
                }
                .shadow(color: DWColor.label.opacity(0.08), radius: 16, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add task")
    }
}
