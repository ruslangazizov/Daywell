import ComposableArchitecture

public enum AppBootstrap {
    public static func makeStore() -> StoreOf<RootReducer> {
        // Условная фабрика нашего Persistence-модуля.
//        let dataClient = PersistenceFactory.makeDataClient()

        return Store(initialState: RootReducer.State()) {
            RootReducer()
#if DEBUG
                ._printChanges()
#endif
        }
//        withDependencies: {
//            $0.dataClient = dataClient
//        }
    }
}
