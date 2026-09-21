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

        await XCTAssertThrowsErrorAsync(try await service.validatedContent(from: manifestData(schema: 2))) { error in
            XCTAssertEqual(error as? RemoteContentValidationError, .unsupportedSchema(2))
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
