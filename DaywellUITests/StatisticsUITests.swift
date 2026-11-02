import XCTest

final class StatisticsUITests: BaseUITestCase {
    func testFirstVisitAboutAndReturnToToday() {
        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.buttons["statistics.goToToday"].waitForExistence(timeout: 10))
        attachScreenshot(named: "Statistics — First visit")
        app.buttons["statistics.about"].tap()
        XCTAssertTrue(app.staticTexts["Facts with context"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["statistics.goToToday"].tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }

    func testFirstVisitSupportsLargeText() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Statistics"].tap()
        let today = app.buttons["statistics.goToToday"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(today.isHittable)
        attachScreenshot(named: "Statistics — Large text")
        today.tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].isSelected)
    }
}
