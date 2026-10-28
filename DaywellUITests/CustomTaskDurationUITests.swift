import SettingsFeature
import XCTest

final class CustomTaskDurationUITests: BaseUITestCase {

    func testCustomDurationMenuAndSheet() {
        app.tabBars.buttons["Settings"].tap()

        let taskWindow = app.buttons[SettingsFeature.Accessibility.taskWindow]
        for _ in 0..<4 where !taskWindow.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(taskWindow.waitForExistence(timeout: 5))
        taskWindow.tap()

        let custom = app.buttons[SettingsFeature.Accessibility.customDuration]
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        custom.tap()
        XCTAssertTrue(app.navigationBars["Custom duration"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.pickerWheels.count, 2)

        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "30")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "24")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "25")
        XCTAssertEqual(app.staticTexts[SettingsFeature.Accessibility.customDurationSummary].label, "25.5 hours")
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "1")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "15")
        XCTAssertEqual(app.staticTexts[SettingsFeature.Accessibility.customDurationSummary].label, "1 hour 15 min")
        attachScreenshot(named: "Custom duration — 1 hour 15 min")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.navigationBars["Custom duration"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(taskWindow.label.contains("1 hour 15 min"), taskWindow.debugDescription)

        taskWindow.tap()
        attachScreenshot(named: "Task window — custom option selected")
        custom.tap()
        app.pickerWheels.element(boundBy: 0).adjust(toPickerWheelValue: "0")
        app.pickerWheels.element(boundBy: 1).adjust(toPickerWheelValue: "0")
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        attachScreenshot(named: "Custom duration — zero disabled")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.navigationBars["Custom duration"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(taskWindow.label.contains("1 hour 15 min"))

        app.terminate()
        app.launch()
        app.tabBars.buttons["Settings"].tap()
        for _ in 0..<4 where !taskWindow.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(taskWindow.waitForExistence(timeout: 5))
        XCTAssertTrue(taskWindow.label.contains("1 hour 15 min"), taskWindow.debugDescription)
        taskWindow.tap()
        XCTAssertTrue(app.buttons["1 hour 15 min"].exists)
        custom.tap()
        XCTAssertTrue(app.navigationBars["Custom duration"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts[SettingsFeature.Accessibility.customDurationSummary].label, "1 hour 15 min")
        app.buttons["Cancel"].tap()
    }
}
