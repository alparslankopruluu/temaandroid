import XCTest
@testable import ScreenMotion

final class LibraryTests: XCTestCase {
    @MainActor func testDraftFavoriteRewardAndInstallProgressSurviveRelaunch() throws {
        let name = "ScreenMotionTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = LibraryStore(defaults: defaults)
        let theme = try XCTUnwrap(ThemeCatalog.bundled.theme("midnight"))
        let config = SceneConfiguration(intensity: 0.8, particles: 0.2, depth: 0.7, zoom: 1.3, style: 2)
        store.save(theme, configuration: config)
        store.save(theme, configuration: config)
        store.toggleFavorite(theme.id)
        store.grantReward("motorcycle")
        store.toggleStep("install.wallpaper.1")
        let reopened = LibraryStore(defaults: defaults)
        XCTAssertEqual(reopened.designs.count, 1)
        XCTAssertEqual(reopened.designs.first?.configuration, config)
        XCTAssertTrue(reopened.favorites.contains(theme.id))
        XCTAssertTrue(reopened.installationSteps.contains("install.wallpaper.1"))
        XCTAssertTrue(reopened.rewards.contains("motorcycle"))
        reopened.consumeReward("motorcycle")
        XCTAssertFalse(LibraryStore(defaults: defaults).rewards.contains("motorcycle"))
    }
    func testCatalogPreservesRealisticBaselineAndAddsSixPixelScenes() {
        let themes = ThemeCatalog.bundled.themes
        XCTAssertEqual(themes.count, 22)
        XCTAssertEqual(Set(themes.map(\.id)).count, 22)
        XCTAssertEqual(themes.filter { $0.appearance == .realistic }.count, 16)
        XCTAssertEqual(themes.filter { $0.appearance == .pixel }.count, 6)
        XCTAssertEqual(themes.filter { $0.appearance == .pixel && $0.isFree }.map(\.id), ["pixel-car"])
        XCTAssertEqual(Set(themes.filter(\.isPixel).map(\.titleKey)), Set([
            "theme.pixel-car", "theme.pixel-motorcycle", "theme.pixel-helicopter",
            "theme.pixel-spaceship", "theme.pixel-reef", "theme.pixel-forest"
        ]))
        for collection in ThemeCollection.allCases {
            XCTAssertEqual(themes.filter { $0.collection == collection && $0.appearance == .realistic && $0.isFree }.count, 1)
        }
    }
    @MainActor func testRewardCancelledBeforeCompletionNeverGrantsSuccess() async {
        let service = RewardedAdService()
        let task = Task { try await service.playTest() }
        task.cancel()
        do { try await task.value; XCTFail("Cancelled ad must not succeed") } catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(service.running)
    }
    @MainActor func testAllIconPacksExport24DistinctImages() async throws {
        for collection in ThemeCollection.allCases {
            let url = try await IconExportService.export(collection: collection)
            let files = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            XCTAssertEqual(files.count, 24)
            let contents = try files.map { try Data(contentsOf: $0) }
            XCTAssertEqual(Set(contents).count, 24)
            try FileManager.default.removeItem(at: url)
        }
    }
}
