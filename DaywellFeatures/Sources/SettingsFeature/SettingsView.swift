import ComposableArchitecture
import DesignSystem
import SwiftUI
import Domain

public struct SettingsView: View {
    @Bindable var store: StoreOf<SettingsReducer>

    public init(store: StoreOf<SettingsReducer>) {
        self.store = store
    }

    @Environment(\.colorScheme) private var colorScheme

    public var body: some View {
        NavigationStack {
            ZStack {
                DWColor.grouped(colorScheme).ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        block(title: "APPEARANCE") {
                            ChoiceControl(
                                options: DWAppearance.allCases,
                                selection: $store.appearance.sending(\.didChooseAppearance),
                                isStacked: true,
                                title: { $0.title },
                                icon: { $0.icon }
                            )
                        }

                        block(title: "TODAY VIEW") {
                            ChoiceControl(
                                options: TodayLayout.allCases,
                                selection: $store.todayLayout.sending(\.didChooseTodayLayout),
                                isStacked: false,
                                title: { $0.title },
                                icon: { $0.icon }
                            )
                        } footer: {
                            switch store.todayLayout {
                            case .timeline:
                                CardWidthSettingsView(
                                    percentage: $store.customCardWidthPercentage
                                        .sending(\.didChooseCustomCardWidthPercentage)
                                )
                            case .agenda:
                                explanation("Tasks are shown in a chronological list")
                            case .zones:
                                DailyZonesSettingsView(
                                    zones: store.sortedDailyZones,
                                    onAddZone: { store.send(.dailyZones(.didTapAdd)) },
                                    onEditZone: { store.send(.dailyZones(.didTapZone($0))) },
                                    onDeleteZone: { store.send(.dailyZones(.didTapDelete($0))) },
                                    onRestoreDefaultZones: { store.send(.dailyZones(.didTapRestoreDefaults)) }
                                )
                            }
                        }

                        block(title: "PLANNING") {
                            PlanningSettingsView(
                                firstDayOfWeek: $store.firstDayOfWeek
                                    .sending(\.didChooseFirstDayOfWeek),
                                taskDurations: store.taskDurations,
                                defaultTaskDuration: $store.defaultTaskDuration
                                    .sending(\.taskDuration.didChooseDefault),
                                onCustomDuration: {
                                    store.send(.taskDuration(.didTapCustom))
                                }
                            )
                        } footer: {
                            explanation("Applies only to new tasks and can be changed")
                        }

                        block(title: "NOTIFICATIONS") {
                            NotificationsSettingsView(
                                taskRemindersEnabled: $store.taskRemindersEnabled
                                    .sending(\.didChangeTaskRemindersEnabled),
                                appIconBadgeEnabled: $store.appIconBadgeEnabled
                                    .sending(\.didChangeAppIconBadgeEnabled)
                            )
                        } footer: {
                            explanation(
                                "Turning reminders off keeps their times in your tasks. The badge hides when nothing is left."
                            )
                        }

                        block(title: "ICLOUD") {
                            ICloudSettingsView(
                                status: store.iCloudStatus,
                                lastConfirmedSync: store.lastConfirmedSync,
                                onCheckStatus: {
                                    store.send(.didTapCheckICloudStatus)
                                }
                            )
                        } footer: {
                            explanation(
                                "Changes are saved on this device first. Checking status does not force a sync."
                            )
                        }
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .navigationTitle("Settings")
        }
        .sheet(item: $store.scope(state: \.customTaskDuration, action: \.taskDuration.custom)) { store in
            CustomTaskDurationView(store: store)
        }
        .sheet(item: $store.scope(state: \.editDayZone, action: \.dailyZones.editor)) { store in
            EditDayZoneView(store: store)
        }
        .confirmationDialog($store.scope(state: \.zonesConfirmation, action: \.dailyZones.confirmation))
    }

    private func explanation(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(DWColor.secondary(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func block<Content: View, Footer: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            content()

            footer()
        }
        .frame(maxWidth: .infinity)
    }
}
