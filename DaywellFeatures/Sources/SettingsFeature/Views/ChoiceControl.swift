import SwiftUI
import DesignSystem

struct ChoiceControl<Option: Hashable>: View {
    @Environment(\.colorScheme) var colorScheme

    let options: [Option]
    @Binding var selection: Option

    let isStacked: Bool
    let title: (Option) -> String
    let icon: (Option) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                let isSelected = selection == option

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selection = option
                    }
                } label: {
                    optionLabel(option)
                        .font(.body)
                        .foregroundStyle(
                            isSelected ? DWColor.accent(colorScheme) : DWColor.secondary(colorScheme)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, isStacked ? 18 : 20)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(DWColor.separator)
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .settingBackground()
    }

    @ViewBuilder
    private func optionLabel(_ option: Option) -> some View {
        if isStacked {
            VStack(spacing: 12) {
                Image(systemName: icon(option))
                    .font(.title2)
                    .accessibilityHidden(true)

                Text(title(option))
                    .font(.subheadline)
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: icon(option))
                    .accessibilityHidden(true)

                Text(title(option))
                    .font(.subheadline)
            }
        }
    }
}
