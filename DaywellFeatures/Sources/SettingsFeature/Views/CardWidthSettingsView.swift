import SwiftUI
import DesignSystem

struct CardWidthSettingsView: View {
    @Binding var percentage: Double

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote)
    private var previewHeight: CGFloat = 70

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Slider(
                value: $percentage,
                in: 0.1 ... 1,
                step: 0.05
            ) {
                Text("Card width")
            }
            .tint(DWColor.accent(colorScheme))
            .frame(minHeight: 44)
            .accessibilityValue("\(Int(percentage)) percent")
            .accessibilityHint(
                "Width of each card when three or more tasks overlap"
            )

            HStack {
                Text("10%")
                Spacer()
                Text("100%")
            }
            .font(.caption2)
            .foregroundStyle(DWColor.secondary(colorScheme))
            .accessibilityHidden(true)

            cardsPreview
                .padding(.top, 11)

            Text("""
            Swipe the row to see more tasks.
            1–2 tasks keep their automatic layout.
            """)
            .font(.footnote)
            .foregroundStyle(DWColor.secondary(colorScheme))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .settingBackground()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Card width")
                    .foregroundStyle(DWColor.label)

                Spacer(minLength: 12)

                Text("\(Int(percentage * 100))%")
                    .fontWeight(.semibold)
                    .foregroundStyle(DWColor.accent(colorScheme))
            }
            .font(.body)

            Text("For 3 or more overlapping tasks")
                .font(.footnote)
                .foregroundStyle(DWColor.secondary(colorScheme))
        }
    }

    private var cardsPreview: some View {
        GeometryReader { geometry in
            let cardWidth = geometry.size.width * CGFloat(percentage)

            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    TimelineTaskCard(
                        title: "Do math homework",
                        time: "8 PM – 10 PM",
                        colorGroup: .defaults[0],
                        isCompleted: .constant(true)
                    )
                    .frame(width: cardWidth)

                    TimelineTaskCard(
                        title: "Read",
                        time: "9 PM – 11 PM",
                        colorGroup: .defaults[1],
                        isCompleted: .constant(false)
                    )
                    .frame(width: cardWidth)

                    TimelineTaskCard(
                        title: "Plan  the week",
                        time: "10 PM – 11 PM",
                        colorGroup: .defaults[2],
                        isCompleted: .constant(true)
                    )
                    .frame(width: cardWidth)
                }
            }
            .scrollIndicators(.hidden)
        }
        .frame(height: previewHeight)
        .clipShape(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .accessibilityHidden(true)
    }
}
