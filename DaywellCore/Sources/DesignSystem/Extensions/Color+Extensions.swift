import SwiftUI
import UIKit

extension Color {
    nonisolated static func dynamic(light: UIColor, dark: UIColor) -> Color {
        return Color(uiColor: UIColor(dynamicProvider: { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return dark
            } else {
                return light
            }
        }))
    }
    static func dynamic(light: Color, dark: Color, colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            return dark
        } else {
            return light
        }
    }
    static func from(hex rgbValue: UInt64) -> Color {
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgbValue & 0x0000FF) / 255
        return Color(red: r, green: g, blue: b, opacity: 1)
    }
}

extension UIColor {
    static func from(hex rgbValue: UInt64) -> UIColor {
        let r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255
        let g = CGFloat((rgbValue & 0x00FF00) >> 8) / 255
        let b = CGFloat(rgbValue & 0x0000FF) / 255
        return UIColor(red: r, green: g, blue: b, alpha: 1)
    }
}
