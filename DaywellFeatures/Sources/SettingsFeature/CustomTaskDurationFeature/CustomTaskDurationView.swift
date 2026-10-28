import ComposableArchitecture
import DesignSystem
import SwiftUI

struct CustomTaskDurationView: View {
    @Bindable var store: StoreOf<CustomTaskDurationReducer>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose a window for new tasks.")
                        .font(.subheadline)
                        .foregroundStyle(DWColor.secondary(colorScheme))

                    HStack(spacing: 16) {
                        durationWheel(
                            title: "Hours",
                            values: store.hourOptions,
                            selection: $store.hours.sending(\.didChooseHours)
                        )
                        durationWheel(
                            title: "Minutes",
                            values: 0...59,
                            selection: $store.minutes.sending(\.didChooseMinutes)
                        )
                    }

                    VStack(spacing: 12) {
                        Text(store.duration.title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(DWColor.label)
                            .accessibilityIdentifier(Accessibility.customDurationSummary)

                        Text(store.canSave
                             ? "Saved as an option and selected for new tasks."
                             : "Choose a duration longer than 0 minutes.")
                            .font(.footnote)
                            .foregroundStyle(DWColor.secondary(colorScheme))
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .background(DWColor.grouped(colorScheme))
            .navigationTitle("Custom duration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.didTapCancel)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.didTapSave)
                    }
                    .disabled(!store.canSave)
                }
            }
        }
        .tint(DWColor.accent(colorScheme))
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(500), .large])
        .presentationDragIndicator(.hidden)
    }

    private func durationWheel(
        title: LocalizedStringKey,
        values: ClosedRange<Int>,
        selection: Binding<Int>
    ) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .textCase(.uppercase)
                .font(.caption2)
                .foregroundStyle(DWColor.secondary(colorScheme))
                .accessibilityHidden(true)

            Picker(title, selection: selection) {
                ForEach(values, id: \.self) { value in
                    Text(value.formatted()).tag(value)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .clipped()
        }
        .frame(maxWidth: .infinity)
    }
}
