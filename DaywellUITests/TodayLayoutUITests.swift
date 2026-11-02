import XCTest

final class TodayLayoutUITests: BaseUITestCase {
    func testFreshStoreShowsNoDemoTasks() {
        XCTAssertTrue(app.staticTexts["No tasks for this day"].waitForExistence(timeout: 10))
        chooseLayout("Agenda")
        XCTAssertTrue(app.staticTexts["No tasks for this day"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Mark Read a chapter complete"].exists)
        attachScreenshot(named: "Today — Empty local store")
    }

    func testEmptyZoneKeepsSelectionWithLargeText() {
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

    func testSwitchingLayoutsPreservesSavedChoiceWithEmptyStore() {
        XCTAssertTrue(app.scrollViews["today.timeline"].waitForExistence(timeout: 10))
        chooseLayout("Agenda")
        XCTAssertTrue(app.scrollViews["today.agenda"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Today — Empty agenda")

        chooseLayout("Zones")
        XCTAssertTrue(app.scrollViews["today.zones"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Today — Empty zones")
        app.tabBars.buttons["Settings"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.scrollViews["today.zones"].waitForExistence(timeout: 5))

        chooseLayout("Timeline")
        XCTAssertTrue(app.scrollViews["today.timeline"].waitForExistence(timeout: 5))
    }

    private func chooseLayout(_ name: String) {
        app.tabBars.buttons["Settings"].tap()
        app.buttons[name].tap()
        app.tabBars.buttons["Today"].tap()
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
