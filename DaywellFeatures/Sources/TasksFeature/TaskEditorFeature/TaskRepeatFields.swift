import Domain
import ComposableArchitecture
import DesignSystem
import Persistence
import SwiftUI

struct TaskRepeatFields: View {
    @Binding var draft: TaskEditorDraft
    let calendar: Calendar
    @SharedReader(Preferences.firstDayOfWeek) private var firstDayOfWeek
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Picker("Frequency", selection: $draft.frequency) {
            ForEach(TaskEditorDraft.Frequency.allCases, id: \.self) { frequency in
                Text(frequency.rawValue).tag(frequency)
            }
        }
        Stepper("Every \(draft.interval) \(draft.frequency.rawValue.lowercased())",
                value: $draft.interval, in: 1...99)
        if draft.frequency == .weekly {
            // A wrapping grid remains usable with larger accessibility text sizes.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 58))], spacing: 8) {
                ForEach(orderedWeekdays, id: \.self) { day in
                    Button {
                        if !draft.weekdays.insert(day).inserted { draft.weekdays.remove(day) }
                    } label: {
                        Text(calendar.shortWeekdaySymbols[day.rawValue - 1])
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(draft.weekdays.contains(day) ? DWColor.accentSoft : .clear,
                                        in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(draft.weekdays.contains(day) ? DWColor.accent(colorScheme) : .secondary)
                    .accessibilityLabel(calendar.weekdaySymbols[day.rawValue - 1])
                    .accessibilityAddTraits(draft.weekdays.contains(day) ? .isSelected : [])
                }
            }
        }
        if draft.frequency == .monthly {
            Picker("Day of month", selection: $draft.monthDay) {
                ForEach(1...31, id: \.self) { Text("\($0)").tag($0) }
            }
        }
    }

    private var orderedWeekdays: [Weekday] {
        let first = switch firstDayOfWeek {
        case .system: calendar.firstWeekday
        case .sunday: 1
        case .monday: 2
        case .tuesday: 3
        case .wednesday: 4
        case .thursday: 5
        case .friday: 6
        case .saturday: 7
        }
        return (0..<7).compactMap { Weekday(rawValue: (first - 1 + $0) % 7 + 1) }
    }
}
