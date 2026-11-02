import XCTest

final class TaskEditorUITests: BaseUITestCase {
    func testCreatesTaskAndHabitInToday() {
        openEditor()
        XCTAssertFalse(app.buttons["taskEditor.save"].isEnabled)
        let name = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Read a chapter")
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Read a chapter"].waitForExistence(timeout: 5))

        openEditor()
        name.tap()
        name.typeText("Daily walk")
        app.buttons["Done"].tap()
        app.buttons["taskEditor.repeat"].tap()
        app.buttons["Every day"].tap()
        XCTAssertTrue(app.navigationBars["New habit"].waitForExistence(timeout: 3))
        attachScreenshot(named: "New habit — Native form")
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.staticTexts["Daily walk"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Statistics"].tap()
        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.staticTexts["Daily walk"].waitForExistence(timeout: 5))
    }

    func testDiscardAndLargeText() {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        openEditor()
        let name = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Unsaved task")
        app.buttons["Done"].tap()
        attachScreenshot(named: "New task — Large text")
        app.buttons["taskEditor.cancel"].tap()
        // iOS may render a confirmation as a popover without a cancel row.
        if app.buttons["Keep editing"].exists {
            app.buttons["Keep editing"].tap()
        } else {
            app.otherElements["PopoverDismissRegion"].tap()
        }
        XCTAssertTrue(name.exists)
        app.buttons["taskEditor.cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.staticTexts["No tasks for this day"].waitForExistence(timeout: 5))
    }

    private func openEditor() {
        let add = app.buttons["Add task"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.buttons["taskEditor.save"].waitForExistence(timeout: 5))
    }
}
