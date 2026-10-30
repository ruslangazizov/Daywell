import XCTest

final class TodayLayoutUITests: BaseUITestCase {
    func testTimeBasedZonesShareCompletionAndKeepUnmatchedTasksSeparate() {
        chooseLayout("Zones")
        XCTAssertTrue(app.staticTexts["today.zone.title"].waitForExistence(timeout: 5))
        firstZone()
        app.buttons["today.zone.next"].tap()
        assertZone("Day")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Monthly reflection")).count, 1)

        let pending = app.buttons["Mark Plan an evening walk complete"]
        XCTAssertTrue(pending.exists)
        pending.tap()
        XCTAssertTrue(app.buttons["Mark Plan an evening walk incomplete"].exists)
        app.buttons["today.zone.next"].tap()
        assertZone("Evening")
        let completed = app.buttons["Mark Plan an evening walk incomplete"]
        XCTAssertTrue(completed.exists)
        XCTAssertFalse(app.buttons["Mark Monthly reflection complete"].exists)
        attachScreenshot(named: "Zones — Shared completion in Evening")

        completed.tap()
        app.buttons["today.zone.previous"].tap()
        assertZone("Day")
        XCTAssertTrue(pending.exists)
        attachScreenshot(named: "Zones — Monthly reflection and overlapping task in Day")

        app.buttons["today.zone.next"].tap()
        app.buttons["today.zone.next"].tap()
        assertZone("No zone")
        XCTAssertFalse(pending.exists)
        XCTAssertFalse(app.buttons["Mark Monthly reflection complete"].exists)
        XCTAssertTrue(app.buttons["Mark Late-night wind down complete"].exists)

        chooseLayout("Agenda")
        reveal(pending)
        XCTAssertEqual(app.buttons.matching(identifier: "Mark Plan an evening walk complete").count, 1)
    }

    func testLongZoneScrollKeepsSelectionWithLargeText() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        chooseLayout("Zones")
        XCTAssertTrue(app.staticTexts["today.zone.title"].waitForExistence(timeout: 5))
        firstZone()
        assertZone("Morning")
        attachScreenshot(named: "Zones — Large text")
        pull(from: 0.7, to: 0.4)
        assertZone("Morning")
        app.scrollViews["today.zones"].swipeUp(velocity: .fast)
        assertZone("Morning") // Momentum reaching the end must not select another zone.
    }

    func testZoneGesturesGoBothWaysAndNowRestoresCurrentZone() {
        chooseLayout("Zones")
        let title = app.staticTexts["today.zone.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let currentTitle = title.label
        firstZone()
        XCTAssertEqual(title.label, "Morning")
        XCTAssertFalse(app.buttons["today.zone.previous"].exists)

        app.buttons["today.zone.next"].tap()
        assertZone("Day")
        pull(from: 0.3, to: 0.35)
        assertZone("Day") // Releasing below the threshold cancels.
        pull(from: 0.2, to: 0.85)
        assertZone("Morning")

        app.buttons["today.zone.next"].tap()
        assertZone("Day")
        pull(from: 0.85, to: 0.15)
        assertZone("Evening")
        attachScreenshot(named: "Zones — Evening after pulling up")

        app.buttons["today.now"].tap()
        assertZone(currentTitle)
        firstZone()
        app.buttons["today.now"].tap()
        assertZone(currentTitle) // Also works when the selected date never changed.

        let date = app.scrollViews["today.weekPager"].buttons.allElementsBoundByIndex
            .first { $0.isHittable && !$0.isSelected }
        XCTAssertNotNil(date)
        date?.tap()
        assertZone("Morning")
        XCTAssertFalse(app.staticTexts["today.zone.status"].exists)
        app.buttons["today.zone.next"].tap()
        assertZone("Day")
        app.buttons["today.now"].tap()
        assertZone(currentTitle)
        attachScreenshot(named: "Zones — Return to now")
    }

    func testSwitchingLayoutsPreservesCompletionAndSavedChoice() {
        XCTAssertTrue(app.scrollViews["today.timeline"].waitForExistence(timeout: 10))
        chooseLayout("Agenda")
        XCTAssertTrue(app.scrollViews["today.agenda"].waitForExistence(timeout: 5))
        let pending = app.buttons["Mark Read a chapter complete"]
        reveal(pending)
        pending.tap()
        XCTAssertTrue(app.buttons["Mark Read a chapter incomplete"].exists)
        attachScreenshot(named: "Today — Agenda")

        chooseLayout("Zones")
        XCTAssertTrue(app.scrollViews["today.zones"].waitForExistence(timeout: 5))
        let completed = app.buttons["Mark Read a chapter incomplete"]
        reveal(completed)
        XCTAssertTrue(completed.exists)
        attachScreenshot(named: "Today — Zones")
        completed.tap()

        chooseLayout("Agenda")
        XCTAssertTrue(app.scrollViews["today.agenda"].waitForExistence(timeout: 5))
        reveal(pending)
        XCTAssertTrue(pending.exists)

        chooseLayout("Timeline")
        XCTAssertTrue(app.scrollViews["today.timeline"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Today — Timeline")
    }

    private func chooseLayout(_ name: String) {
        app.tabBars.buttons["Settings"].tap()
        app.buttons[name].tap()
        app.tabBars.buttons["Today"].tap()
    }

    private func reveal(_ element: XCUIElement) {
        if app.scrollViews["today.zones"].exists {
            firstZone()
            for _ in 0..<8 where !element.exists && app.buttons["today.zone.next"].exists {
                app.buttons["today.zone.next"].tap()
            }
        }
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        if !element.isHittable {
            for _ in 0..<8 where !element.isHittable { app.swipeDown() }
        }
        XCTAssertTrue(element.isHittable)
    }

    private func firstZone() {
        for _ in 0..<8 where app.buttons["today.zone.previous"].exists {
            app.buttons["today.zone.previous"].tap()
        }
        // Before the first zone starts, Now shows the gap preceding Morning.
        if app.staticTexts["today.zone.title"].label == "Between zones" {
            app.buttons["today.zone.next"].tap()
        }
    }

    private func assertZone(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let matches = NSPredicate(format: "label == %@", name)
        let expectation = XCTNSPredicateExpectation(predicate: matches, object: app.staticTexts["today.zone.title"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed, file: file, line: line)
    }

    private func pull(from start: CGFloat, to end: CGFloat) {
        let scroll = app.scrollViews["today.zones"]
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: start))
            .press(forDuration: 0.1,
                   thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: end)),
                   withVelocity: .slow, thenHoldForDuration: 0.3)
    }
}
