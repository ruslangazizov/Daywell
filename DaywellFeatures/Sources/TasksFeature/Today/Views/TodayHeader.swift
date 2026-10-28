import DesignSystem
import SwiftUI

struct TodayHeader: View {
    let onNow: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32

    var body: some View {
        HStack {
            Text("Today")
                .font(.system(size: titleSize, weight: .bold))
                .foregroundStyle(DWColor.label)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Button(action: onNow) {
                HStack(spacing: 7) {
                    Text("Now")
                        .font(.system(size: 15))

                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .regular))
                }
                .foregroundStyle(DWColor.accent(colorScheme))
                .frame(width: 80, height: 44)
                .background(DWColor.glass, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(DWColor.separator, lineWidth: 1)
                }
                .shadow(color: DWColor.label.opacity(0.06), radius: 16, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Return to today and current time")
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 61)
    }
}
