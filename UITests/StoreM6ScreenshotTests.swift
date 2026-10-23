import XCTest

/// Raw 1.0.4 store captures. Skipped unless requested, e.g.
/// TEST_RUNNER_SCREENMOTION_SHOT_LOCALES="en-US,tr" xcodebuild test -only-testing:ScreenMotionUITests/StoreM6ScreenshotTests
final class StoreM6ScreenshotTests: XCTestCase {
    private struct Shot { let language: String; let locale: String; let folder: String }
    private let all: [Shot] = [
        .init(language: "en", locale: "en_US", folder: "en-US"), .init(language: "tr", locale: "tr_TR", folder: "tr"),
        .init(language: "de", locale: "de_DE", folder: "de-DE"), .init(language: "es", locale: "es_ES", folder: "es-ES"),
        .init(language: "fr", locale: "fr_FR", folder: "fr-FR"), .init(language: "it", locale: "it_IT", folder: "it"),
        .init(language: "pt-BR", locale: "pt_BR", folder: "pt-BR"), .init(language: "nl", locale: "nl_NL", folder: "nl-NL"),
        .init(language: "sv", locale: "sv_SE", folder: "sv"), .init(language: "da", locale: "da_DK", folder: "da"),
        .init(language: "nb", locale: "nb_NO", folder: "no"), .init(language: "pl", locale: "pl_PL", folder: "pl"),
        .init(language: "ru", locale: "ru_RU", folder: "ru"), .init(language: "ja", locale: "ja_JP", folder: "ja"),
        .init(language: "ko", locale: "ko_KR", folder: "ko"), .init(language: "zh-Hans", locale: "zh_CN", folder: "zh-Hans"),
        .init(language: "zh-Hant", locale: "zh_TW", folder: "zh-Hant"), .init(language: "ar", locale: "ar_SA", folder: "ar-SA"),
        .init(language: "hi", locale: "hi_IN", folder: "hi"), .init(language: "id", locale: "id_ID", folder: "id"),
        .init(language: "th", locale: "th_TH", folder: "th"), .init(language: "vi", locale: "vi_VN", folder: "vi")
    ]

    @MainActor func testCaptureM6StoreScreens() throws {
        let requested = ProcessInfo.processInfo.environment["SCREENMOTION_SHOT_LOCALES"]
        try XCTSkipIf(requested == nil, "Store captures run only on request")
        let wanted = requested == "all" ? all.map(\.folder) : requested!.split(separator: ",").map(String.init)
        for shot in all where wanted.contains(shot.folder) {
            let app = launch(shot, extra: [])
            let start = app.buttons["startExploring"]
            if start.waitForExistence(timeout: 8) { start.tap() }
            XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 8), "discover missing for \(shot.folder)")
            sleep(2)
            capture("\(shot.folder)/01-discover")
            let halloween = app.buttons["filter.halloween"]
            XCTAssertTrue(halloween.waitForExistence(timeout: 5), "halloween filter missing for \(shot.folder)")
            halloween.tap()
            app.swipeDown()
            sleep(2)
            capture("\(shot.folder)/06-halloween")
            // A filter keeps the header in place, so the cards read as a clean grid of Lock Screens.
            // Long localized pills push Underwater off screen, where a tap can land on its neighbour;
            // the in-app deep link selects the filter the same way an App Store event link does.
            app.open(try XCTUnwrap(URL(string: "screenmotion://discover/ocean")))
            XCTAssertTrue(app.buttons["filter.ocean"].waitForExistence(timeout: 5))
            // Long localized pills can scroll the page; return to the top so the header stays in frame.
            app.swipeDown()
            sleep(2)
            capture("\(shot.folder)/02-cards")
            let reef = app.buttons["theme.reef"]
            XCTAssertTrue(reef.waitForExistence(timeout: 5))
            reef.tap()
            XCTAssertTrue(app.buttons["editor.saveInstall"].waitForExistence(timeout: 8))
            sleep(2)
            capture("\(shot.folder)/03-editor")
            app.terminate()

            let video = launch(shot, extra: ["-demo-video", "abyss"])
            let open = video.buttons["openVideoLive"]
            XCTAssertTrue(open.waitForExistence(timeout: 8))
            open.tap()
            XCTAssertTrue(video.buttons["video.save"].waitForExistence(timeout: 10), "video editor missing for \(shot.folder)")
            sleep(2)
            capture("\(shot.folder)/04-video")
            video.terminate()

            let nightstand = launch(shot, extra: [])
            let openNightstand = nightstand.buttons["openNightstand"]
            XCTAssertTrue(openNightstand.waitForExistence(timeout: 8))
            openNightstand.tap()
            sleep(3)
            capture("\(shot.folder)/05-nightstand")
            nightstand.terminate()
        }
    }

    @MainActor private func launch(_ shot: Shot, extra: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(shot.language))", "-AppleLocale", shot.locale,
                               "-welcome", "YES", "-launch-paywall", "YES", "-demo-clock", "YES"]
            // US Lock Screens read 9:41, not 09:41.
            + (shot.folder == "en-US" ? ["-AppleICUForce12HourTime", "YES", "-AppleICUForce24HourTime", "NO"] : []) + extra
        app.launch()
        return app
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
