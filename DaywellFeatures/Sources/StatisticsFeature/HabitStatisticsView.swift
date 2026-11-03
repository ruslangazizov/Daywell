import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Presents habit statistics inside the caller's navigation stack.
public struct HabitStatisticsView: View {
    let store: StoreOf<StatisticsReducer>
    let habitID: UUID
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<StatisticsReducer>, habitID: UUID) {
        self.store = store
        self.habitID = habitID
    }

    public var body: some View {
        Group {
            if store.hasLoaded {
                detail(.habit(habitID))
            } else if store.errorMessage == nil {
                ProgressView("Loading statistics")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Statistics unavailable", systemImage: "chart.bar.xaxis")
            }
        }
        .safeAreaInset(edge: .top) {
            if let error = store.errorMessage {
                VStack(spacing: 8) {
                    Text(store.hasLoaded ? error : "Couldn’t load statistics.")
                    Button("Retry") { store.send(.task) }
                        .frame(minHeight: 44)
                }
                .font(.subheadline)
                .padding()
                .accessibilityIdentifier("statistics.error")
            }
        }
        .background(DWColor.bg(colorScheme))
        .toolbar(.visible, for: .navigationBar)
        .task { await store.send(.task).finish() }
        .task { await store.send(.startClock).finish() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.send(.task) }
        }
    }

    private func detail(_ destination: StatisticsDestination) -> some View {
        StatisticsDetailView(
            destination: destination,
            summary: store.summary,
            planTask: { store.send(.planTask($0)) },
            editHabit: { store.send(.editHabit($0)) }
        )
    }
}
