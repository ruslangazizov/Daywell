import SwiftUI

public struct TimelineTaskCard: View {
    let title: String
    let time: String
    let colorGroup: DWColorGroup
    let minHeight: CGFloat

    @Binding var isCompleted: Bool

    public init(
        title: String,
        time: String,
        colorGroup: DWColorGroup,
        isCompleted: Binding<Bool>,
        minHeight: CGFloat = UIConstants.minTaskCardHeight
    ) {
        self.title = title
        self.time = time
        self.colorGroup = colorGroup
        self._isCompleted = isCompleted
        self.minHeight = minHeight
    }

    @ScaledMetric(relativeTo: .subheadline)
    private var titleSize: CGFloat = 14

    @ScaledMetric(relativeTo: .caption2)
    private var timeSize: CGFloat = 10

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: titleSize, weight: .semibold))
                .padding(.trailing, 26)

            Text(time)
                .font(.system(size: timeSize, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(colorGroup.label)
        .padding(9)
        .frame(
            maxWidth: .infinity,
            minHeight: max(UIConstants.minTaskCardHeight, minHeight),
            alignment: .topLeading
        )
        .background(colorGroup.bg, in: shape)
        .overlay {
            shape.strokeBorder(colorGroup.border, lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            completionButton
        }
        .accessibilityElement(children: .contain)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(
            cornerRadius: 11,
            style: .continuous
        )
    }

    private var completionButton: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isCompleted.toggle()
            }
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(colorGroup.label, lineWidth: 1)

                if isCompleted {
                    Circle()
                        .fill(colorGroup.label)

                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(DWColor.white)
                }
            }
            .frame(width: 21, height: 21)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            isCompleted
            ? "Mark \(title) incomplete"
            : "Mark \(title) complete"
        )
        .accessibilityValue(isCompleted ? "Completed" : "Pending")
    }
}

#Preview("Pending / Complete") {
    TimelineTaskCardStatesPreview()
}

private struct TimelineTaskCardStatesPreview: View {
    @State private var allIsCompleted = false
    private let titles: [String] = [
        "Read",
        "Go for a walk",
        "Do math homework",
        "Something long like meditate and practice mindfulness",
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(DWColorGroup.defaults, id: \.bg) { colorGroup in
                TimelineTaskCard(
                    title: titles.randomElement()!,
                    time: "8 PM – 10 PM",
                    colorGroup: colorGroup,
                    isCompleted: $allIsCompleted
                )
                .frame(width: 148)
            }
        }
    }
}
