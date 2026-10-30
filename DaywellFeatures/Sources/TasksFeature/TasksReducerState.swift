import Foundation
import Domain
import Persistence
import ComposableArchitecture

extension TasksReducer {
    @ObservableState
    public struct State: Equatable {
        var selectedDate: Date
        var selectedLocalDate: LocalDate?
        var dateStripResetID = UUID()
        var zonesResetID = UUID()
        var tasks: [DWTask]
        var tasksOccurrences: IdentifiedArrayOf<OccurrenceRecord>
        @SharedReader(Preferences.todayLayout) var todayLayout
        @SharedReader(Preferences.dailyZones) var zones
        var now: Date
        var calendar: Calendar
        var hasLoadedData: Bool
        var isLoading = false
        var errorMessage: String?

        public init(
            selectedDate: Date = .now,
            selectedLocalDate: LocalDate? = nil,
            tasks: [DWTask] = [],
            tasksOccurrences: IdentifiedArrayOf<OccurrenceRecord> = [],
            zones: [DayZone]? = nil,
            now: Date? = nil,
            calendar: Calendar = .current,
            hasLoadedData: Bool? = nil
        ) {
            self.selectedDate = selectedDate
            self.selectedLocalDate = selectedLocalDate ?? (try? LocalDate(selectedDate, in: calendar.timeZone))
            self.tasks = tasks
            self.tasksOccurrences = tasksOccurrences
            if let zones { self._zones = SharedReader(value: zones) }
            self.now = now ?? selectedDate
            self.calendar = calendar
            self.hasLoadedData = hasLoadedData ?? !tasks.isEmpty
        }

        var scheduledTasks: [DWTask] {
            guard let day = selectedLocalDate else { return [] }
            return tasks.filter { !$0.isArchived && $0.schedule.occurs(on: day) }
        }

        var completionSummary: TodayCompletionSummaryModel? {
            guard todayLayout == .timeline, hasLoadedData, let today = selectedLocalDate else { return nil }

            let tasksForToday = scheduledTasks
            let completedTasksCount = tasksForToday.count { task in
                let id = TaskOccurrenceID(taskID: task.id, day: today)
                return tasksOccurrences[id: id]?.isCompleted == true
            }
            return TodayCompletionSummaryModel(
                completedCount: completedTasksCount,
                totalCount: tasksForToday.count
            )
        }

        var timeline: TodayTimelineViewModel {
            TodayTimelineViewModel(
                tasks: scheduledTasks,
                day: selectedLocalDate,
                occurrences: tasksOccurrences,
                todayLayout: todayLayout,
                now: now,
                calendar: calendar
            )
        }

        var scrollTargetID: String {
            switch todayLayout {
            case .timeline:
                return timeline.scrollTargetID
            case .agenda:
                return TodayListViewModel(timeline: timeline, zones: zones).agendaScrollTargetID
            case .zones:
                return TodayListViewModel(timeline: timeline, zones: zones).zonesScrollTargetID
            }
        }
    }
}
