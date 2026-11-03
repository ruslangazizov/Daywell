import ComposableArchitecture
import DesignSystem
import SwiftUI

/// Keep the tab view in the root destination so its tab bar participates in
/// the push and interactive back transitions together with the Today screen.
public struct TasksNavigationView<Root: View, HabitStatistics: View>: View {
    @Bindable private var store: StoreOf<TasksReducer>
    @Environment(\.colorScheme) private var colorScheme
    private let root: Root
    private let habitStatistics: (UUID) -> HabitStatistics

    public init(
        store: StoreOf<TasksReducer>,
        @ViewBuilder root: () -> Root,
        @ViewBuilder habitStatistics: @escaping (UUID) -> HabitStatistics
    ) {
        self.store = store
        self.root = root()
        self.habitStatistics = habitStatistics
    }

    public var body: some View {
        NavigationStack {
            root
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(item: $store.detailsID.sending(\.detailsChanged)) { id in
                    TaskDetailsDestination(store: store, id: id)
                        .navigationDestination(item: $store.habitStatisticsID.sending(\.habitStatisticsChanged)) { taskID in
                            habitStatistics(taskID)
                        }
                }
        }
        .tint(DWColor.accent(colorScheme))
        .sheet(item: $store.scope(state: \.taskEditor, action: \.taskEditor)) { editorStore in
            TaskEditorView(store: editorStore)
        }
    }
}
