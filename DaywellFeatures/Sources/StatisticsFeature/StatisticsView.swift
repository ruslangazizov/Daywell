import ComposableArchitecture
import SwiftUI

public struct StatisticsView: View {
    @Bindable var store: StoreOf<StatisticsReducer>

    public init(store: StoreOf<StatisticsReducer>) {
        self.store = store
    }

    public var body: some View {
        Text("Statistics")
    }
}
