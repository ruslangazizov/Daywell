import SwiftUI

public struct DWColorGroup {
    public let bg: Color
    public let label: Color
    public let border: Color

    public init(bg: Color, label: Color, border: Color) {
        self.bg = bg
        self.label = label
        self.border = border
    }

    public static let defaults: [DWColorGroup] = [
        DWColorGroup(bg: DWColor.lilacBg, label: DWColor.lilacLabel, border: DWColor.lilacBorder),
        DWColorGroup(bg: DWColor.mintBg, label: DWColor.mintLabel, border: DWColor.mintBorder),
        DWColorGroup(bg: DWColor.peachBg, label: DWColor.peachLabel, border: DWColor.peachBorder),
        DWColorGroup(bg: DWColor.blueBg, label: DWColor.blueLabel, border: DWColor.blueBorder),
        DWColorGroup(bg: DWColor.roseBg, label: DWColor.roseLabel, border: DWColor.roseBorder),
    ]
}
