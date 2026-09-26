import Foundation

/// A signed-off data shape for remotely curated content. It can describe access,
/// but it cannot grant an entitlement; entitlement state is always supplied by the caller.
struct RemoteContentManifest: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let contentVersion: String
    let minimumAppVersion: String
    let assetBaseURL: URL
    let items: [RemoteContentItem]
    /// Additive schema-v2 catalog entries. Older v1 manifests decode with no themes.
    let themes: [RemoteThemeDefinition]?
}

struct RemoteContentItem: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let localizedText: [String: [String: String]]
    let isVisible: Bool
    let order: Int
    let accessPolicy: RemoteAccessPolicy
    /// Logical asset name to a relative, versioned path below `assetBaseURL`.
    let assets: [String: String]
}

/// A new theme is data, never downloaded executable code. Its renderer and interaction
/// vocabulary are compiled into the app and deliberately small/allow-listed.
struct RemoteThemeDefinition: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let localizedText: [String: [String: String]]
    let isVisible: Bool
    let order: Int
    let accessPolicy: RemoteAccessPolicy
    let appearance: ThemeAppearance
    let collection: ThemeCollection
    let symbol: String
    /// Logical asset name to a relative, versioned path below `assetBaseURL`.
    let assets: [String: String]
    let scene: RemoteSceneRecipe
}

struct RemoteSceneRecipe: Codable, Equatable, Hashable, Sendable {
    /// Layers use matching full-canvas transparent images, ordered back to front.
    let layers: [RemoteSceneLayer]
    let particles: [RemoteParticleEmitter]?
    let light: RemoteSceneLight?
    let interaction: RemoteTouchResponse
    let ambientAudioAsset: String?
}

struct RemoteSceneLight: Codable, Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let color: String
    let radius: Double
    let flicker: Double
    let period: Double
}

struct RemoteSceneLayer: Codable, Equatable, Hashable, Sendable {
    let asset: String
    let parallax: Double
    let animation: RemoteLayerAnimation
    let amount: Double
    let period: Double
}

enum RemoteLayerAnimation: String, Codable, CaseIterable, Hashable, Sendable {
    case still
    case sway
    case drift
    case flicker
    case pulse
}

struct RemoteParticleEmitter: Codable, Equatable, Hashable, Sendable {
    let preset: RemoteParticlePreset
    let count: Int
    let speed: Double
}

enum RemoteParticlePreset: String, Codable, CaseIterable, Hashable, Sendable {
    case rain
    case ember
    case smoke
    case firefly
    case snow
    case bubble
    case stardust
}

enum RemoteTouchResponse: String, Codable, CaseIterable, Hashable, Sendable {
    case none
    case push
    case ripple
    case swirl
    case emberBurst
    case bubbleTrail
}

enum RemoteAccessPolicy: String, Codable, Equatable, Sendable {
    case free
    case pro

    func allows(isProEntitled: Bool) -> Bool {
        switch self {
        case .free:
            return true
        case .pro:
            return isProEntitled
        }
    }
}

/// A manifest that has passed schema, compatibility and URL validation.
struct ValidatedRemoteContent: Equatable, Sendable {
    let manifest: RemoteContentManifest

    var remoteThemes: [RemoteThemeDefinition] {
        (manifest.themes ?? [])
            .filter(\.isVisible)
            .sorted {
                if $0.order == $1.order { return $0.id < $1.id }
                return $0.order < $1.order
            }
    }

    var visibleItems: [RemoteContentItem] {
        manifest.items
            .filter(\.isVisible)
            .sorted {
                if $0.order == $1.order { return $0.id < $1.id }
                return $0.order < $1.order
            }
    }

    func accessibleItems(isProEntitled: Bool) -> [RemoteContentItem] {
        visibleItems.filter { $0.accessPolicy.allows(isProEntitled: isProEntitled) }
    }

    func assetURL(itemID: String, name: String) -> URL? {
        guard let item = manifest.items.first(where: { $0.id == itemID }),
              let path = item.assets[name] else {
            return nil
        }
        return Self.safeAssetURL(baseURL: manifest.assetBaseURL, relativePath: path)
    }

    func assetURL(themeID: String, name: String) -> URL? {
        guard let theme = (manifest.themes ?? []).first(where: { $0.id == themeID }),
              let path = theme.assets[name] else {
            return nil
        }
        return Self.safeAssetURL(baseURL: manifest.assetBaseURL, relativePath: path)
    }

    static func safeAssetURL(baseURL: URL, relativePath: String) -> URL? {
        guard isSafeHTTPSBaseURL(baseURL),
              !relativePath.isEmpty,
              !relativePath.hasPrefix("/"),
              !relativePath.hasSuffix("/"),
              relativePath.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
              let decodedPath = relativePath.removingPercentEncoding,
              decodedPath == relativePath else {
            return nil
        }

        let segments = relativePath.split(separator: "/", omittingEmptySubsequences: false)
        guard !segments.isEmpty,
              segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains("\\") }) else {
            return nil
        }

        return segments.reduce(baseURL) { url, segment in
            url.appendingPathComponent(String(segment), isDirectory: false)
        }
    }

    static func isSafeHTTPSBaseURL(_ url: URL) -> Bool {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return false
        }
        return components.scheme?.lowercased() == "https"
            && components.host?.isEmpty == false
            && components.user == nil
            && components.password == nil
            && components.query == nil
            && components.fragment == nil
    }
}

enum RemoteContentValidationError: Error, Equatable, Sendable {
    case decodingFailed
    case unsupportedSchema(Int)
    case invalidContentVersion
    case invalidMinimumAppVersion
    case appVersionTooOld(required: String, current: String)
    case invalidAssetBaseURL
    case duplicateItemID(String)
    case invalidItemID
    case invalidLocalizedText(itemID: String)
    case invalidAssetPath(itemID: String, name: String)
    case manifestTooLarge
    case tooManyThemes
    case duplicateThemeID(String)
    case invalidThemeID
    case invalidThemeText(themeID: String)
    case invalidThemeAssets(themeID: String)
    case invalidSceneRecipe(themeID: String)
}
