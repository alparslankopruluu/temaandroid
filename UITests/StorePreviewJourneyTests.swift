import XCTest

/// A paced journey for the App Store preview, recorded with `simctl io recordVideo`.
/// Skipped unless TEST_RUNNER_SCREENMOTION_PREVIEW_LOCALE is set (for example "en_US:en").
final class StorePreviewJourneyTests: XCTestCase {
    @MainActor func testPreviewJourney() throws {
        let requested = ProcessInfo.processInfo.environment["SCREENMOTION_PREVIEW_LOCALE"]
        try XCTSkipIf(requested == nil, "Preview journey runs only on request")
        let parts = requested!.split(separator: ":").map(String.init)
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(parts[1]))", "-AppleLocale", parts[0], "-welcome", "YES",
                               "-launch-paywall", "YES", "-demo-clock", "YES", "-demo-video", "abyss"]
            + (parts[0] == "en_US" ? ["-AppleICUForce12HourTime", "YES"] : [])
        app.launch()
        XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 10))
        sleep(4)                                   // 1. a living Lock Screen on Discover

        app.buttons["featuredTheme"].tap()
        XCTAssertTrue(app.buttons["editor.saveInstall"].waitForExistence(timeout: 8))
        sleep(1)
        let preview = app.descendants(matching: .any)["scenePreview.midnight"]
        for point in [CGVector(dx: 0.35, dy: 0.6), CGVector(dx: 0.65, dy: 0.45), CGVector(dx: 0.5, dy: 0.7)] {
            preview.coordinate(withNormalizedOffset: point).tap()
            usleep(700_000)
        }
        app.segmentedControls.buttons.element(boundBy: 2).tap()   // 2. touch it, warm it
        sleep(2)
        app.navigationBars.buttons.element(boundBy: 0).tap()

        let video = app.buttons["openVideoLive"]
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        video.tap()
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10))
        sleep(2)                                   // 3. your video, a Live Photo
        slider.adjust(toNormalizedSliderPosition: 0.5)
        sleep(2)
        app.buttons["video.close"].tap()

        let nightstand = app.buttons["openNightstand"]
        XCTAssertTrue(nightstand.waitForExistence(timeout: 5))
        nightstand.tap()
        sleep(5)                                   // 4. a living nightstand
    }
}
