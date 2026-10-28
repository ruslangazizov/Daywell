import SwiftUI

public enum DWColor {
    public static func bg(_ colorScheme: ColorScheme) -> Color {
        Color.dynamic(
            light: Color.from(hex: 0xFAFAFA),
            dark: Color.from(hex: 0x17171A),
            colorScheme: colorScheme
        )
    }
    public static let group = Color.dynamic(
        light: UIColor.from(hex: 0xFFFFFF),
        dark: UIColor.from(hex: 0x242429)
    )
    public static func grouped(_ colorScheme: ColorScheme) -> Color {
        Color.dynamic(
            light: Color.from(hex: 0xF2F2F7),
            dark: Color.from(hex: 0x101013),
            colorScheme: colorScheme
        )
    }
    public static let label = Color.dynamic(
        light: UIColor.from(hex: 0x1C1C1E),
        dark: UIColor.from(hex: 0xF4F4F7)
    )
    public static func secondary(_ colorScheme: ColorScheme) -> Color {
        Color.dynamic(
            light: Color.from(hex: 0x68686F),
            dark: Color.from(hex: 0xADADB5),
            colorScheme: colorScheme
        )
    }
    // TODO: возможно стоит поменять на UIColor.tertiarySystemFill - выглядит красивее
    public static let separator = Color.dynamic(
        light: UIColor.from(hex: 0xE4E4E9),
        dark: UIColor.from(hex: 0x3A3A42)
    )
    public static func accent(_ colorScheme: ColorScheme) -> Color {
        Color.dynamic(
            light: Color.from(hex: 0x6553CD),
            dark: Color.from(hex: 0xB1A0FF),
            colorScheme: colorScheme
        )
    }
    public static let accentSoft = Color.dynamic(
        light: UIColor.from(hex: 0xEAE6F8),
        dark: UIColor.from(hex: 0x383049)
    )
    public static let glass = Color.dynamic(
        light: UIColor.from(hex: 0xF8F8FA),
        dark: UIColor.from(hex: 0x303036)
    )
    public static let red = Color.dynamic(
        light: UIColor.from(hex: 0xD83A40),
        dark: UIColor.from(hex: 0xFF686D)
    )
    public static let lilacBg = Color.dynamic(
        light: UIColor.from(hex: 0xEEE9FA),
        dark: UIColor.from(hex: 0x352C49)
    )
    public static let lilacLabel = Color.dynamic(
        light: UIColor.from(hex: 0x493579),
        dark: UIColor.from(hex: 0xE1D3FF)
    )
    public static let lilacBorder = Color.dynamic(
        light: UIColor.from(hex: 0xD6CCEC),
        dark: UIColor.from(hex: 0x5A4777)
    )
    public static let mintBg = Color.dynamic(
        light: UIColor.from(hex: 0xE4F0E8),
        dark: UIColor.from(hex: 0x243D31)
    )
    public static let mintLabel = Color.dynamic(
        light: UIColor.from(hex: 0x255640),
        dark: UIColor.from(hex: 0xCAECD7)
    )
    public static let mintBorder = Color.dynamic(
        light: UIColor.from(hex: 0xC8DFD0),
        dark: UIColor.from(hex: 0x40634E)
    )
    public static let peachBg = Color.dynamic(
        light: UIColor.from(hex: 0xF7EBD7),
        dark: UIColor.from(hex: 0x433725)
    )
    public static let peachLabel = Color.dynamic(
        light: UIColor.from(hex: 0x73501D),
        dark: UIColor.from(hex: 0xF4DDB5)
    )
    public static let peachBorder = Color.dynamic(
        light: UIColor.from(hex: 0xECDBBE),
        dark: UIColor.from(hex: 0x6D5636)
    )
    public static let blueBg = Color.dynamic(
        light: UIColor.from(hex: 0xE5EDF8),
        dark: UIColor.from(hex: 0x28384D)
    )
    public static let blueLabel = Color.dynamic(
        light: UIColor.from(hex: 0x315374),
        dark: UIColor.from(hex: 0xD0E2FA)
    )
    public static let blueBorder = Color.dynamic(
        light: UIColor.from(hex: 0xCDDBF0),
        dark: UIColor.from(hex: 0x435D7C)
    )
    public static let roseBg = Color.dynamic(
        light: UIColor.from(hex: 0xF7E6EC),
        dark: UIColor.from(hex: 0x452D37)
    )
    public static let roseLabel = Color.dynamic(
        light: UIColor.from(hex: 0x814359),
        dark: UIColor.from(hex: 0xF5CDDC)
    )
    public static let roseBorder = Color.dynamic(
        light: UIColor.from(hex: 0xECD0DB),
        dark: UIColor.from(hex: 0x704555)
    )
    public static let white = Color.white
    public static let green = Color.dynamic(
        light: UIColor.from(hex: 0x34C759),
        dark: UIColor.from(hex: 0x30D158)
    )
}
