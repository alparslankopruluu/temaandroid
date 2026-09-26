import Foundation

protocol RemoteContentDataLoading: Sendable {
    func data(from url: URL) async throws -> Data
}

struct URLSessionRemoteContentLoader: RemoteContentDataLoading {
    func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

enum DynamicContentSource: Equatable, Sendable {
    case bundled
    case cache
    case remote
}

struct DynamicContentSnapshot: Equatable, Sendable {
    let content: ValidatedRemoteContent
    let source: DynamicContentSource
}

/// Loads public curation data. This actor never stores or derives purchase state.
actor DynamicContentService {
    static let supportedSchemaVersions: Set<Int> = [1, 2]
    static let maximumManifestBytes = 1_000_000

    private let bundledData: Data
    private let remoteManifestURL: URL?
    private let cacheURL: URL?
    private let currentAppVersion: String
    private let loader: any RemoteContentDataLoading
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    init(
        bundledData: Data,
        remoteManifestURL: URL? = nil,
        cacheURL: URL? = nil,
        currentAppVersion: String,
        loader: any RemoteContentDataLoading = URLSessionRemoteContentLoader(),
        fileManager: FileManager = .default
    ) {
        self.bundledData = bundledData
        self.remoteManifestURL = remoteManifestURL
        self.cacheURL = cacheURL
        self.currentAppVersion = currentAppVersion
        self.loader = loader
        self.fileManager = fileManager
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    /// Returns remote content when valid, otherwise the last-known-good cache,
    /// and finally the bundled baseline. Remote failures never erase the cache.
    func load() async throws -> DynamicContentSnapshot {
        let bundled = try validatedContent(from: bundledData)
        let cached = loadCachedContent()

        guard let remoteManifestURL else {
            if let cached { return DynamicContentSnapshot(content: cached, source: .cache) }
            return DynamicContentSnapshot(content: bundled, source: .bundled)
        }

        guard ValidatedRemoteContent.isSafeHTTPSBaseURL(remoteManifestURL) else {
            if let cached { return DynamicContentSnapshot(content: cached, source: .cache) }
            return DynamicContentSnapshot(content: bundled, source: .bundled)
        }

        do {
            let remoteData = try await loader.data(from: remoteManifestURL)
            let remote = try validatedContent(from: remoteData)
            try persistLastKnownGood(remote)
            return DynamicContentSnapshot(content: remote, source: .remote)
        } catch {
            if let cached { return DynamicContentSnapshot(content: cached, source: .cache) }
            return DynamicContentSnapshot(content: bundled, source: .bundled)
        }
    }

    func validatedContent(from data: Data) throws -> ValidatedRemoteContent {
        guard data.count <= Self.maximumManifestBytes else {
            throw RemoteContentValidationError.manifestTooLarge
        }
        let manifest: RemoteContentManifest
        do {
            manifest = try decoder.decode(RemoteContentManifest.self, from: data)
        } catch {
            throw RemoteContentValidationError.decodingFailed
        }

        guard Self.supportedSchemaVersions.contains(manifest.schemaVersion) else {
            throw RemoteContentValidationError.unsupportedSchema(manifest.schemaVersion)
        }
        guard Self.isVersion(manifest.contentVersion) else {
            throw RemoteContentValidationError.invalidContentVersion
        }
        guard Self.isVersion(manifest.minimumAppVersion), Self.isVersion(currentAppVersion) else {
            throw RemoteContentValidationError.invalidMinimumAppVersion
        }
        guard Self.compareVersions(currentAppVersion, manifest.minimumAppVersion) != .orderedAscending else {
            throw RemoteContentValidationError.appVersionTooOld(
                required: manifest.minimumAppVersion,
                current: currentAppVersion
            )
        }
        guard ValidatedRemoteContent.isSafeHTTPSBaseURL(manifest.assetBaseURL) else {
            throw RemoteContentValidationError.invalidAssetBaseURL
        }

        var itemIDs = Set<String>()
        for item in manifest.items {
            guard !item.id.isEmpty,
                  item.id.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_" )).contains($0) }) else {
                throw RemoteContentValidationError.invalidItemID
            }
            guard itemIDs.insert(item.id).inserted else {
                throw RemoteContentValidationError.duplicateItemID(item.id)
            }
            guard !item.localizedText.isEmpty,
                  item.localizedText.allSatisfy({ locale, fields in
                      !locale.isEmpty && !fields.isEmpty
                          && fields.allSatisfy { !$0.key.isEmpty && !$0.value.isEmpty }
                  }) else {
                throw RemoteContentValidationError.invalidLocalizedText(itemID: item.id)
            }
            for (name, path) in item.assets {
                guard !name.isEmpty,
                      ValidatedRemoteContent.safeAssetURL(baseURL: manifest.assetBaseURL, relativePath: path) != nil else {
                    throw RemoteContentValidationError.invalidAssetPath(itemID: item.id, name: name)
                }
            }
        }

        let themes = manifest.themes ?? []
        guard themes.count <= 48 else { throw RemoteContentValidationError.tooManyThemes }
        if manifest.schemaVersion == 1, !themes.isEmpty {
            throw RemoteContentValidationError.unsupportedSchema(1)
        }
        var themeIDs = Set<String>()
        for theme in themes {
            guard Self.isValidThemeID(theme.id) else {
                throw RemoteContentValidationError.invalidThemeID
            }
            guard themeIDs.insert(theme.id).inserted else {
                throw RemoteContentValidationError.duplicateThemeID(theme.id)
            }
            guard theme.localizedText["en"]?["title"]?.isEmpty == false,
                  theme.localizedText.allSatisfy({ locale, fields in
                      !locale.isEmpty && fields["title"]?.isEmpty == false
                          && fields.allSatisfy { !$0.key.isEmpty && !$0.value.isEmpty }
                          && (fields["title"]?.count ?? 0) <= 80
                          && (fields["summary"]?.count ?? 0) <= 240
                  }) else {
                throw RemoteContentValidationError.invalidThemeText(themeID: theme.id)
            }
            guard theme.assets["artwork"] != nil,
                  theme.assets.count <= 12,
                  theme.assets.allSatisfy({ name, path in
                      Self.isValidAssetName(name)
                          && Self.isVersionedThemeAssetPath(path, contentVersion: manifest.contentVersion)
                          && ValidatedRemoteContent.safeAssetURL(baseURL: manifest.assetBaseURL, relativePath: path) != nil
                  }) else {
                throw RemoteContentValidationError.invalidThemeAssets(themeID: theme.id)
            }
            guard !theme.scene.layers.isEmpty, theme.scene.layers.count <= 8,
                  theme.scene.layers.allSatisfy({ layer in
                      theme.assets[layer.asset] != nil
                          && layer.parallax.isFinite && (-1...1).contains(layer.parallax)
                          && layer.amount.isFinite && (0...1).contains(layer.amount)
                          && layer.period.isFinite && (0.5...90).contains(layer.period)
                  }),
                  (theme.scene.particles.map { emitters in
                      emitters.count <= 4
                          && emitters.allSatisfy { (0...120).contains($0.count) && $0.speed.isFinite && (0...2).contains($0.speed) }
                          && emitters.reduce(0) { $0 + $1.count } <= 160
                  } ?? true),
                  (theme.scene.light.map { light in
                      light.x.isFinite && (0...1).contains(light.x)
                          && light.y.isFinite && (0...1).contains(light.y)
                          && light.color.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
                          && light.radius.isFinite && (0...0.5).contains(light.radius)
                          && light.flicker.isFinite && (0...1).contains(light.flicker)
                          && light.period.isFinite && (0.5...30).contains(light.period)
                  } ?? true),
                  theme.scene.ambientAudioAsset.map({ theme.assets[$0] != nil }) ?? true else {
                throw RemoteContentValidationError.invalidSceneRecipe(themeID: theme.id)
            }
            if let audioAsset = theme.scene.ambientAudioAsset,
               let audioPath = theme.assets[audioAsset],
               !Self.isSupportedAudioPath(audioPath) {
                throw RemoteContentValidationError.invalidSceneRecipe(themeID: theme.id)
            }
            for layer in theme.scene.layers {
                guard let path = theme.assets[layer.asset], Self.isSupportedImagePath(path) else {
                    throw RemoteContentValidationError.invalidSceneRecipe(themeID: theme.id)
                }
            }
            guard Self.isSupportedImagePath(theme.assets["artwork"] ?? "") else {
                throw RemoteContentValidationError.invalidThemeAssets(themeID: theme.id)
            }
        }

        return ValidatedRemoteContent(manifest: manifest)
    }

    private static func isValidThemeID(_ value: String) -> Bool {
        guard (3...48).contains(value.count), value == value.lowercased() else { return false }
        return value.utf8.allSatisfy { byte in
            (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) || byte == 45
        }
    }

    private static func isValidAssetName(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 32 && value.utf8.allSatisfy { byte in
            (byte >= 97 && byte <= 122) || (byte >= 48 && byte <= 57) || byte == 45 || byte == 95
        }
    }

    private static func isSupportedImagePath(_ value: String) -> Bool {
        ["png", "jpg", "jpeg", "webp"].contains(URL(filePath: value).pathExtension.lowercased())
    }

    private static func isSupportedAudioPath(_ value: String) -> Bool {
        ["m4a", "mp3", "aac"].contains(URL(filePath: value).pathExtension.lowercased())
    }

    private static func isVersionedThemeAssetPath(_ value: String, contentVersion: String) -> Bool {
        let segments = value.split(separator: "/", omittingEmptySubsequences: false)
        return segments.count >= 3 && segments[0] == "assets" && segments[1] == Substring(contentVersion)
    }

    private func loadCachedContent() -> ValidatedRemoteContent? {
        guard let cacheURL,
              let data = try? Data(contentsOf: cacheURL) else {
            return nil
        }
        return try? validatedContent(from: data)
    }

    private func persistLastKnownGood(_ content: ValidatedRemoteContent) throws {
        guard let cacheURL else { return }
        let parentURL = cacheURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        let data = try encoder.encode(content.manifest)
        try data.write(to: cacheURL, options: [.atomic, .completeFileProtection])
    }

    private static func isVersion(_ value: String) -> Bool {
        let components = value.split(separator: ".", omittingEmptySubsequences: false)
        return !components.isEmpty && components.allSatisfy { component in
            !component.isEmpty && component.allSatisfy(\.isNumber)
        }
    }

    private static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = lhs.split(separator: ".").compactMap { Int($0) }
        let right = rhs.split(separator: ".").compactMap { Int($0) }
        for index in 0..<max(left.count, right.count) {
            let leftValue = index < left.count ? left[index] : 0
            let rightValue = index < right.count ? right[index] : 0
            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }
        return .orderedSame
    }
}
