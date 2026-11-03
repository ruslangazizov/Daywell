import XCTest

final class TaskDetailsUITests: BaseUITestCase {
    func testDetailsTransitionKeepsTabBarOnToday() {
        createTask("Read a chapter", repeating: false)
        let todayTab = app.tabBars.buttons["Today"]
        XCTAssertTrue(todayTab.isHittable)

        app.staticTexts["Read a chapter"].firstMatch.tap()
        XCTAssertTrue(app.buttons["taskDetails.complete"].waitForExistence(timeout: 5))
        XCTAssertFalse(todayTab.exists)

        // Cancelling an interactive back gesture must leave details open.
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.005, dy: 0.5))
        let shortDrag = app.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: shortDrag, withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertTrue(app.buttons["taskDetails.edit"].isHittable)
        XCTAssertFalse(todayTab.exists)

        let farEdge = app.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: farEdge)
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        XCTAssertTrue(todayTab.isHittable)
        XCTAssertFalse(app.buttons["taskDetails.edit"].exists)

        // Reopening and using Back must restore the same tab bar too.
        app.staticTexts["Read a chapter"].firstMatch.tap()
        XCTAssertTrue(app.buttons["taskDetails.edit"].waitForExistence(timeout: 5))
        XCTAssertFalse(todayTab.exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(todayTab.waitForExistence(timeout: 5))
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Agenda"].waitForExistence(timeout: 5))
        todayTab.tap()
        XCTAssertTrue(app.staticTexts["Read a chapter"].waitForExistence(timeout: 5))
    }

    func testTaskDetailsCompletionAndEditing() {
        createTask("Read a chapter", repeating: false)
        app.staticTexts["Read a chapter"].firstMatch.tap()
        XCTAssertTrue(app.buttons["taskDetails.complete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["taskDetails.history"].exists)
        attachScreenshot(named: "Task details")
        app.buttons["taskDetails.complete"].tap()
        XCTAssertTrue(app.staticTexts["Completed today"].waitForExistence(timeout: 5))
        app.buttons["taskDetails.edit"].tap()
        let title = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(" slowly")
        let editedTitle = (title.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        XCTAssertTrue(editedTitle.contains("slowly"))
        XCTAssertNotEqual(editedTitle, "Read a chapter")
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.staticTexts[editedTitle].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Completed today"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["Mark \(editedTitle) incomplete"].waitForExistence(timeout: 5))
        // The separate completion control must not push details.
        app.buttons["Mark \(editedTitle) incomplete"].tap()
        XCTAssertTrue(app.buttons["Mark \(editedTitle) complete"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["taskDetails.edit"].exists)
    }

    func testHabitDetailsAndUndo() {
        createTask("Daily walk", repeating: true)
        app.staticTexts["Daily walk"].firstMatch.tap()
        XCTAssertTrue(app.buttons["taskDetails.complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Last 7 days"].exists)
        app.buttons["taskDetails.complete"].tap()
        XCTAssertTrue(app.staticTexts["Completed today"].waitForExistence(timeout: 5))
        attachScreenshot(named: "Habit details — completed")
        app.buttons["taskDetails.complete"].tap()
        XCTAssertTrue(app.staticTexts["Ready when you are"].waitForExistence(timeout: 5))
    }

    func testAgendaAndZonesOpenTheSameHabit() {
        createTask("Daily walk", repeating: true)
        for layout in ["Agenda", "Zones"] {
            app.tabBars.buttons["Settings"].tap()
            app.buttons[layout].tap()
            app.tabBars.buttons["Today"].tap()
            if layout == "Zones" {
                for _ in 0..<5 where !app.staticTexts["Daily walk"].isHittable {
                    let next = app.buttons["today.zone.next"]
                    if next.exists { next.tap() }
                }
            }
            app.staticTexts["Daily walk"].firstMatch.tap()
            XCTAssertTrue(app.buttons["taskDetails.complete"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["Last 7 days"].exists)
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
    }

    func testMoreStatsOpensHabitActivityAndReturnsToDetails() {
        createTask("Daily walk", repeating: true)
        app.staticTexts["Daily walk"].firstMatch.tap()
        let moreStats = app.buttons["taskDetails.moreStats"]
        XCTAssertTrue(moreStats.waitForExistence(timeout: 5))
        moreStats.tap()

        XCTAssertTrue(app.buttons["statistics.editHabit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Daily walk"].exists)
        XCTAssertFalse(app.tabBars.buttons["Today"].exists)
        let activity = app.buttons["statistics.viewActivity"]
        for _ in 0..<3 where !activity.isHittable { app.swipeUp() }
        activity.tap()
        XCTAssertTrue(app.navigationBars["Recorded activity"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["statistics.editHabit"].tap()
        let title = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(" outside")
        let editedTitle = (title.value as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.navigationBars[editedTitle].waitForExistence(timeout: 5))

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(moreStats.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[editedTitle].exists)
        moreStats.tap()
        XCTAssertTrue(app.buttons["statistics.editHabit"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.tabBars.buttons["Today"].waitForExistence(timeout: 5))
    }

    func testDarkDetailsWithLargeText() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Dark"].tap()
        app.tabBars.buttons["Today"].tap()
        createTask("Gentle evening stretches", repeating: true)
        app.staticTexts["Gentle evening stretches"].firstMatch.tap()
        XCTAssertTrue(app.buttons["taskDetails.complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["taskDetails.complete"].isHittable)
        attachScreenshot(named: "Habit details — Dark large text")
        app.buttons["taskDetails.complete"].tap()
        let completed = NSPredicate(format: "label CONTAINS %@", "Mark incomplete")
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(
            predicate: completed, object: app.buttons["taskDetails.complete"]
        )], timeout: 5), .completed)
        app.swipeUp()
        attachScreenshot(named: "Habit history — Dark large text")
    }

    private func createTask(_ title: String, repeating: Bool) {
        let add = app.buttons["Add task"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        let name = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(title)
        app.buttons["Done"].tap()
        // Untimed cards stay visible regardless of current clock time.
        let window = app.switches["taskEditor.timeWindow"].switches.firstMatch
        for _ in 0..<5 where !window.isHittable { app.swipeUp() }
        window.tap()
        if repeating {
            for _ in 0..<5 where !app.buttons["taskEditor.repeat"].isHittable { app.swipeUp() }
            app.buttons["taskEditor.repeat"].tap()
            app.buttons["Every day"].tap()
        }
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }
}
