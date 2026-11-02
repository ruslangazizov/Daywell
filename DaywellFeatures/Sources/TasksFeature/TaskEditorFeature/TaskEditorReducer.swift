import Clients
import ComposableArchitecture
import Domain
import Foundation
import Persistence

public struct TaskEditorReducer: Reducer {
    @ObservableState
    public struct State: Equatable {
        let id: UUID
        var draft: TaskEditorDraft
        let initialDraft: TaskEditorDraft
        let originalTask: DWTask?
        let calendar: Calendar
        var isSaving = false
        var saveError: String?
        @Presents var discardConfirmation: ConfirmationDialogState<Action.DiscardConfirmation>?

        init(id: UUID, selectedDate: Date, now: Date, calendar: Calendar, duration: TaskDuration) {
            self.originalTask = nil
            self.id = id
            self.calendar = calendar
            let draft = TaskEditorDraft(selectedDate: selectedDate, now: now, calendar: calendar, duration: duration)
            self.draft = draft
            initialDraft = draft
        }

        init(task: DWTask, calendar: Calendar) {
            id = task.id
            originalTask = task
            self.calendar = calendar
            let draft = TaskEditorDraft(task: task, calendar: calendar)
            self.draft = draft
            initialDraft = draft
        }

        var isEditing: Bool { originalTask != nil }
        var hasChanges: Bool { draft != initialDraft }
        var validationMessage: String? { draft.validationMessage(calendar: calendar) }
        var canSave: Bool { !isSaving && validationMessage == nil }
    }

    @CasePathable
    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case cancelTapped
        case saveTapped
        case saveResponse(Result<DWTask, Error>)
        case discardConfirmation(PresentationAction<DiscardConfirmation>)
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable { case didSave(DWTask) }
        @CasePathable
        public enum DiscardConfirmation { case discard }
    }

    @Dependency(\.tasksClient) var tasksClient
    @Dependency(\.date) var date
    @Dependency(\.dismiss) var dismiss

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                state.saveError = nil
                return .none
            case .cancelTapped:
                guard !state.isSaving else { return .none }
                guard state.hasChanges else { return .run { _ in await dismiss() } }
                state.discardConfirmation = ConfirmationDialogState {
                    TextState(state.isEditing ? "Discard changes?" : "Discard this task?")
                } actions: {
                    ButtonState(role: .destructive, action: .discard) { TextState("Discard changes") }
                    ButtonState(role: .cancel) { TextState("Keep editing") }
                } message: {
                    TextState("Your changes have not been saved.")
                }
                return .none
            case .discardConfirmation(.presented(.discard)):
                return .run { _ in await dismiss() }
            case .saveTapped:
                guard state.canSave else { return .none }
                do {
                    let task = try state.draft.task(id: state.id, now: date.now, calendar: state.calendar, original: state.originalTask)
                    state.isSaving = true
                    state.saveError = nil
                    return .run { send in
                        try await tasksClient.save(task)
                        await send(.saveResponse(.success(task)))
                    } catch: { error, send in
                        await send(.saveResponse(.failure(error)))
                    }
                } catch {
                    state.saveError = error.localizedDescription
                    return .none
                }
            case .saveResponse(.success(let task)):
                // Keep controls disabled until the parent consumes the saved task and closes the sheet.
                return .send(.delegate(.didSave(task)))
            case .saveResponse(.failure(let error)):
                state.isSaving = false
                state.saveError = error.localizedDescription
                return .none
            case .discardConfirmation, .delegate:
                return .none
            }
        }
        .ifLet(\.$discardConfirmation, action: \.discardConfirmation)
    }
}
