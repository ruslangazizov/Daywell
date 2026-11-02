import ComposableArchitecture
import DesignSystem
import Domain
import Persistence
import SwiftUI

struct TaskEditorView: View {
    @Bindable var store: StoreOf<TaskEditorReducer>
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var focusedField: Field?
    private enum Field { case title, notes }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task name", text: $store.draft.title, axis: .vertical)
                        .lineLimit(1...3)
                        .focused($focusedField, equals: .title)
                        .accessibilityIdentifier(Accessibility.taskEditorTitle)
                }
                .listRowBackground(DWColor.group)

                Section {
                    TextField("Description (optional)", text: $store.draft.notes, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($focusedField, equals: .notes)
                        .accessibilityIdentifier(Accessibility.taskEditorNotes)
                }
                .listRowBackground(DWColor.group)

                timeSection
                scheduleSection

                Section("Personalize") {
                    TaskColorPicker(selection: $store.draft.color)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))

                if let message = store.saveError ?? store.validationMessage,
                   !store.draft.title.isEmpty || store.saveError != nil {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier(Accessibility.taskEditorError)
                    }
                    .listRowBackground(DWColor.group)
                }

                Section {
                    Button(action: save) {
                        HStack {
                            Spacer()
                            if store.isSaving { ProgressView().tint(.white) }
                            Text(store.isEditing ? "Save changes" : (store.draft.isHabit ? "Add habit" : "Add task"))
                                .fontWeight(.semibold)
                            Image(systemName: "checkmark")
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .disabled(!store.canSave)
                    .accessibilityIdentifier(Accessibility.taskEditorAdd)
                } header: {
                    Text("Time windows can overlap. Choose what feels right when the time comes.")
                        .textCase(nil)
                        .padding(.bottom, 8)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .disabled(store.isSaving)
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background(DWColor.grouped(colorScheme))
            .navigationTitle(store.isEditing
                             ? (store.draft.isHabit ? "Edit habit" : "Edit task")
                             : (store.draft.isHabit ? "New habit" : "New task"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { store.send(.cancelTapped) }
                        .labelStyle(.iconOnly)
                        .disabled(store.isSaving)
                        .accessibilityIdentifier(Accessibility.taskEditorCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", systemImage: "checkmark", action: save)
                        .labelStyle(.iconOnly)
                        .disabled(!store.canSave)
                        .accessibilityIdentifier(Accessibility.taskEditorSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .tint(DWColor.accent(colorScheme))
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled(store.hasChanges || store.isSaving)
        .confirmationDialog($store.scope(state: \.discardConfirmation, action: \.discardConfirmation))
    }

    private var timeSection: some View {
        Section {
            Toggle("Time window", isOn: $store.draft.hasTimeWindow)
                .accessibilityIdentifier(Accessibility.taskEditorTimeWindow)
            if store.draft.hasTimeWindow {
                TaskTimePicker(title: "Starts", time: $store.draft.start)
                TaskTimePicker(title: "Ends", time: $store.draft.end)
                Toggle("Ends next day", isOn: $store.draft.endsNextDay)
            }
        } header: {
            Text("Time window")
        } footer: {
            if !store.draft.hasTimeWindow {
                Text("Do this task at any time during the day.")
            } else if store.draft.endsNextDay {
                Text("This window ends the following day. The task stays on its start date.")
            }
        }
        .listRowBackground(DWColor.group)
    }

    private var scheduleSection: some View {
        Section {
            Picker("Repeat", selection: $store.draft.repeatOption) {
                ForEach(TaskEditorDraft.RepeatOption.allCases, id: \.self) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .accessibilityIdentifier(Accessibility.taskEditorRepeat)

            DatePicker(store.draft.isHabit ? "Starts on" : "Date",
                       selection: $store.draft.scheduledDate, displayedComponents: .date)
            if store.draft.repeatOption == .custom {
                TaskRepeatFields(draft: $store.draft, calendar: store.calendar)
            }
            if store.draft.isHabit {
                Toggle("End repeat", isOn: $store.draft.hasEndDate)
                if store.draft.hasEndDate {
                    DatePicker("Ends on", selection: $store.draft.endDate,
                               in: store.calendar.startOfDay(for: store.draft.scheduledDate)...,
                               displayedComponents: .date)
                }
            }
        } header: {
            Text("Schedule")
        } footer: {
            if store.draft.isHabit {
                Text(store.isEditing
                     ? "Changes apply to the whole habit. Recorded completions are kept."
                     : "A task that repeats is a habit.")
                if store.draft.repeatOption == .monthly ||
                    (store.draft.repeatOption == .custom && store.draft.frequency == .monthly) {
                    Text("Months without the selected day are skipped.")
                }
            }
        }
        .listRowBackground(DWColor.group)
    }

    private func save() {
        focusedField = nil
        store.send(.saveTapped)
    }
}

private struct TaskTimePicker: View {
    let title: String
    @Binding var time: LocalTime

    // A fixed day in UTC lets DatePicker edit wall-clock values even on DST days.
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    var body: some View {
        DatePicker(title, selection: Binding(
            get: { Date(timeIntervalSinceReferenceDate: Double(time.minutesSinceMidnight * 60)) },
            set: { time = try! LocalTime(hour: calendar.component(.hour, from: $0),
                                        minute: calendar.component(.minute, from: $0)) }
        ), displayedComponents: .hourAndMinute)
        .environment(\.calendar, calendar)
        .environment(\.timeZone, calendar.timeZone)
    }
}

#Preview("New task") {
    TaskEditorView(store: Store(initialState: TaskEditorReducer.State(
        id: UUID(), selectedDate: .now, now: .now, calendar: .current, duration: .defaultValue
    )) { TaskEditorReducer() })
}

#Preview("Habit · Dark") {
    let state = TaskEditorReducer.State(
        id: UUID(), selectedDate: .now, now: .now, calendar: .current, duration: .defaultValue
    )
    TaskEditorView(store: Store(initialState: {
        var state = state
        state.draft.title = "Language practice"
        state.draft.repeatOption = .custom
        state.draft.weekdays = [.monday, .wednesday, .friday]
        return state
    }()) { TaskEditorReducer() })
    .preferredColorScheme(.dark)
}
