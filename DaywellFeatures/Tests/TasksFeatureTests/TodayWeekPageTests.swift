import Foundation
import Testing
@testable import TasksFeature

struct TodayWeekPageTests {
    private func calendar(firstWeekday: Int = 2, timeZone: String = "Europe/Belgrade") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.firstWeekday = firstWeekday
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    @Test func currentWeekHonorsFirstWeekday() {
        for firstWeekday in [1, 2, 7] {
            let calendar = calendar(firstWeekday: firstWeekday)
            let today = date(2026, 10, 23, calendar: calendar)
            let pages = TodayWeekPage.surrounding(today, calendar: calendar)
            let current = pages[TodayWeekPage.Constants.weeksCount / 2]

            #expect(pages.map(\.id) == [-2, -1, 0, 1, 2])
            #expect(current.dates.count == 7)
            #expect(calendar.component(.weekday, from: current.dates[0]) == firstWeekday)
            #expect(current.dates.filter { calendar.isDate($0, inSameDayAs: today) }.count == 1)
        }
    }

    @Test func weeksCrossMonthAndYearBoundaries() {
        let calendar = calendar()
        let dates = TodayWeekPage.surrounding(
            date(2026, 12, 31, calendar: calendar), calendar: calendar
        )[TodayWeekPage.Constants.weeksCount / 2].dates

        #expect(dates.map { calendar.component(.day, from: $0) } == [28, 29, 30, 31, 1, 2, 3])
        #expect(dates.map { calendar.component(.month, from: $0) } == [12, 12, 12, 12, 1, 1, 1])
        #expect(calendar.component(.year, from: dates[6]) == 2027)
    }

    @Test func includesLeapDay() {
        let calendar = calendar()
        let dates = TodayWeekPage.surrounding(
            date(2028, 2, 29, calendar: calendar), calendar: calendar
        )[TodayWeekPage.Constants.weeksCount / 2].dates

        #expect(dates.map { calendar.component(.day, from: $0) } == [28, 29, 1, 2, 3, 4, 5])
    }

    @Test func calendarDaysStayAtMidnightAcrossDaylightSavingChanges() {
        let calendar = calendar()
        for (month, day, expectedHours) in [(3, 29, 23.0), (10, 25, 25.0)] {
            let dates = TodayWeekPage.surrounding(
                date(2026, month, day, calendar: calendar), calendar: calendar
            ).flatMap(\.dates)

            #expect(Set(dates).count == 7 * TodayWeekPage.Constants.weeksCount)
            #expect(dates.allSatisfy { calendar.component(.hour, from: $0) == 0 })
            let intervals = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) / 3600 }
            #expect(intervals.contains(expectedHours))
        }
    }

    @Test func pagingKeepsOnlyGivenConstantWeeksAndCanReturnToTheStart() {
        let calendar = calendar()
        let initial = TodayWeekPage.surrounding(date(2026, 10, 23, calendar: calendar), calendar: calendar)
        var pages = initial

        for direction in [2, -2] {
            for _ in 0 ..< 500 {
                let nextStart = pages.first { $0.id == direction }!.dates[0]
                pages = TodayWeekPage.surrounding(nextStart, calendar: calendar)
                #expect(pages.count == TodayWeekPage.Constants.weeksCount)
                #expect(pages.flatMap(\.dates).count == 7 * TodayWeekPage.Constants.weeksCount)
            }
        }

        let middle = TodayWeekPage.Constants.weeksCount / 2
        #expect(pages[middle].dates == initial[middle].dates)
    }
}
