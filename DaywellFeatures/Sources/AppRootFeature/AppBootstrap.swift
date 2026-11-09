import ComposableArchitecture
import Clients

public enum AppBootstrap {
    public static func makeStore() -> StoreOf<RootReducer> {
        NotificationsClient.installDelegate()
        return Store(initialState: RootReducer.State()) {
            RootReducer()
#if DEBUG
                ._printChanges()
#endif
        }
    }
}
