import ComposableArchitecture
import DesignSystem
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
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                TodayHeader {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                        store.send(.todayButtonTapped)
                        proxy.scrollTo(store.timeline.scrollTargetID, anchor: .top)
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
                        Button("Retry") { store.send(.task) }
                    }
                    .padding()
                }

                if store.isLoading {
                    ProgressView("Loading tasks")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.hasLoadedData {
                    TodayTimelineView(model: store.timeline) { id, completed in
                        store.send(.completionChanged(id, completed))
                    }
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
                proxy.scrollTo(store.timeline.scrollTargetID, anchor: .top)
            }
            .onChange(of: store.hasLoadedData) {
                proxy.scrollTo(store.timeline.scrollTargetID, anchor: .top)
            }
        }
        .background(DWColor.bg(colorScheme).ignoresSafeArea())
        .tint(DWColor.accent(colorScheme))
        .task { await store.send(.task).finish() }
        .task { await store.send(.startClock).finish() }
        .onChange(of: scenePhase) {
            if scenePhase == .active { store.send(.clockTick) }
        }
    }
}

#Preview("Today") {
    TasksTodayView(
        store: Store(initialState: TasksReducer.State()) {
            TasksReducer()
        }
    )
}
