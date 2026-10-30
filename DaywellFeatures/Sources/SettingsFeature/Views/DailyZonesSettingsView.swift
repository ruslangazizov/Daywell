import DesignSystem
import Domain
import SwiftUI

struct DailyZonesSettingsView: View {
    let zones: [DayZone]
    let onAddZone: () -> Void
    let onEditZone: (UUID) -> Void
    let onDeleteZone: (UUID) -> Void
    let onRestoreDefaultZones: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily zones")
                    .font(.body)
                    .accessibilityAddTraits(.isHeader)

                if zones.isEmpty {
                    explanation("No zones yet. Add a zone to give part of your day its own focus.")
                } else {
                    // TODO: перенести эту логику в редьюсер
                    let sortedZones = zones.sorted { $0.window.start < $1.window.start }
                    VStack(spacing: 0) {
                        ForEach(sortedZones) { zone in
                            zoneRow(zone)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        withAnimation {
                                            onDeleteZone(zone.id)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                            .labelStyle(IconOnlyLabelStyle())
                                    }
                                }

                            if zone.id != sortedZones.last?.id { Divider() }
                        }
                    }
                }

                Button(action: onAddZone) {
                    Label("Add zone", systemImage: "plus")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(DWColor.accent(colorScheme))
                .accessibilityIdentifier(Accessibility.addZone)

                explanation("Tasks appear in every zone their time overlaps. Tasks without a matching zone appear in No zone.\nZones can have gaps, but cannot overlap.")

                let gaps = DailyZonesFormatting.gaps(in: zones)
                if zones.isEmpty {
                    explanation("No active zone: all day")
                } else if gaps.isEmpty {
                    explanation("Your zones cover the whole day.")
                } else {
                    explanation("No active zone: " + gaps.map {
                        DailyZonesFormatting.interval($0, locale: locale)
                    }.joined(separator: ", "))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .settingBackground()

            Button(action: onRestoreDefaultZones) {
                Text("Restore default zones")
                    .frame(maxWidth: .infinity, minHeight: 24, alignment: .leading)
                    .padding(16)
                    .contentShape(Rectangle())
            }
            .foregroundStyle(DWColor.accent(colorScheme))
            .settingBackground()
            .accessibilityIdentifier(Accessibility.restoreZones)
        }
        .font(.body)
        .buttonStyle(.plain)
        .tint(DWColor.accent(colorScheme))
    }

    private func zoneRow(_ zone: DayZone) -> some View {
        Button {
            onEditZone(zone.id)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: DailyZonesFormatting.symbol(for: zone))
                    .font(.title3)
                    .foregroundStyle(DWColor.accent(colorScheme))
                    .frame(width: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name)
                        .foregroundStyle(DWColor.label)
                    Text(DailyZonesFormatting.interval(zone.window, locale: locale)
                         + (zone.window.crossesMidnight ? " · next day" : ""))
                        .font(.footnote)
                        .foregroundStyle(DWColor.secondary(colorScheme))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DWColor.secondary(colorScheme))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit zone")
        .accessibilityIdentifier(Accessibility.zone(zone.id.uuidString))
    }

    private func explanation(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(DWColor.secondary(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Daily zones · Light") {
    DailyZonesSettingsView(
        zones: DayZone.defaults,
        onAddZone: {},
        onEditZone: { _ in },
        onDeleteZone: { _ in },
        onRestoreDefaultZones: {}
    )
    .padding()
    .background(DWColor.grouped(.light))
}

#Preview("Daily zones · Empty · Dark · Larger text") {
    DailyZonesSettingsView(
        zones: [],
        onAddZone: {
        },
        onEditZone: { _ in },
        onDeleteZone: { _ in },
        onRestoreDefaultZones: {}
    )
    .padding()
    .background(DWColor.grouped(.dark))
    .preferredColorScheme(.dark)
    .environment(\.dynamicTypeSize, .accessibility2)
}
