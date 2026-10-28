import ComposableArchitecture
import SwiftUI

public struct TasksHabitsView: View {
    let store: StoreOf<TasksReducer>

    public init(store: StoreOf<TasksReducer>) {
        self.store = store
    }

    public var body: some View {
        EmptyView()
    }
}
