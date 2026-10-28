import SettingsFeature
import XCTest

final class DailyZonesUITests: BaseUITestCase {
    func testEditingAddingAndRestoringZones() {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Zones"].tap()

        let morning = app.buttons[Accessibility.zone("00000000-0000-0000-0000-000000000065")]
        XCTAssertTrue(morning.waitForExistence(timeout: 5))
        morning.tap()
        XCTAssertTrue(app.navigationBars["Edit zone"].waitForExistence(timeout: 5))
        let name = app.textFields[Accessibility.zoneName]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Morning".count))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        name.typeText("Early morning")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Edit zone"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(morning.label.contains("Early morning"))

        let add = app.buttons[Accessibility.addZone]
        reveal(add)
        add.tap()
        XCTAssertTrue(app.navigationBars["Add zone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        name.tap()
        name.typeText("Night")
        XCTAssertTrue(app.buttons["Save"].isEnabled)
        attachScreenshot(named: "Zones — overnight editor")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Add zone"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Night"].exists)

        let restore = app.buttons[Accessibility.restoreZones]
        reveal(restore)
        restore.tap()
        XCTAssertTrue(app.buttons["Restore defaults"].waitForExistence(timeout: 5))
        if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else {
            // Popover-style confirmations dismiss by tapping outside, without a Cancel row.
            app.navigationBars["Settings"].tap()
        }
        XCTAssertTrue(app.buttons["Restore defaults"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Night"].exists)
        restore.tap()
        app.buttons["Restore defaults"].tap()
        XCTAssertTrue(app.staticTexts["Night"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(morning.label.contains("Morning"))
        XCTAssertFalse(morning.label.contains("Early morning"))
        app.swipeDown()
        attachScreenshot(named: "Zones — default settings")
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
}
