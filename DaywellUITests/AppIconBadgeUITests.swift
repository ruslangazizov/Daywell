import XCTest

final class AppIconBadgeUITests: BaseUITestCase {
    private var badgeIconIndex: Int?

    func testBadgeTracksCompletionLayoutsAndOptOut() {
        app.tabBars.buttons["Settings"].tap()
        let badge = app.switches["settings.appIconBadge"].switches.firstMatch
        reveal(badge)
        badge.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow"].waitForExistence(timeout: 2) {
            springboard.buttons["Allow"].tap()
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == '1'"), object: badge
        )], timeout: 5), .completed)
        app.tabBars.buttons["Today"].tap()
        createUntimedTask("Badge check")
        checkHomeBadge(1)

        app.buttons["Mark Badge check complete"].tap()
        XCTAssertTrue(app.buttons["Mark Badge check incomplete"].waitForExistence(timeout: 5))
        checkHomeBadge(0)
        app.buttons["Mark Badge check incomplete"].tap()
        XCTAssertTrue(app.buttons["Mark Badge check complete"].waitForExistence(timeout: 5))
        checkHomeBadge(1)

        app.tabBars.buttons["Settings"].tap()
        for _ in 0..<5 where !app.buttons["Agenda"].isHittable { app.swipeDown() }
        app.buttons["Agenda"].tap()
        checkHomeBadge(1)
        app.buttons["Zones"].tap()
        // An untimed task is in No zone, never in the current timed zone.
        checkHomeBadge(0)
        app.buttons["Timeline"].tap()
        checkHomeBadge(1)
        reveal(badge)
        badge.tap()
        checkHomeBadge(0)
    }

    private func checkHomeBadge(_ count: Int) {
        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let icons = springboard.icons.matching(identifier: "Daywell")
        XCTAssertTrue(icons.firstMatch.waitForExistence(timeout: 5))
        // Development builds with another bundle ID can share the display name.
        // Locate the newly badged icon once, then keep checking that same icon.
        if badgeIconIndex == nil {
            let appeared = NSPredicate { _, _ in
                (0..<icons.count).contains { (icons.element(boundBy: $0).value as? String)?.hasPrefix("\(count) ") == true }
            }
            XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: appeared, object: nil)], timeout: 5), .completed)
            badgeIconIndex = (0..<icons.count).first {
                (icons.element(boundBy: $0).value as? String)?.hasPrefix("\(count) ") == true
            }
        }
        let icon = icons.element(boundBy: badgeIconIndex ?? 0)
        let predicate = NSPredicate { object, _ in
            guard let icon = object as? XCUIElement else { return false }
            let value = icon.value as? String ?? ""
            return count == 0 ? value.isEmpty : (value == String(count) || value.hasPrefix("\(count) "))
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: icon)], timeout: 5),
                       .completed, "Expected \(count); badge value: \(String(describing: icon.value))")
        attachScreenshot(named: "App icon badge \(count)")
        app.activate()
        // XCTest returns before SpringBoard's zoom transition finishes on iOS 27.
        // App elements are already in the AX tree but taps still land on the transition.
        Thread.sleep(forTimeInterval: 1)
    }

    private func createUntimedTask(_ title: String) {
        app.buttons["Add task"].firstMatch.tap()
        let name = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(title)
        app.buttons["Done"].tap()
        let window = app.switches["taskEditor.timeWindow"].switches.firstMatch
        reveal(window)
        window.tap()
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.buttons["Mark \(title) complete"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<6 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}
