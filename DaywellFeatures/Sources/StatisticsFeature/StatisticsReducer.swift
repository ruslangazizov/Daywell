import ComposableArchitecture

public struct StatisticsReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        public init() {}
    }

    @CasePathable
    public enum Action {}

    public var body: some Reducer<State, Action> {
        EmptyReducer()
    }

    public init() {}
}
