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

    @MainActor func testRainfireThemeLoadsFromRemoteCatalogAndOpensInEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        let filter = app.segmentedControls["appearanceFilter"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.buttons["Pixel"].tap()
        let rainfire = app.buttons["theme.pixel-rainfire"]
        XCTAssertTrue(rainfire.waitForExistence(timeout: 10))
        rainfire.tap()
        let preview = app.descendants(matching: .any)["scenePreview.pixel-rainfire"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[
            "Rain falls over a quiet island cabin while firelight, smoke and embers respond to your touch."
        ].waitForExistence(timeout: 10))
        capture("editor-pixel-rainfire")
        let sceneCenter = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
        sceneCenter.tap()
        capture("editor-pixel-rainfire-after-tap")
        let dragStart = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.38, dy: 0.64))
        let dragEnd = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.62, dy: 0.48))
        dragStart.press(forDuration: 0.2, thenDragTo: dragEnd)
        XCTAssertTrue(preview.exists)
        capture("editor-pixel-rainfire-after-drag")
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
