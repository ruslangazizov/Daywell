import DesignSystem
import Domain

extension TaskColorToken {
    var toDWColorGroup: DWColorGroup {
        switch self {
        case .lilac: DWColorGroup.defaults[0]
        case .mint: DWColorGroup.defaults[1]
        case .peach: DWColorGroup.defaults[2]
        case .blue: DWColorGroup.defaults[3]
        case .rose: DWColorGroup.defaults[4]
        }
    }
}
