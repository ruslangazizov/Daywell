import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

public struct TasksTodayView: View {
    @Bindable var store: StoreOf<TasksReducer>

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<TasksReducer>) {
        self.store = store
    }

    public var body: some View {
        todayContent
            .tint(DWColor.accent(colorScheme))
            .task { await store.send(.task).finish() }
            .task { await store.send(.startClock).finish() }
            .onChange(of: scenePhase) {
                if scenePhase == .active { store.send(.clockTick) }
            }
    }

    private var todayContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                TodayHeader {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        store.send(.todayButtonTapped)
                        if store.todayLayout != .zones {
                            proxy.scrollTo(store.scrollTargetID, anchor: .top)
                        }
                    }
                }

                TodayDateStrip(selectedDate: $store.selectedDate.sending(\.dateStripTapped))
                    .id(store.dateStripResetID)
                    .transition(.opacity)

                if let completionSummary = store.completionSummary {
                    TodayCompletionSummary(model: completionSummary)
                }

                if let errorMessage = store.errorMessage {
                    VStack(spacing: 8) {
                        Text(errorMessage).font(.footnote)
                        if store.hasLoadedData {
                            Button("Dismiss") { store.send(.dismissError) }
                        } else {
                            Button("Retry") { store.send(.task) }
                        }
                    }
                    .padding()
                }

                if store.isLoading {
                    ProgressView("Loading tasks")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.hasLoadedData {
                    tasksContent
                        .overlay(alignment: .bottomTrailing) {
                            TodayAddTaskButton {
                                store.send(.addTaskButtonTapped)
                            }
                            .padding(.trailing, 21)
                            .padding(.bottom, 15)
                        }
                } else {
                    Spacer()
                }
            }
            .onChange(of: store.selectedLocalDate) {
                if store.todayLayout != .zones { proxy.scrollTo(store.scrollTargetID, anchor: .top) }
            }
            .onChange(of: store.todayLayout) {
                if store.todayLayout != .zones { proxy.scrollTo(store.scrollTargetID, anchor: .top) }
            }
            .onChange(of: store.hasLoadedData) {
                if store.todayLayout != .zones { proxy.scrollTo(store.scrollTargetID, anchor: .top) }
            }
        }
        .background(DWColor.bg(colorScheme).ignoresSafeArea())
    }

    @ViewBuilder
    private var tasksContent: some View {
        let timeline = store.timeline
        switch store.todayLayout {
        case .timeline:
            TodayTimelineView(model: timeline, onOpen: { store.send(.detailsChanged($0)) }, onCompletionChanged: completeTask)
        case .agenda:
            TodayAgendaView(
                model: TodayListViewModel(timeline: timeline, zones: store.zones),
                onOpen: { store.send(.detailsChanged($0)) },
                onCompletionChanged: completeTask
            )
        case .zones:
            TodayZonesView(
                model: TodayZonesViewModel(timeline: timeline, zones: store.zones),
                onOpen: { store.send(.detailsChanged($0)) },
                onCompletionChanged: completeTask,
                onAddTask: { store.send(.addTaskButtonTapped) }
            )
            .id(ZonesIdentity(day: store.selectedLocalDate, resetID: store.zonesResetID))
        }
    }

    private struct ZonesIdentity: Hashable {
        let day: LocalDate?
        let resetID: UUID
    }

    private func completeTask(_ id: TaskOccurrenceID, _ completed: Bool) {
        store.send(.completionChanged(id, completed))
    }
}

#Preview("Today") {
    let store = Store(initialState: TasksReducer.State()) { TasksReducer() }
    TasksNavigationView(store: store) {
        TasksTodayView(store: store)
    } habitStatistics: { _ in
        Text("Habit statistics")
    }
}
