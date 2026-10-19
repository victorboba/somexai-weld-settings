import XCTest

/// The core loop, driven through the real UI.
///
/// Every assertion here is on content that only exists if the app genuinely worked: an amperage
/// range that changed because the process changed, a preset row carrying the number the editor
/// pre-filled, a logged weld appearing in the list with its title. Nothing asserts merely that a
/// button exists.
final class CoreLoopTests: XCTestCase {

    override func setUpWithError() throws { continueAfterFailure = false }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-skipOnboarding", "-resetData", "-uiTesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Bench"].waitForExistence(timeout: 20),
                      "the bench should be the screen the app opens on")
        return app
    }

    private func amperage(_ app: XCUIApplication) -> String {
        let readout = app.staticTexts["amperageReadout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10), "the settings card never resolved")
        return readout.label
    }

    // MARK: - The selector resolves to a card

    func testTheBenchResolvesToARangeAndTheProcessChangesIt() {
        let app = launch()

        // Defaults are MIG, mild steel, 3 mm, fillet, flat — about 115 to 145 amps.
        let mig = amperage(app)
        XCTAssertTrue(mig.contains("–"), "the card should show a range, not one figure: \(mig)")
        XCTAssertTrue(mig.contains("A"))
        XCTAssertTrue(app.staticTexts["cardSubtitle"].label.contains("DCEP"),
                      "solid wire under gas runs electrode positive")

        // Switching the process changes what the screen asks for, not just what it filters.
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Wire speed")).firstMatch.exists
                      || app.staticTexts["Wire speed"].exists,
                      "MIG should be asked about wire speed")

        app.buttons["process-stick"].tap()
        let stick = amperage(app)
        XCTAssertNotEqual(mig, stick, "the stick card should not be the MIG card")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "E7018")).firstMatch
                        .waitForExistence(timeout: 5),
                      "stick should name the rod, which is the thing that decides the range")
        XCTAssertFalse(app.staticTexts["Wire speed"].exists, "stick has no wire speed")
    }

    func testAluminiumOnTigSwitchesThePolarityToAC() {
        let app = launch()
        app.buttons["process-tig"].tap()
        XCTAssertTrue(app.staticTexts["cardSubtitle"].label.contains("DCEN"),
                      "TIG on steel is electrode negative")

        app.buttons["Aluminium"].firstMatch.tap()
        let subtitle = app.staticTexts["cardSubtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5))
        XCTAssertTrue(subtitle.label.contains("AC"),
                      "aluminium needs AC to break the oxide up, and the card has to say so: \(subtitle.label)")
        XCTAssertTrue(subtitle.label.contains("Aluminium"))
    }

    func testTheThicknessReadoutConvertsBetweenGaugeAndMillimetres() {
        let app = launch()
        let readout = app.staticTexts["thicknessReadout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 10))
        XCTAssertTrue(readout.label.contains("mm"), "the readout should carry millimetres: \(readout.label)")
        XCTAssertTrue(readout.label.contains("in"), "and inches: \(readout.label)")

        // Drag the slider down into sheet metal and the gauge number appears.
        app.sliders["thicknessSlider"].adjust(toNormalizedSliderPosition: 0.18)
        XCTAssertTrue(readout.label.contains("ga"),
                      "sheet metal should also read as a gauge number: \(readout.label)")
    }

    func testTappingASettingRowRevealsWhichWayToMoveIt() {
        let app = launch()
        let voltage = app.staticTexts["VOLTAGE"].firstMatch
        XCTAssertTrue(voltage.waitForExistence(timeout: 10))
        voltage.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "ropey")).firstMatch
                        .waitForExistence(timeout: 5),
                      "the row should open onto the advice about which way to move it")
    }

    // MARK: - Saving what worked

    func testSavingAPresetPutsItOnThePresetsTab() {
        let app = launch()
        let expected = amperage(app)

        app.buttons["Save as a preset"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Save a preset"].waitForExistence(timeout: 5))
        // The editor pre-fills the middle of the range, so there is a real number to look for.
        app.buttons["Save"].firstMatch.tap()

        app.tabBars.buttons["Presets"].tap()
        XCTAssertTrue(app.staticTexts["Not on a machine"].waitForExistence(timeout: 5),
                      "a preset saved with no machine should be filed under its own heading")

        let midpoint = midpointAmps(of: expected)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "\(midpoint) A")).firstMatch
                        .waitForExistence(timeout: 5),
                      "the preset row should carry the number that was saved (\(midpoint) A from \(expected))")
    }

    func testLoggingAWeldFromTheBenchShowsUpInTheJobLog() {
        let app = launch()
        app.buttons["Log this weld"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Log a weld"].waitForExistence(timeout: 5),
                      "the bench should hand the selection straight to the job log")
        let title = app.textFields["What did you weld?"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Trailer fender bracket")
        app.buttons["Save"].firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Trailer fender bracket"].waitForExistence(timeout: 8),
                      "the logged weld should appear in the list")
        // The summary strip only counts welds that were actually saved.
        XCTAssertTrue(app.staticTexts["welds logged"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1"].firstMatch.exists)
    }

    func testTheHowToGuideOpensFromTheBench() {
        let app = launch()
        app.buttons["How do I use this app?"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["How do I use Weld Settings?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Set the bench"].waitForExistence(timeout: 5),
                      "the first step of the guide should be the first thing a new user does")
    }

    func testSettingsCarriesTheIndependenceNotice() {
        let app = launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "not affiliated")).firstMatch
        XCTAssertTrue(notice.waitForExistence(timeout: 5),
                      "Settings must say the app is not affiliated with any machine manufacturer")
    }

    // MARK: - Helpers

    /// "115 – 145 A" -> 130, matching the midpoint the preset editor pre-fills.
    private func midpointAmps(of range: String) -> Int {
        let numbers = range.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard numbers.count >= 2 else { return 0 }
        return (numbers[0] + numbers[1]) / 2
    }
}
