import XCTest

class BaseUITestCase: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        super.setUp()

        continueAfterFailure = false

        app = XCUIApplication()
        app.launchEnvironment["IS_UI_TESTING"] = "true"
        app.launch()
    }

    override func tearDown() {
        super.tearDown()

        continueAfterFailure = true

        app = nil
    }

    // MARK: - Helpers

    func attachScreenshot(named name: String, needsWait: Bool = true) {
        if needsWait {
            // A wheel's accessibility value changes before its scrolling animation finishes.
            Thread.sleep(forTimeInterval: 0.5)
        }

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
