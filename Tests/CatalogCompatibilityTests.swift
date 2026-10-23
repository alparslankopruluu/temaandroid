import Foundation
import Testing
@testable import ScreenMotion

struct CatalogCompatibilityTests {
    private let legacyThemeIDs: Set<String> = [
        "midnight", "motorcycle", "bicycle", "tractor", "tank", "bus", "truck",
        "helicopter", "airplane", "spaceship", "reef", "jellyfish", "orbit",
        "nebula", "alpine", "forest"
    ]

    private let legacyFreeThemeIDs: Set<String> = ["midnight", "reef", "orbit", "alpine"]

    @Test("Catalog expansion preserves every legacy theme identifier")
    func legacyThemesRemainResolvable() throws {
        let catalog = ThemeCatalog.bundled

        for id in legacyThemeIDs {
            let theme = try #require(catalog.theme(id), "Missing legacy theme: \(id)")
            #expect(theme.id == id)
        }
    }

    @Test("Legacy access policy remains four free and twelve Pro themes")
    func legacyAccessBaselineRemainsStable() throws {
        let legacyThemes = try legacyThemeIDs.map { id in
            try #require(ThemeCatalog.bundled.theme(id), "Missing legacy theme: \(id)")
        }
        let freeIDs = Set(legacyThemes.filter(\.isFree).map(\.id))
        let proCount = legacyThemes.filter { $0.isFree == false }.count

        #expect(freeIDs == legacyFreeThemeIDs)
        #expect(proCount == 12)
    }

    @Test("Saved designs from the original schema still decode and resolve their theme")
    func legacySavedDesignRemainsCompatible() throws {
        let data = Data(
            """
            {
              "id": "01A1B2C3-D4E5-4678-9012-3456789ABCDE",
              "themeID": "midnight",
              "configuration": {
                "intensity": 0.8,
                "particles": 0.2,
                "depth": 0.7,
                "zoom": 1.3,
                "style": 2
              },
              "savedAt": 700000000
            }
            """.utf8
        )

        let design = try JSONDecoder().decode(SavedDesign.self, from: data)
        let theme = try #require(ThemeCatalog.bundled.theme(design.themeID))

        #expect(design.id.uuidString == "01A1B2C3-D4E5-4678-9012-3456789ABCDE")
        #expect(design.configuration == SceneConfiguration(
            intensity: 0.8,
            particles: 0.2,
            depth: 0.7,
            zoom: 1.3,
            style: 2
        ))
        #expect(design.savedAt.timeIntervalSinceReferenceDate == 700000000)
        #expect(theme.id == "midnight")
    }

    @Test("Legacy theme JSON does not require future optional fields")
    func legacyThemePayloadRemainsDecodable() throws {
        let data = Data(
            """
            {
              "id": "midnight",
              "titleKey": "theme.midnight",
              "collection": "vehicles",
              "artwork": "midnight",
              "isFree": true,
              "symbol": "car.side"
            }
            """.utf8
        )

        let theme = try JSONDecoder().decode(Theme.self, from: data)

        #expect(theme.id == "midnight")
        #expect(theme.isFree)
    }

    @Test("Discover hero skips a Pro scene that a remote order placed first")
    func featuredSceneIsAlwaysFree() throws {
        let catalog = ThemeCatalog.bundled
        let rainfire = try #require(catalog.theme("pixel-rainfire"))
        #expect(!rainfire.isFree)
        let reordered = [rainfire] + catalog.themes.filter { $0.id != rainfire.id }
        let featured = try #require(ThemeCatalog.featured(in: reordered))
        #expect(featured.isFree)
        #expect(ThemeCatalog.featured(in: [rainfire])?.id == rainfire.id)
    }
}
