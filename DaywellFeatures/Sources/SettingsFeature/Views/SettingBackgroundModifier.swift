import SwiftUI
import DesignSystem

extension View {
    func settingBackground() -> some View {
        modifier(SettingBackgroundModifier())
    }
}

struct SettingBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                DWColor.group,
                in: RoundedRectangle(
                    cornerRadius: 26,
                    style: .continuous
                )
            )
    }
}
