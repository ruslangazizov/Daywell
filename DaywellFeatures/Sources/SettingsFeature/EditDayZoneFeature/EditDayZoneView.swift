import ComposableArchitecture
import DesignSystem
import Domain
import SwiftUI

struct EditDayZoneView: View {
    @Bindable var store: StoreOf<EditDayZoneReducer>
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Zone name", text: $store.name.sending(\.didChangeName))
                        .textInputAutocapitalization(.words)
                        .accessibilityIdentifier(Accessibility.zoneName)
                }
                .listRowBackground(DWColor.group)

                Section {
                    DatePicker("Starts", selection: timeBinding(
                        $store.start.sending(\.didChangeStart)
                    ), displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: timeBinding(
                        $store.end.sending(\.didChangeEnd)
                    ), displayedComponents: .hourAndMinute)
                    Toggle("Ends next day", isOn: $store.endsNextDay.sending(\.didChangeEndsNextDay))
                } header: {
                    Text("Time window")
                } footer: {
                    Text("Zones can have gaps, but cannot overlap. Enable Ends next day for an overnight zone.")
                }
                .listRowBackground(DWColor.group)

                if let message = store.saveError ?? store.validationMessage {
                    Section {
                        Text(message)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier(Accessibility.zoneValidation)
                    }
                    .listRowBackground(DWColor.group)
                }
            }
            .environment(\.calendar, DailyZonesFormatting.calendar)
            .environment(\.timeZone, DailyZonesFormatting.calendar.timeZone)
            .scrollContentBackground(.hidden)
            .background(DWColor.grouped(colorScheme))
            .navigationTitle(store.isNew ? "Add zone" : "Edit zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { store.send(.didTapCancel) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { store.send(.didTapSave) }
                        .disabled(!store.canSave)
                }
            }
        }
        .tint(DWColor.accent(colorScheme))
    }

    private func timeBinding(_ time: Binding<LocalTime>) -> Binding<Date> {
        Binding(
            get: { DailyZonesFormatting.date(for: time.wrappedValue) },
            set: { time.wrappedValue = DailyZonesFormatting.time(from: $0) }
        )
    }
}
