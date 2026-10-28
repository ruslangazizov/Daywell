import SwiftUI
import ComposableArchitecture
import TasksFeature
import SettingsFeature
import DesignSystem

public struct AppView: View {
    @Bindable private var store: StoreOf<RootReducer>
    @Environment(\.colorScheme) private var colorScheme

    public init(store: StoreOf<RootReducer>) {
        self.store = store
    }

    public var body: some View {
        TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
            Tab("Today", systemImage: "calendar", value: RootReducer.Tab.today) {
                TasksTodayView(
                    store: store.scope(
                        state: \.tasks,
                        action: \.tasks
                    )
                )
            }

            Tab("Habits", systemImage: "repeat", value: RootReducer.Tab.habits) {
                TasksHabitsView(
                    store: store.scope(
                        state: \.tasks,
                        action: \.tasks
                    )
                )
            }

            Tab("Settings", systemImage: "gear", value: RootReducer.Tab.settings) {
                SettingsView(
                    store: store.scope(
                        state: \.settings,
                        action: \.settings
                    )
                )
            }
        }
        .tint(DWColor.accent(colorScheme))
        .task {
            await store.send(.settings(.task)).finish()
        }
    }
}
