import DesignSystem
import Domain
import SwiftUI

struct TodayZonesView: View {
    let model: TodayZonesViewModel
    let onCompletionChanged: (TaskOccurrenceID, Bool) -> Void
    let onAddTask: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var browsedZoneID: String?
    @State private var pullDistance: Double = 0
    @State private var isInteracting = false
    @State private var direction = ZoneDirection.next

    private var section: TodayZonesViewModel.Section? { model.section(browsing: browsedZoneID) }
    private var selectionID: String { section?.id ?? "between-zones" }
    private var armedDirection: ZoneDirection? {
        guard let direction = TodayZonePull.destination(distance: pullDistance),
              model.neighbor(of: section, direction: direction) != nil else { return nil }
        return direction
    }

    var body: some View {
        GeometryReader { container in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let previous = model.neighbor(of: section, direction: .previous) {
                        zoneCue(previous, direction: .previous)
                    }

                    if let section {
                        zoneHeader(section)
                        if section.tasks.isEmpty {
                            emptyZone
                        } else {
                            VStack(spacing: 12) {
                                ForEach(section.tasks) { task in
                                    TodayTaskCard(model: task, onCompletionChanged: onCompletionChanged)
                                }
                            }
                            if section.tasks.allSatisfy(\.isCompleted) {
                                Label("All set for this zone", systemImage: "checkmark.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(DWColor.secondary(colorScheme))
                            }
                        }
                    } else {
                        betweenZones
                    }

                    Spacer(minLength: 10)

                    if let next = model.neighbor(of: section, direction: .next) {
                        zoneCue(next, direction: .next)
                    } else {
                        Text("You're at the end of this day")
                            .font(.footnote)
                            .foregroundStyle(DWColor.secondary(colorScheme))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .padding(.horizontal, 60)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)
                .frame(minHeight: container.size.height, alignment: .top)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.always)
            .onScrollGeometryChange(for: Double.self) { geometry in
                Self.pullDistance(in: geometry)
            } action: { _, distance in
                if isInteracting { pullDistance = distance }
            }
            .onScrollPhaseChange { oldPhase, newPhase, context in
                isInteracting = newPhase == .interacting
                // A deceleration bounce must never navigate. Commit only at the finger's release.
                if oldPhase == .interacting, newPhase != .interacting {
                    let releaseDistance = Self.pullDistance(in: context.geometry)
                    pullDistance = 0
                    if newPhase == .decelerating || newPhase == .idle,
                       let direction = TodayZonePull.destination(distance: releaseDistance) {
                        navigate(direction)
                    }
                }
            }
            .accessibilityIdentifier(Accessibility.todayZones)
            .id(selectionID)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .move(edge: direction == .next ? .bottom : .top).combined(with: .opacity),
                removal: .opacity
            ))
        }
        .clipped()
        .sensoryFeedback(.selection, trigger: armedDirection) { _, newValue in newValue != nil }
        .onChange(of: selectionID) {
            pullDistance = 0
            isInteracting = false
        }
        .onChange(of: model.sections.map(\.id)) {
            if let browsedZoneID, !model.sections.contains(where: { $0.id == browsedZoneID }) {
                self.browsedZoneID = nil
            }
        }
    }

    private func zoneHeader(_ section: TodayZonesViewModel.Section) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    zoneTitle(section)
                    Spacer(minLength: 8)
                    completionCount(section)
                }
                VStack(alignment: .leading, spacing: 8) {
                    zoneTitle(section)
                    completionCount(section)
                }
            }
            if let window = section.window {
                Text(TodayZonesViewModel.intervalLabel(window))
                    .font(.subheadline)
                    .foregroundStyle(DWColor.secondary(colorScheme))
            } else {
                Text("Tasks outside your zones or without a time")
                    .font(.subheadline)
                    .foregroundStyle(DWColor.secondary(colorScheme))
            }
        }
    }

    private func zoneTitle(_ section: TodayZonesViewModel.Section) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 8))
        return layout {
            Text(section.title)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(Accessibility.todayZoneTitle)

            if section.isCurrent {
                Text("Now")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(section.isCurrent ? DWColor.accent(colorScheme) : DWColor.secondary(colorScheme))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(section.isCurrent ? DWColor.accentSoft : DWColor.secondary(colorScheme).opacity(0.08), in: Capsule())
                    .fixedSize()
                    .accessibilityIdentifier(Accessibility.todayZoneStatus)
            }
        }
    }

    private func completionCount(_ section: TodayZonesViewModel.Section) -> some View {
        Text("\(section.tasks.count { $0.isCompleted }) of \(section.tasks.count) done")
            .font(.caption.monospacedDigit())
            .foregroundStyle(DWColor.secondary(colorScheme))
            .fixedSize()
    }

    private var emptyZone: some View {
        ContentUnavailableView {
            Label("A little breathing room", systemImage: "sun.haze")
        } description: {
            Text("There are no tasks in this zone.")
        } actions: {
            Button("Add task", action: onAddTask)
                .buttonStyle(.bordered)
        }
    }

    private var betweenZones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.sections.isEmpty ? "No zones yet" : "Between zones")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier(Accessibility.todayZoneTitle)
            Text(model.gapDescription)
                .font(.subheadline)
                .foregroundStyle(DWColor.secondary(colorScheme))
            ContentUnavailableView(
                "Enjoy a little breathing room",
                systemImage: "moon.stars",
                description: Text("Your day doesn't have to be filled from end to end.")
            )
        }
    }

    private func zoneCue(_ destination: TodayZonesViewModel.Section, direction: ZoneDirection) -> some View {
        let distance = max(0, pullDistance * Double(direction.rawValue))
        let progress = min(1, distance / TodayZonePull.threshold)
        let hint = progress >= 1 ? "Release to open" : distance > 0 ? "Keep pulling" :
            direction == .next ? "Pull up to continue" : "Pull down to go back"

        return Button { navigate(direction) } label: {
            VStack(spacing: 5) {
                HStack(spacing: 4) {
                    Image(systemName: direction == .next ? "arrow.up" : "arrow.down")
                        .font(.system(size: 18, weight: .medium))
                        .frame(width: 30, height: 30)
                        .background {
                            Circle().trim(from: 0, to: progress)
                                .stroke(lineWidth: 2)
                                .rotationEffect(.degrees(-90))
                        }
                    Text(destination.title).font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(DWColor.secondary(colorScheme))
            }
            .foregroundStyle(DWColor.accent(colorScheme))
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: direction == .next ? 40 : 44)
            .background(progress >= 1 ? DWColor.accentSoft : .clear, in: RoundedRectangle(cornerRadius: 18))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, direction == .next ? 56 : 24)
        .accessibilityLabel("\(direction == .next ? "Next" : "Previous") zone: \(destination.title)")
        .accessibilityHint("Shows tasks in \(destination.title)")
        .accessibilityIdentifier(direction == .next ? Accessibility.todayNextZone : Accessibility.todayPreviousZone)
    }

    private func navigate(_ direction: ZoneDirection) {
        guard let destination = model.neighbor(of: section, direction: direction) else { return }

        self.direction = direction
        pullDistance = 0
        isInteracting = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            browsedZoneID = destination.id
        }
    }

    private nonisolated static func pullDistance(in geometry: ScrollGeometry) -> Double {
        TodayZonePull.distance(
            offset: Double(geometry.contentOffset.y),
            contentHeight: Double(geometry.contentSize.height),
            containerHeight: Double(geometry.containerSize.height),
            topInset: Double(geometry.contentInsets.top),
            bottomInset: Double(geometry.contentInsets.bottom)
        )
    }
}

#Preview("Zones · Current") {
    todayZonesPreview(hour: 12)
}

#Preview("Zones · Empty · Dark · Large text") {
    todayZonesPreview(hour: 9)
        .preferredColorScheme(.dark)
        .dynamicTypeSize(.xxxLarge)
}

#Preview("Zones · Between zones") {
    todayZonesPreview(hour: 23)
}

private func todayZonesPreview(hour: Int) -> some View {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 29, hour: hour))!
    let day = try! LocalDate(now, in: calendar.timeZone)
    let task = try! DWTask(
        title: "Walk outside and take a little time to recharge",
        schedule: .once(on: day),
        timeWindow: DayZone.defaults[1].window,
        color: .mint
    )
    let timeline = TodayTimelineViewModel(
        tasks: [task],
        day: day,
        occurrences: [],
        todayLayout: .zones,
        now: now,
        calendar: calendar
    )
    return TodayZonesView(
        model: TodayZonesViewModel(timeline: timeline, zones: DayZone.defaults),
        onCompletionChanged: { _, _ in },
        onAddTask: {}
    )
}
