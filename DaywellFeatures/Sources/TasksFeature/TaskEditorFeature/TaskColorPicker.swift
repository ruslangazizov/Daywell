import DesignSystem
import Domain
import SwiftUI

struct TaskColorPicker: View {
    @Binding var selection: TaskColorToken

    var body: some View {
        HStack(spacing: 12) {
            ForEach(TaskColorToken.allCases, id: \.self) { color in
                let group = color.toDWColorGroup
                Button {
                    selection = color
                } label: {
                    Circle()
                        .fill(group.bg)
                        .strokeBorder(group.border, lineWidth: 1)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == color {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(group.label)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Task color")
    }
}
