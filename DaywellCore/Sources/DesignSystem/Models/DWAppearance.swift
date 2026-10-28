import SwiftUI

public enum DWAppearance: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    public nonisolated static let defaultValue: Self = .system

    public var title: String { rawValue.capitalized }

    public var icon: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    public var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
    }
}
