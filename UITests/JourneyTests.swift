import XCTest

final class JourneyTests: XCTestCase {
    @MainActor func testDiscoverEditSaveAndInstallationJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-launch-paywall", "YES"]
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
            app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-launch-paywall", "YES"]
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
        app.launchArguments = ["-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR", "-launch-paywall", "YES"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 5))
        app.buttons["featuredTheme"].tap()
        let export = app.buttons["Kaydet ve kur"]
        XCTAssertTrue(export.waitForExistence(timeout: 5))
        export.tap()
        // Only live output is offered: a still or plain video cannot be a moving wallpaper.
        XCTAssertTrue(app.staticTexts["Kilit ekranın için kısa bir animasyon"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Her ekrana uygun, net bir duvar kâğıdı"].exists)
        XCTAssertFalse(app.staticTexts["Paylaşmak için 3 saniyelik video"].exists)
        XCTAssertFalse(app.staticTexts["export.hint.livePhoto"].exists)
    }
    @MainActor func testPixelThemeOpensInsideExistingEditor() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-launch-paywall", "YES"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        let filter = app.buttons["filter.pixel"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.tap()
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
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-launch-paywall", "YES"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        let filter = app.buttons["filter.pixel"]
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        filter.tap()
        let rainfire = app.buttons["theme.pixel-rainfire"]
        // Rainfire sits at its catalog position near the end of the pixel list, below the fold.
        for _ in 0..<6 where !rainfire.isHittable { app.swipeUp() }
        XCTAssertTrue(rainfire.waitForExistence(timeout: 10))
        rainfire.tap()
        // Browsing never interrupts: a locked scene opens its free preview, and the offer waits for Save.
        XCTAssertFalse(app.buttons["pro.previewFirst"].waitForExistence(timeout: 2))
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
        app.buttons["editor.saveInstall"].tap()
        let unlock = app.buttons["pro.unlock"]
        XCTAssertTrue(unlock.waitForExistence(timeout: 5))
        unlock.tap()
        XCTAssertTrue(app.buttons["Restore purchases"].waitForExistence(timeout: 12))
    }

    @MainActor func testPaywallLoadsProductsAndComplianceActions() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-launch-paywall", "YES"]
        app.launch()

        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }

        let pro = app.buttons["proButton"]
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

    @MainActor func testWelcomeOffersDismissiblePaywallOnce() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-welcome", "NO", "-launch-paywall", "NO"]
        app.launch()
        let start = app.buttons["startExploring"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let close = app.buttons["action.close"]
        XCTAssertTrue(close.waitForExistence(timeout: 12))
        capture("paywall-welcome")
        close.tap()
        XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 5))
    }

    @MainActor func testOnboardingPagesInterestsAndOfferWithThreePlans() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-welcome", "NO", "-launch-paywall", "NO"]
        app.launch()
        let show = app.buttons["welcome.start"]
        XCTAssertTrue(show.waitForExistence(timeout: 8))
        capture("onboarding-1")
        let next = app.buttons["onboarding.next"]
        // A tap during the first paging layout pass can be dropped on a cold simulator; one retry keeps the test honest.
        for _ in 0..<2 where !next.exists {
            if show.isHittable { show.tap() }
            _ = next.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(next.exists)
        capture("onboarding-2")
        next.tap()
        let ocean = app.buttons["interest.ocean"]
        XCTAssertTrue(ocean.waitForExistence(timeout: 5))
        ocean.tap()
        XCTAssertTrue(ocean.isSelected)
        capture("onboarding-3")
        app.buttons["onboarding.interests.done"].tap()
        XCTAssertTrue(app.buttons["Restore purchases"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Yearly"].exists)
        XCTAssertTrue(app.staticTexts["Monthly"].exists)
        XCTAssertTrue(app.staticTexts["Lifetime"].exists)
        XCTAssertTrue(app.staticTexts["$29.99 per year"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Save 64%"].exists)
        // Trial eligibility follows StoreKit history on this simulator; when offered, its price line must be exact.
        if app.buttons["pro.startTrial"].exists {
            XCTAssertTrue(app.staticTexts["No payment now. 3 days free, then $29.99 per year."].exists)
        } else {
            XCTAssertTrue(app.buttons["pro.continue"].exists)
        }
        capture("paywall-onboarding")
        app.staticTexts["Lifetime"].tap()
        XCTAssertTrue(app.staticTexts["One payment. No subscription."].waitForExistence(timeout: 3))
        capture("paywall-lifetime")
        app.buttons["action.close"].tap()
        XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 5))
    }

    @MainActor func testVideoToLivePhotoAndNightstandOpenFromDiscover() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-launch-paywall", "YES"]
        app.launch()
        let start = app.buttons["startExploring"]
        if start.waitForExistence(timeout: 3) { start.tap() }
        let video = app.buttons["openVideoLive"]
        XCTAssertTrue(video.waitForExistence(timeout: 5))
        video.tap()
        XCTAssertTrue(app.buttons["video.choose"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Free videos left: 2"].exists)
        capture("video-live")
        app.buttons["Close"].tap()
        let nightstand = app.buttons["openNightstand"]
        XCTAssertTrue(nightstand.waitForExistence(timeout: 5))
        nightstand.tap()
        sleep(2)
        capture("nightstand")
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
