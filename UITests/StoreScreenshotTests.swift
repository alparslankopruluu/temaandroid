import XCTest

final class StoreScreenshotTests: XCTestCase {
    private struct LocaleShot {
        let language: String
        let locale: String
        let folder: String
    }

    private let shots: [LocaleShot] = [
        .init(language: "en", locale: "en_US", folder: "en-US"),
        .init(language: "tr", locale: "tr_TR", folder: "tr"),
        .init(language: "ar", locale: "ar_SA", folder: "ar-SA"),
        .init(language: "ja", locale: "ja_JP", folder: "ja"),
        .init(language: "zh-Hans", locale: "zh_CN", folder: "zh-Hans"),
        .init(language: "ru", locale: "ru_RU", folder: "ru"),
        .init(language: "es", locale: "es_ES", folder: "es-ES"),
        .init(language: "pt-BR", locale: "pt_BR", folder: "pt-BR"),
        .init(language: "de", locale: "de_DE", folder: "de-DE"),
        .init(language: "fr", locale: "fr_FR", folder: "fr-FR"),
        .init(language: "it", locale: "it_IT", folder: "it"),
        .init(language: "ko", locale: "ko_KR", folder: "ko"),
        .init(language: "zh-Hant", locale: "zh_TW", folder: "zh-Hant"),
        .init(language: "id", locale: "id_ID", folder: "id"),
        .init(language: "vi", locale: "vi_VN", folder: "vi"),
        .init(language: "th", locale: "th_TH", folder: "th"),
        .init(language: "hi", locale: "hi_IN", folder: "hi"),
        .init(language: "nl", locale: "nl_NL", folder: "nl-NL"),
        .init(language: "pl", locale: "pl_PL", folder: "pl"),
        .init(language: "sv", locale: "sv_SE", folder: "sv"),
        .init(language: "da", locale: "da_DK", folder: "da"),
        .init(language: "nb", locale: "nb_NO", folder: "no")
    ]

    @MainActor func testCaptureLocalizedStoreScreens() {
        for shot in shots {
            let app = XCUIApplication()
            app.launchArguments = [
                "-AppleLanguages", "(\(shot.language))",
                "-AppleLocale", shot.locale,
                "-welcome", "NO"
            ]
            app.launch()
            let start = app.buttons["startExploring"]
            XCTAssertTrue(start.waitForExistence(timeout: 8), "welcome missing for \(shot.folder)")
            capture("\(shot.folder)/02-welcome")
            start.tap()
            XCTAssertTrue(app.buttons["featuredTheme"].waitForExistence(timeout: 8), "discover missing for \(shot.folder)")
            capture("\(shot.folder)/01-discover")
            app.buttons["featuredTheme"].tap()
            XCTAssertTrue(app.buttons["editor.saveInstall"].waitForExistence(timeout: 8), "editor missing for \(shot.folder)")
            capture("\(shot.folder)/04-editor")
            app.buttons["editor.saveInstall"].tap()
            XCTAssertTrue(app.buttons["export.save"].waitForExistence(timeout: 8), "export missing for \(shot.folder)")
            capture("\(shot.folder)/03-export")
            app.terminate()
        }
    }

    @MainActor private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
