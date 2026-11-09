import SwiftUI
import DesignSystem
import Persistence

struct ICloudSettingsView: View {
    let status: ICloudSyncStatus
    let isChecking: Bool
    let lastConfirmedSync: Date?
    let onCheckStatus: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Text(status.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(DWColor.label)
                        .accessibilityIdentifier(Accessibility.iCloudStatus)
                    if status == .syncing {
                        ProgressView()
                            .tint(DWColor.accent(colorScheme))
                    }
                }

                Text(status.description)
                    .font(.footnote)
                    .foregroundStyle(DWColor.secondary(colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if status == .available || status == .notChecked {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent {
                        Text(status == .available ? "Available" : "Not checked")
                            .foregroundStyle(DWColor.accent(colorScheme))
                    } label: {
                        Text("Status")
                            .foregroundStyle(DWColor.label)
                    }
                    .font(.subheadline)

                    if status == .available {
                        lastSyncRow
                    }
                }
            } else if lastConfirmedSync != nil || status == .noConfirmedSync {
                lastSyncRow
            }

            Divider()
                .overlay(DWColor.separator)

            if isChecking || status == .checking {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(DWColor.accent(colorScheme))

                    Text("Checking status…")
                        .foregroundStyle(DWColor.secondary(colorScheme))
                }
                .font(.body)
                .frame(minHeight: 20)
                .accessibilityElement(children: .combine)
            } else {
                Button(action: onCheckStatus) {
                    Text("Check status")
                        .frame(
                            minHeight: 20,
                            alignment: .leading
                        )
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier(Accessibility.checkICloudStatus)
                .buttonStyle(.plain)
                .font(.body)
                .foregroundStyle(DWColor.accent(colorScheme))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .settingBackground()
    }

    private var lastSyncRow: some View {
        LabeledContent {
            if let lastConfirmedSync {
                Text(lastConfirmedSync, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .multilineTextAlignment(.trailing)
            } else {
                Text("Not yet")
            }
        } label: {
            Text("Last confirmed sync")
        }
        .font(.footnote)
        .foregroundStyle(DWColor.secondary(colorScheme))
    }
}
