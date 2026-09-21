import XCTest

final class JourneyTests: XCTestCase {
    @MainActor func testDiscoverEditSaveAndInstallationJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 4) { capture("welcome"); start.tap() }
        XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 5))
        capture("discover")
        app.buttons["featuredTheme"].tap()
        XCTAssertTrue(app.buttons["Save & set up"].waitForExistence(timeout: 5))
        capture("editor")
        app.buttons["Toggle favorite"].tap()
        app.buttons["Save design"].tap()
        app.buttons["Save & set up"].tap()
        XCTAssertTrue(app.buttons["Save to Photos"].waitForExistence(timeout: 5))
        capture("export-options")
        app.buttons["Close"].tap()
    }
    @MainActor func testTurkishAndArabicDiscovery() {
        for (language, locale) in [("tr", "tr_TR"), ("ar", "ar_SA")] {
            let app = XCUIApplication()
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale]
            app.launch()
            let start = app.buttons["startExploring"]
            if start.waitForExistence(timeout: 2) { start.tap() }
            XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 5))
            capture("discover-\(language)")
            app.buttons["featuredTheme"].tap()
            capture("editor-\(language)")
            app.terminate()
        }
    }
    @MainActor func testTurkishExportHintsAreLocalized() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 5))
        app.buttons["featuredTheme"].tap()
        let export = app.buttons["Kaydet ve kur"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        XCTAssertTrue(app.staticTexts["Her ekrana uygun, net bir duvar kâğıdı"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Kilit ekranın için kısa bir animasyon"].exists)
        XCTAssertTrue(app.staticTexts["Paylaşmak için 3 saniyelik video"].exists)
        XCTAssertFalse(app.staticTexts["export.hint.still"].exists)
        XCTAssertFalse(app.staticTexts["export.hint.livePhoto"].exists)
        XCTAssertFalse(app.staticTexts["export.hint.video"].exists)
    }
    @MainActor func testPixelThemeOpensInsideExistingEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        let filter = app.segmentedControls["appearanceFilter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["Pixel"].tap()
        let pixelCar = app.buttons["theme.pixel-car"]
        XCTAssertTrue(pixelCar.waitForExistence(timeout: 5))
        pixelCar.tap()
        let preview = app.descendants(matching: .any)["scenePreview.pixel-car"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        let scoreMode = app.switches["scoreModeToggle"]
        XCTAssertTrue(scoreMode.waitForExistence(timeout: 5))
        scoreMode.tap()
        capture("editor-pixel-car")
    }

    @MainActor func testPaywallLoadsProductsAndComplianceActions() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }

        let pro = app.buttons["Every world. Yours."]
        XCTAssertTrue(pro.waitForExistence(timeout: 5))
        pro.tap()

        XCTAssertTrue(app.buttons["Restore purchases"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Yearly"].exists)
        XCTAssertTrue(app.staticTexts["Monthly"].exists)
        XCTAssertTrue(app.staticTexts["Subscription renews automatically for the selected period until canceled in App Store settings."].exists)
        XCTAssertFalse(app.staticTexts["No Paywall configured"].exists)
        XCTAssertFalse(app.progressIndicators.firstMatch.exists)
        capture("paywall-en")

        app.swipeUp()
        XCTAssertTrue(app.buttons["Terms of Use"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Privacy Policy"].exists)
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
