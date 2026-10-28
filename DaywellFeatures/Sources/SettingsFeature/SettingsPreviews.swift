import ComposableArchitecture
import SwiftUI
import DesignSystem
import Persistence

#Preview("Settings · Dark") {
    @Shared(Preferences.todayLayout) var todayLayout

    SettingsView(
        store: Store(
            initialState: SettingsReducer.State(iCloudStatus: .noConfirmedSync)
        ) {
            SettingsReducer()
        }
    )
    .preferredColorScheme(.dark)
    .onAppear {
        $todayLayout.withLock {
            $0 = .zones
        }
    }
}

#Preview("Settings · Larger text") {
    SettingsView(
        store: Store(initialState: SettingsReducer.State()) {
            SettingsReducer()
        }
    )
    .environment(\.dynamicTypeSize, .accessibility2)
}

private struct ICloudStatesPreview: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(ICloudSyncStatus.allCases) { status in
                    ICloudSettingsView(
                        status: status,
                        lastConfirmedSync: status == .available || status == .syncing
                            ? Date(timeIntervalSince1970: 1_792_828_860)
                            : nil,
                        onCheckStatus: {}
                    )
                }
            }
            .padding()
        }
        .background(DWColor.grouped(colorScheme))
    }
}

#Preview("iCloud · All states") {
    ICloudStatesPreview()
}

private func customDurationPreview(minutes: Int) -> some View {
    var state = SettingsReducer.State()
    state.customTaskDuration = .init(duration: TaskDuration(minutes: minutes))
    return SettingsView(store: Store(initialState: state) { SettingsReducer() })
}

#Preview("Custom duration · Light") {
    customDurationPreview(minutes: 75)
        .preferredColorScheme(.light)
}

#Preview("Custom duration · Dark") {
    customDurationPreview(minutes: 75)
        .preferredColorScheme(.dark)
}

#Preview("Custom duration · Zero · Larger text") {
    customDurationPreview(minutes: 0)
        .environment(\.dynamicTypeSize, .accessibility2)
}
