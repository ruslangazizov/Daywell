import ComposableArchitecture

public enum AppBootstrap {
    public static func makeStore() -> StoreOf<RootReducer> {
        return Store(initialState: RootReducer.State()) {
            RootReducer()
#if DEBUG
                ._printChanges()
#endif
        }
    }
}
