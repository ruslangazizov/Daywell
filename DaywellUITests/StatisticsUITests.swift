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

    func testTopHourOpensReviewedTaskAndCancelReturnsToInsight() {
        launchHistory()
        app.buttons["statistics.topHour"].tap()
        XCTAssertTrue(app.staticTexts["A pattern worth trying"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Statistics — Top hour")
        let plan = app.buttons["statistics.planTask"]
        reveal(plan)
        plan.tap()
        XCTAssertTrue(app.textFields["taskEditor.title"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Statistics — Plan suggested hour")
        app.buttons["taskEditor.cancel"].tap()
        XCTAssertTrue(plan.waitForExistence(timeout: 5))
    }

    func testWeekdayReceiptAndHabitEditing() {
        launchHistory()
        app.buttons["4 weeks"].tap()
        let weekday = app.buttons["statistics.weekday"]
        reveal(weekday)
        weekday.tap()
        XCTAssertTrue(app.staticTexts["An average, not a target"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Statistics — Weekly rhythm")
        let activity = app.buttons["statistics.viewActivity"]
        reveal(activity)
        activity.tap()
        XCTAssertTrue(app.navigationBars["Recorded activity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed"].firstMatch.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let allHabits = app.buttons["statistics.allHabits"]
        reveal(allHabits)
        allHabits.tap()
        app.buttons.containing(.staticText, identifier: "Read 10 pages").firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Recent history"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Statistics — Habit activity")
        let edit = app.buttons["statistics.editHabit"]
        reveal(edit)
        edit.tap()
        let title = app.textFields["taskEditor.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.value as? String, "Read 10 pages")
        app.buttons["taskEditor.cancel"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
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

    // MARK: - Private

    private func launchHistory() {
        app.terminate()
        app.launchEnvironment["STATISTICS_UI_TEST_FIXTURE"] = "true"
        app.launch()
        app.tabBars.buttons["Statistics"].tap()
        XCTAssertTrue(app.buttons["statistics.topHour"].waitForExistence(timeout: 10))
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<8 {
            if element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
