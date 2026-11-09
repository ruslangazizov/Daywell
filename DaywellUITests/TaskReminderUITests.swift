import XCTest

final class TaskReminderUITests: BaseUITestCase {
    func testOptInShowsReminderInsideScheduleAndOffHidesIt() {
        openEditor()
        XCTAssertFalse(app.buttons["taskEditor.reminder"].exists)
        app.buttons["taskEditor.cancel"].tap()

        openNotificationSettings()
        let toggle = app.switches["settings.taskReminders"].switches.firstMatch
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow"].waitForExistence(timeout: 2) {
            springboard.buttons["Allow"].tap()
        }
        XCTAssertTrue(NSPredicate(format: "value == '1'").evaluate(with: toggle))
        app.tabBars.buttons["Today"].tap()
        openEditor()
        let reminder = app.buttons["taskEditor.reminder"]
        reveal(reminder)
        XCTAssertTrue(reminder.exists)
        XCTAssertTrue(reminder.label.contains("At start"))
        XCTAssertTrue(app.staticTexts["Schedule"].exists)
        app.swipeUp()
        attachScreenshot(named: "Reminder inside Schedule")
        reminder.tap()
        app.buttons["15 minutes before"].tap()
        XCTAssertTrue(reminder.label.contains("15 minutes before"))
        reminder.tap()
        app.buttons["Custom time"].tap()
        let time = app.descendants(matching: .any)["taskEditor.reminderTime"].firstMatch
        reveal(time)
        XCTAssertTrue(time.exists)
        attachScreenshot(named: "Custom reminder time")
        app.buttons["taskEditor.cancel"].tap()
        app.buttons["Discard changes"].tap()
        XCTAssertTrue(app.buttons["taskEditor.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No tasks for this day"].waitForExistence(timeout: 5))

        openNotificationSettings()
        let offToggle = app.switches["settings.taskReminders"].switches.firstMatch
        reveal(offToggle)
        attachScreenshot(named: "Before disabling reminders")
        offToggle.tap()
        let isOff = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '0'"), object: offToggle)
        XCTAssertEqual(XCTWaiter.wait(for: [isOff], timeout: 5), .completed)
        attachScreenshot(named: "Reminders disabled")
        app.tabBars.buttons["Today"].tap()
        openEditor()
        XCTAssertFalse(app.buttons["taskEditor.reminder"].exists)
    }

    func testDeliversScheduledReminderWhileAppIsOpen() {
        openNotificationSettings()
        app.switches["settings.taskReminders"].switches.firstMatch.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        if springboard.buttons["Allow"].waitForExistence(timeout: 2) {
            springboard.buttons["Allow"].tap()
        }
        app.tabBars.buttons["Today"].tap()
        openEditor()
        let name = app.descendants(matching: .any)["taskEditor.title"].firstMatch
        name.tap()
        name.typeText("Reminder delivery check")
        app.buttons["Done"].tap()
        app.switches["taskEditor.timeWindow"].switches.firstMatch.tap()
        let time = app.descendants(matching: .any)["taskEditor.reminderTime"].firstMatch
        reveal(time)
        time.buttons.firstMatch.tap()
        attachScreenshot(named: "Reminder time picker")
        let wheels = app.pickerWheels
        XCTAssertTrue(wheels.firstMatch.waitForExistence(timeout: 5), app.debugDescription)
        let target = Date().addingTimeInterval(120)
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: target)
        let minute = calendar.component(.minute, from: target)
        XCTAssertEqual(wheels.count, 3, app.debugDescription)
        wheels.element(boundBy: 0).adjust(toPickerWheelValue: String(hour % 12 == 0 ? 12 : hour % 12))
        wheels.element(boundBy: 1).adjust(toPickerWheelValue: String(format: "%02d", minute))
        wheels.element(boundBy: 2).adjust(toPickerWheelValue: hour < 12 ? "AM" : "PM")
        app.navigationBars["New task"].tap()
        app.buttons["taskEditor.save"].tap()
        XCTAssertTrue(app.buttons["taskEditor.save"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(springboard.staticTexts["Reminder delivery check"].waitForExistence(timeout: 130))
        attachScreenshot(named: "Delivered task reminder")
    }

    private func openNotificationSettings() {
        app.tabBars.buttons["Settings"].tap()
        reveal(app.switches["settings.taskReminders"])
    }

    private func openEditor() {
        let button = app.buttons["Add task"].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["taskEditor.save"].waitForExistence(timeout: 5))
    }

    private func reveal(_ element: XCUIElement) {
        for _ in 0..<5 {
            if element.isHittable { return }
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable)
    }
}
