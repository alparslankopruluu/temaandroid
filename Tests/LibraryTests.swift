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
    func testCatalogHasTwentyThreeLoopScenesAndThirteenPixelScenes() {
        let themes = ThemeCatalog.bundled.themes
        XCTAssertEqual(themes.count, 36)
        XCTAssertEqual(Set(themes.map(\.id)).count, 36)
        XCTAssertEqual(themes.filter { $0.appearance == .realistic }.count, 23)
        // Halloween scenes are Pro in the catalog (one is a seasonal gift), so the five starters stay the permanent free tier.
        XCTAssertEqual(themes.filter(\.isHalloween).map(\.id), ["halloween-moon", "halloween-pumpkins", "halloween-ghosts"])
        XCTAssertEqual(themes.filter { $0.isFree && !$0.isHalloween }.count, 5)
        // Every non-pixel scene ships a cinematic loop; pixel scenes keep their interactive renderer.
        XCTAssertEqual(themes.filter { $0.appearance == .realistic && $0.loopResource == nil }.map(\.id), [])
        XCTAssertEqual(themes.filter { $0.isPixel && $0.loopResource != nil }.map(\.id), [])
        XCTAssertEqual(themes.filter { $0.appearance == .pixel }.count, 13)
        XCTAssertEqual(themes.filter { $0.appearance == .pixel && $0.isFree }.map(\.id), ["pixel-car"])
        XCTAssertEqual(Set(themes.filter(\.isPixel).map(\.titleKey)), Set([
            "theme.pixel-car", "theme.pixel-motorcycle", "theme.pixel-helicopter",
            "theme.pixel-spaceship", "theme.pixel-reef", "theme.pixel-forest",
            "theme.pixel-ufo", "theme.pixel-aquarium", "theme.pixel-autumn",
            "theme.pixel-race", "theme.pixel-koi", "theme.pixel-snow", "theme.pixel-rainfire"
        ]))
        for collection in ThemeCollection.allCases {
            XCTAssertEqual(themes.filter { $0.collection == collection && $0.appearance == .realistic && $0.isFree && !$0.isHalloween }.count, 1)
        }
    }
    @MainActor func testInstallProgressIsScopedToExactDesignAndPersists() throws {
        let name = "ScreenMotionInstallTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = SceneConfiguration(intensity: 0.4)
        let second = SceneConfiguration(intensity: 0.9)
        let store = LibraryStore(defaults: defaults)
        for step in 1...3 { store.toggleInstallationStep(step, kind: .wallpaper, themeID: "pixel-ufo", configuration: second) }
        XCTAssertFalse(store.installationProgress(themeID: "pixel-ufo", configuration: second).installed.contains(.wallpaper))
        store.markExported(.wallpaper, themeID: "pixel-ufo", configuration: first)
        for step in 1...3 { store.toggleInstallationStep(step, kind: .wallpaper, themeID: "pixel-ufo", configuration: first) }
        let reopened = LibraryStore(defaults: defaults)
        let installed = reopened.installationProgress(themeID: "pixel-ufo", configuration: first)
        XCTAssertTrue(installed.exported.contains(.wallpaper))
        XCTAssertTrue(installed.installed.contains(.wallpaper))
        let otherDesign = reopened.installationProgress(themeID: "pixel-ufo", configuration: second)
        XCTAssertEqual(otherDesign.completedSteps, Set(["wallpaper.1", "wallpaper.2", "wallpaper.3"]))
        XCTAssertTrue(otherDesign.exported.isEmpty)
        XCTAssertTrue(otherDesign.installed.isEmpty)
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
    @MainActor func testOnboardingInterestsAndNightstandPickPersist() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = LibraryStore(defaults: defaults)
        XCTAssertFalse(store.hasSeenLaunchPaywall)
        store.setInterests(["halloween", "ocean"])
        store.setNightstandTheme("aurora")
        store.markLaunchPaywallSeen()
        let reopened = LibraryStore(defaults: defaults)
        XCTAssertEqual(reopened.interests, ["halloween", "ocean"])
        XCTAssertEqual(reopened.nightstandThemeID, "aurora")
        XCTAssertTrue(reopened.hasSeenLaunchPaywall)
        let catalog = ThemeCatalog.bundled
        XCTAssertEqual(catalog.nightstandTheme("aurora")?.id, "aurora")
        // A pick that left the catalog falls back to the free featured scene instead of a blank screen.
        XCTAssertEqual(catalog.nightstandTheme("removed-scene")?.isFree, true)
    }
    func testHalloweenSeasonLeadsOffersButNeverTheFreeHero() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let inSeason = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 24)))
        let afterSeason = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 3)))
        XCTAssertTrue(ThemeCatalog.isHalloweenSeason(inSeason))
        XCTAssertFalse(ThemeCatalog.isHalloweenSeason(afterSeason))
        let themes = ThemeCatalog.bundled.themes
        XCTAssertEqual(ThemeCatalog.offer(in: themes, on: inSeason)?.isHalloween, true)
        XCTAssertEqual(ThemeCatalog.offer(in: themes, on: afterSeason)?.isHalloween, false)
        XCTAssertEqual(ThemeCatalog.offer(in: themes, on: afterSeason)?.isFree, false)
        XCTAssertEqual(ThemeCatalog.featured(in: themes)?.isFree, true)
        XCTAssertEqual(DiscoverFilter.visible(in: themes).first, .all)
        XCTAssertTrue(DiscoverFilter.interests(in: themes).contains(.halloween))
        XCTAssertFalse(DiscoverFilter.visible(in: themes.filter { !$0.isHalloween }).contains(.halloween))
        XCTAssertTrue(Theme.isSeasonalGift(id: "halloween-pumpkins", on: inSeason))
        XCTAssertFalse(Theme.isSeasonalGift(id: "halloween-pumpkins", on: afterSeason))
        XCTAssertFalse(Theme.isSeasonalGift(id: "halloween-moon", on: inSeason))
    }
    func testYearlySavingsBadgeMath() {
        XCTAssertEqual(PaywallMath.yearlySavingsPercent(yearly: Decimal(string: "29.99")!, monthly: Decimal(string: "6.99")!), 64)
        XCTAssertNil(PaywallMath.yearlySavingsPercent(yearly: Decimal(string: "79.99")!, monthly: Decimal(string: "6.99")!))
        XCTAssertNil(PaywallMath.yearlySavingsPercent(yearly: 10, monthly: 0))
    }
    func testPushLinksOnlyOpenScreenMotionRoutes() {
        XCTAssertEqual(PushService.link(from: ["link": "screenmotion://discover/halloween"])?.host, "discover")
        XCTAssertEqual(PushService.link(from: ["link": "screenmotion://offer"])?.host, "offer")
        XCTAssertNil(PushService.link(from: ["link": "https://example.com/phish"]))
        XCTAssertNil(PushService.link(from: ["title": "no link"]))
    }
}
