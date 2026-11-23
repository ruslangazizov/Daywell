import SwiftUI
import DesignSystem

struct LegalView: View {
    let onPrivacyPolicyTap: () -> Void
    let onRemoveAllData: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            button(title: "Privacy Policy", action: onPrivacyPolicyTap)

            Divider().overlay(DWColor.separator)

            button(title: "Delete all data", action: onRemoveAllData)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingBackground()
    }

    @ViewBuilder
    private func button(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "arrow.up.right")
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier(Accessibility.privacyPolicy)
        .buttonStyle(.plain)
        .font(.body)
        .foregroundStyle(DWColor.accent(colorScheme))
    }
}
