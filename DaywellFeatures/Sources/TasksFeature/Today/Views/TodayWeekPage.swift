import Foundation

/// A bounded window of calendar dates for the reusable week pager
struct TodayWeekPage: Identifiable {
    let id: Int
    let dates: [Date]

    static func surrounding(_ date: Date, calendar: Calendar) -> [Self] {
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
