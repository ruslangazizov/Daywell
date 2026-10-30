import DesignSystem
import SwiftUI
import Dependencies
import ComposableArchitecture
import Persistence

struct TodayDateStrip: View {
    @Dependency(\.calendar) private var calendar
    @SharedReader(Preferences.firstDayOfWeek) private var firstDayOfWeek

    @State private var visibleWeekStart: Date?
    @State private var visiblePage: Int? = 0
    @Binding var selectedDate: Date

    var body: some View {
        let pages = TodayWeekPage.surrounding(
            visibleWeekStart ?? selectedDate,
            calendar: calendar,
            firstDayOfWeek: firstDayOfWeek
        )

        ScrollView(.horizontal) {
            HStack(spacing: 0) {
                ForEach(pages) { page in
                    HStack(spacing: 4) {
                        ForEach(page.dates, id: \.self) { date in
                            TodayDateChip(
                                weekday: weekday(for: date),
                                day: calendar.component(.day, from: date),
                                month: month(for: date),
                                isSelected: calendar.isDate(date, inSameDayAs: selectedDate)
                            ) {
                                selectedDate = date
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 3)
                    .padding(.bottom, 5)
                    .containerRelativeFrame(.horizontal)
                    .id(page.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $visiblePage, anchor: .center)
        .defaultScrollAnchor(.center)
        .scrollIndicators(.hidden)
        // The seven fixed columns need a bounded visual size; VoiceOver still reads each full date.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: firstDayOfWeek) {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visibleWeekStart = nil
                visiblePage = 0
            }
        }
        .onScrollPhaseChange { _, phase in
            guard phase == .idle,
                  let visiblePage,
                  visiblePage != 0,
                  let start = pages.first(where: { $0.id == visiblePage })?.dates.first
            else { return }

            // Reuse the same three pages only after the swipe has settled.
            // Updating the dates and position together keeps recentering invisible.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                visibleWeekStart = start
                self.visiblePage = 0
            }
        }
        .accessibilityLabel("Week dates")
        .accessibilityIdentifier(Accessibility.todayWeekPager)
    }

    private func weekday(for date: Date) -> String {
        calendar.shortWeekdaySymbols[
            calendar.component(.weekday, from: date) - 1
        ]
    }

    private func month(for date: Date) -> String {
        date.formatted(
            Date.FormatStyle(
                locale: calendar.locale ?? .current,
                calendar: calendar,
                timeZone: calendar.timeZone
            ).month(.abbreviated)
        )
    }
}

private struct TodayDateChip: View {
    let weekday: String
    let day: Int
    let month: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var weekdaySize: CGFloat = 11
    @ScaledMetric(relativeTo: .body) private var daySize: CGFloat = 17
    @ScaledMetric(relativeTo: .caption2) private var monthSize: CGFloat = 10
    @ScaledMetric(relativeTo: .body) private var dateDiameter: CGFloat = 29

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(weekday), \(month) \(day)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var content: some View {
        VStack(spacing: 2) {
            Text(weekday)
                .font(.system(size: weekdaySize))
                .frame(minHeight: 14)

            Text(day, format: .number.grouping(.never))
                .font(.system(size: daySize, weight: .semibold))
                .foregroundStyle(isSelected ? DWColor.white : DWColor.label)
                .frame(width: dateDiameter, height: dateDiameter)
                .background {
                    if isSelected {
                        Circle().fill(DWColor.accent(colorScheme))
                    }
                }

            Text(month)
                .font(.system(size: monthSize, weight: .medium))
                .frame(minHeight: 12)
        }
        .foregroundStyle(isSelected ? DWColor.accent(colorScheme) : DWColor.secondary(colorScheme))
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(DWColor.accentSoft)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    @Previewable @State var selectedDate: Date = .now

    VStack(spacing: 8) {
        TodayDateStrip(selectedDate: $selectedDate)
    }
}
