import DesignSystem
import SwiftUI

public struct TodayCompletionSummaryModel: Equatable {
    let completedCount: Int
    let totalCount: Int

    public init(completedCount: Int, totalCount: Int) {
        self.completedCount = completedCount
        self.totalCount = totalCount
    }
}

struct TodayCompletionSummary: View {
    let model: TodayCompletionSummaryModel

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .footnote) private var textSize: CGFloat = 13

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(DWColor.accent(colorScheme))
                .frame(width: 14)

            Text("\(model.completedCount) of \(model.totalCount) complete")
                .font(.system(size: textSize))
                .foregroundStyle(DWColor.secondary(colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                ForEach(0 ..< min(model.totalCount, 9), id: \.self) { index in
                    Capsule()
                        .fill(index < completedSegments ? DWColor.accent(colorScheme) : DWColor.separator)
                        .frame(width: 8, height: 4)
                }
            }
            .padding(.trailing, 7)
        }
        .padding(.horizontal, 21)
        .frame(minHeight: 31)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(model.completedCount) of \(model.totalCount) tasks complete")
    }

    private var completedSegments: Int {
        guard model.totalCount > 0 else { return 0 }
        return Int((Double(model.completedCount) / Double(model.totalCount) * Double(min(model.totalCount, 9))).rounded(.down))
    }
}
