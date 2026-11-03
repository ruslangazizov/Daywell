import SwiftUI

extension View {
    public func statisticsCard(_ background: Color = DWColor.group) -> some View {
        self.padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background, in: RoundedRectangle(cornerRadius: 24))
    }
}
