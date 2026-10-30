import Foundation
import Persistence

/// A bounded window of calendar dates for the reusable week pager
struct TodayWeekPage: Identifiable {
    let id: Int
    let dates: [Date]

    static func surrounding(
        _ date: Date,
        calendar: Calendar,
        firstDayOfWeek: FirstDayOfWeek = .system
    ) -> [Self] {
        var calendar = calendar
        calendar.firstWeekday = switch firstDayOfWeek {
        case .system: calendar.firstWeekday
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }

        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        let weeksCount = Constants.weeksCount

        return (-weeksCount/2 ... weeksCount/2).map { offset in
            let dates = (0 ..< 7).compactMap { day in
                calendar.date(byAdding: .day, value: offset * 7 + day, to: start)
            }
            return Self(id: offset, dates: dates)
        }
    }

    enum Constants {
        static let weeksCount = 5
    }
}
