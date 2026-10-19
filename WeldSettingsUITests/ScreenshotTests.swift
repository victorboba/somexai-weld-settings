import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh WeldSettings.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Bench"].waitForExistence(timeout: 20))
        sleep(1)
        // The selector and the card it resolves to, which is the whole app in one screen.
        snap("01-bench", app)

        app.buttons["process-stick"].tap()
        sleep(1)
        snap("02-stick", app)

        app.buttons["process-mig"].tap()
        let voltage = app.staticTexts["VOLTAGE"].firstMatch
        if voltage.waitForExistence(timeout: 5) { voltage.tap() }
        sleep(1)
        snap("03-which-way-to-move-it", app)

        app.tabBars.buttons["Presets"].tap()
        XCTAssertTrue(app.navigationBars["Presets"].waitForExistence(timeout: 8))
        sleep(1)
        snap("04-presets", app)

        app.tabBars.buttons["Job log"].tap()
        XCTAssertTrue(app.navigationBars["Job log"].waitForExistence(timeout: 8))
        sleep(1)
        snap("05-job-log", app)

        app.buttons["How do I use this app?"].firstMatch.tap()
        sleep(1)
        snap("06-how-to", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 15))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
