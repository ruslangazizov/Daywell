import XCTest
import SettingsFeature

final class ICloudSettingsUITests: BaseUITestCase {
    func testLocalStatusCanBeCheckedWithoutInventingASync() {
        revealICloud()
        XCTAssertTrue(app.staticTexts["Stored on this device"].exists)
        app.buttons[Accessibility.checkICloudStatus].tap()
        XCTAssertTrue(app.buttons[Accessibility.checkICloudStatus].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stored on this device"].exists)
        XCTAssertFalse(app.staticTexts["Last confirmed sync"].exists)
        attachScreenshot(named: "iCloud — local test storage", needsWait: false)
    }

    func testAccountAndTransferStatesAreRendered() {
        for (status, title) in [
            ("signedOut", "Sign in to iCloud"),
            ("storageFull", "iCloud storage is full"),
            ("noConfirmedSync", "No confirmed sync yet"),
            ("syncing", "Syncing…")
        ] {
            app.terminate()
            app.launchEnvironment["ICLOUD_UI_TEST_STATUS"] = status
            app.launch()
            revealICloud()
            XCTAssertTrue(app.staticTexts[title].exists, status)
            XCTAssertTrue(app.buttons[Accessibility.checkICloudStatus].isEnabled)
            attachScreenshot(named: "iCloud — \(status)", needsWait: false)
        }
    }

    private func revealICloud() {
        app.tabBars.buttons["Settings"].tap()
        let check = app.buttons[Accessibility.checkICloudStatus]
        for _ in 0..<5 where !check.isHittable { app.swipeUp() }
        XCTAssertTrue(check.waitForExistence(timeout: 5))
    }
}
