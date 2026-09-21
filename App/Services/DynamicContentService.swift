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
    static let supportedSchemaVersion = 1

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
        let manifest: RemoteContentManifest
        do {
            manifest = try decoder.decode(RemoteContentManifest.self, from: data)
        } catch {
            throw RemoteContentValidationError.decodingFailed
        }

        guard manifest.schemaVersion == Self.supportedSchemaVersion else {
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

        return ValidatedRemoteContent(manifest: manifest)
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
