import XCTest
@testable import ScreenMotion

final class DynamicContentTests: XCTestCase {
    func testBundledFallbackIsUsedWhenRemoteFails() async throws {
        let service = DynamicContentService(
            bundledData: manifestData(version: "1"),
            remoteManifestURL: URL(string: "https://assets.example.com/manifest.json"),
            currentAppVersion: "1.0",
            loader: StubRemoteContentLoader(result: .failure(URLError(.notConnectedToInternet)))
        )

        let snapshot = try await service.load()

        XCTAssertEqual(snapshot.source, .bundled)
        XCTAssertEqual(snapshot.content.manifest.contentVersion, "1")
    }

    func testInvalidSchemaAndUnsafeAssetPathsAreRejected() async throws {
        let service = DynamicContentService(
            bundledData: manifestData(version: "1"),
            currentAppVersion: "1.0"
        )

        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: manifestData(schema: 3))) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .unsupportedSchema(3))
        }
        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: manifestData(assetPath: "../secret.jpg"))) { error in
            XCTAssertEqual(
                error as? RemoteContentValidationError,
                .invalidAssetPath(itemID: "pro-scene", name: "hero")
            )
        }
        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: manifestData(baseURL: "http://assets.example.com/v1/"))) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .invalidAssetBaseURL)
        }
    }

    func testAccessPolicyUsesCallerEntitlementWithoutGrantingIt() async throws {
        let service = DynamicContentService(
            bundledData: manifestData(version: "1"),
            currentAppVersion: "1.0"
        )
        let content = try await service.validatedContent(from: manifestData(version: "1"))

        XCTAssertEqual(content.accessibleItems(isProEntitled: false).map(\.id), ["free-scene"])
        XCTAssertEqual(content.accessibleItems(isProEntitled: true).map(\.id), ["free-scene", "pro-scene"])
    }

    func testValidRemoteBecomesLastKnownGoodForLaterFailure() async throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenMotion-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("remote-content.json")
        defer { try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent()) }
        let manifestURL = try XCTUnwrap(URL(string: "https://assets.example.com/manifest.json"))

        let firstService = DynamicContentService(
            bundledData: manifestData(version: "1"),
            remoteManifestURL: manifestURL,
            cacheURL: cacheURL,
            currentAppVersion: "1.0",
            loader: StubRemoteContentLoader(result: .success(manifestData(version: "2")))
        )
        let remote = try await firstService.load()
        XCTAssertEqual(remote.source, .remote)
        XCTAssertEqual(remote.content.manifest.contentVersion, "2")

        let offlineService = DynamicContentService(
            bundledData: manifestData(version: "1"),
            remoteManifestURL: manifestURL,
            cacheURL: cacheURL,
            currentAppVersion: "1.0",
            loader: StubRemoteContentLoader(result: .failure(URLError(.notConnectedToInternet)))
        )
        let cached = try await offlineService.load()

        XCTAssertEqual(cached.source, .cache)
        XCTAssertEqual(cached.content.manifest.contentVersion, "2")
    }

    func testMinimumAppVersionFallsBackInsteadOfReplacingCache() async throws {
        let cacheURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenMotion-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("remote-content.json")
        defer { try? FileManager.default.removeItem(at: cacheURL.deletingLastPathComponent()) }
        let manifestURL = try XCTUnwrap(URL(string: "https://assets.example.com/manifest.json"))

        let seed = DynamicContentService(
            bundledData: manifestData(version: "1"),
            remoteManifestURL: manifestURL,
            cacheURL: cacheURL,
            currentAppVersion: "1.0",
            loader: StubRemoteContentLoader(result: .success(manifestData(version: "2")))
        )
        _ = try await seed.load()

        let incompatible = DynamicContentService(
            bundledData: manifestData(version: "1"),
            remoteManifestURL: manifestURL,
            cacheURL: cacheURL,
            currentAppVersion: "1.0",
            loader: StubRemoteContentLoader(result: .success(manifestData(version: "3", minimumAppVersion: "2.0")))
        )
        let snapshot = try await incompatible.load()

        XCTAssertEqual(snapshot.source, .cache)
        XCTAssertEqual(snapshot.content.manifest.contentVersion, "2")
    }

    func testSchemaTwoAcceptsNewLocalizedSceneWithBoundedLayersParticlesLightAndAudio() async throws {
        let service = DynamicContentService(
            bundledData: manifestData(version: "1"),
            currentAppVersion: "1.0.2"
        )

        let content = try await service.validatedContent(from: remoteThemeManifestData())

        XCTAssertEqual(content.remoteThemes.map(\.id), ["pixel-rainfire"])
        XCTAssertEqual(content.assetURL(themeID: "pixel-rainfire", name: "artwork")?.lastPathComponent, "rainfire.png")
        XCTAssertEqual(content.assetURL(themeID: "pixel-rainfire", name: "ambience")?.lastPathComponent, "rain.m4a")
        XCTAssertEqual(content.remoteThemes.first?.scene.particles?.count, 3)
        XCTAssertEqual(content.remoteThemes.first?.scene.ambientAudioAsset, "ambience")
    }

    func testSchemaTwoRejectsUnsafeAndUnboundedThemeRecipes() async throws {
        let service = DynamicContentService(bundledData: manifestData(version: "1"), currentAppVersion: "1.0.2")

        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: remoteThemeManifestData(assetPath: "../rainfire.png"))) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .invalidThemeAssets(themeID: "pixel-rainfire"))
        }
        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: remoteThemeManifestData(particleCount: 161))) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .invalidSceneRecipe(themeID: "pixel-rainfire"))
        }
        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: remoteThemeManifestData(assetPath: "assets/rainfire.png"))) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .invalidThemeAssets(themeID: "pixel-rainfire"))
        }
    }

    func testSchemaTwoRejectsIntegerOverflowInParticleBudget() async throws {
        let service = DynamicContentService(bundledData: manifestData(version: "1"), currentAppVersion: "1.0.2")

        await XCTAssertThrowsErrorAsync(try await service.validatedContent(
            from: remoteThemeManifestData(particleCount: Int.max)
        )) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .invalidSceneRecipe(themeID: "pixel-rainfire"))
        }
    }

    private func remoteThemeManifestData(assetPath: String = "assets/2/rainfire.png", particleCount: Int = 32) -> Data {
        let json = """
        {
          "schemaVersion": 2,
          "contentVersion": "2",
          "minimumAppVersion": "1.0.2",
          "assetBaseURL": "https://assets.example.com/v2/",
          "items": [],
          "themes": [
            {
              "id": "pixel-rainfire",
              "localizedText": {"en": {"title": "Rainfire Cabin", "summary": "Rain and fire."}, "tr": {"title": "Yağmur Ateşi", "summary": "Yağmur ve ateş."}},
              "isVisible": true,
              "order": 1,
              "accessPolicy": "pro",
              "appearance": "pixel",
              "collection": "nature",
              "symbol": "house.fill",
              "assets": {"artwork": "\(assetPath)", "ambience": "assets/2/rain.m4a"},
              "scene": {
                "layers": [{"asset": "artwork", "parallax": 0.5, "animation": "drift", "amount": 0.2, "period": 18}],
                "particles": [
                  {"preset": "rain", "count": \(particleCount), "speed": 0.8},
                  {"preset": "ember", "count": 24, "speed": 1.1},
                  {"preset": "smoke", "count": 12, "speed": 0.3}
                ],
                "light": {"x": 0.8, "y": 0.3, "color": "#FF8B37", "radius": 0.2, "flicker": 0.8, "period": 1.2},
                "interaction": "emberBurst",
                "ambientAudioAsset": "ambience"
              }
            }
          ]
        }
        """
        return Data(json.utf8)
    }

    private func manifestData(
        schema: Int = 1,
        version: String = "1",
        minimumAppVersion: String = "1.0",
        baseURL: String = "https://assets.example.com/public/v1/",
        assetPath: String = "en/hero.jpg"
    ) -> Data {
        let json = """
        {
          "schemaVersion": \(schema),
          "contentVersion": "\(version)",
          "minimumAppVersion": "\(minimumAppVersion)",
          "assetBaseURL": "\(baseURL)",
          "items": [
            {
              "id": "pro-scene",
              "localizedText": { "en": { "title": "Pro" } },
              "isVisible": true,
              "order": 2,
              "accessPolicy": "pro",
              "assets": { "hero": "\(assetPath)" }
            },
            {
              "id": "free-scene",
              "localizedText": { "en": { "title": "Free" } },
              "isVisible": true,
              "order": 1,
              "accessPolicy": "free",
              "assets": { "hero": "en/free.jpg" }
            }
          ]
        }
        """
        return Data(json.utf8)
    }
}

private struct StubRemoteContentLoader: RemoteContentDataLoading {
    let result: Result<Data, Error>

    func data(from url: URL) async throws -> Data {
        try result.get()
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
