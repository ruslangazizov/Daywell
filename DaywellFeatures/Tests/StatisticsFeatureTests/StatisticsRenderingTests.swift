import SwiftUI
import UIKit
import XCTest
@testable import StatisticsFeature

nonisolated final class StatisticsRenderingTests: XCTestCase {
    @MainActor
    func testPopulatedOverviewRendersInLightDarkAndLargeText() async throws {
        for (name, scheme, size) in [
            ("Overview Light", ColorScheme.light, DynamicTypeSize.large),
            ("Overview Dark", ColorScheme.dark, DynamicTypeSize.large),
            ("Overview Large Text", ColorScheme.light, DynamicTypeSize.accessibility3)
        ] {
            let view = StatisticsView(store: StatisticsPreviewData.makeStore())
                .environment(\.colorScheme, scheme)
                .environment(\.dynamicTypeSize, size)
            let controller = UIHostingController(rootView: view)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
            window.rootViewController = controller
            controller.view.frame = window.bounds
            controller.beginAppearanceTransition(true, animated: false)
            window.makeKeyAndVisible()
            window.layoutIfNeeded()
            try await Task.sleep(for: .milliseconds(600))
            controller.view.layoutIfNeeded()
            controller.endAppearanceTransition()
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let image = renderer.image { context in
                controller.view.layer.render(in: context.cgContext)
            }
            let bytes = try XCTUnwrap(image.cgImage?.dataProvider?.data) as Data
            XCTAssertGreaterThan(Set(bytes).count, 8, "A snapshot must contain rendered content, not a blank window.")
            let attachment = XCTAttachment(image: image)
            attachment.name = "Statistics \(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
            window.isHidden = true
        }
    }
}
