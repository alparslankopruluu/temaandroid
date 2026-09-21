import Foundation

struct Theme: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let collection: ThemeCollection
    let artwork: String
    let isFree: Bool
    let symbol: String
    var appearance: ThemeAppearance = .realistic
    var interaction: InteractiveSceneBehavior.Profile?
    var titleOverride: String?
    var artworkURL: URL?

    var isPixel: Bool { appearance == .pixel }
    var displayTitle: String { titleOverride ?? NSLocalizedString(titleKey, comment: "") }

    private enum CodingKeys: String, CodingKey {
        case id, titleKey, collection, artwork, isFree, symbol, appearance, interaction, titleOverride, artworkURL
    }

    init(id: String, titleKey: String, collection: ThemeCollection, artwork: String,
         isFree: Bool, symbol: String, appearance: ThemeAppearance = .realistic,
         interaction: InteractiveSceneBehavior.Profile? = nil, titleOverride: String? = nil,
         artworkURL: URL? = nil) {
        self.id = id
        self.titleKey = titleKey
        self.collection = collection
        self.artwork = artwork
        self.isFree = isFree
        self.symbol = symbol
        self.appearance = appearance
        self.interaction = interaction
        self.titleOverride = titleOverride
        self.artworkURL = artworkURL
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        titleKey = try values.decode(String.self, forKey: .titleKey)
        collection = try values.decode(ThemeCollection.self, forKey: .collection)
        artwork = try values.decode(String.self, forKey: .artwork)
        isFree = try values.decode(Bool.self, forKey: .isFree)
        symbol = try values.decode(String.self, forKey: .symbol)
        appearance = try values.decodeIfPresent(ThemeAppearance.self, forKey: .appearance) ?? .realistic
        interaction = try values.decodeIfPresent(InteractiveSceneBehavior.Profile.self, forKey: .interaction)
        titleOverride = try values.decodeIfPresent(String.self, forKey: .titleOverride)
        artworkURL = try values.decodeIfPresent(URL.self, forKey: .artworkURL)
    }
}

enum ThemeAppearance: String, Codable, CaseIterable, Sendable {
    case realistic
    case pixel
}

enum ThemeCollection: String, Codable, CaseIterable, Identifiable, Sendable {
    case vehicles, ocean, cosmos, nature
    var id: String { rawValue }
    var titleKey: String { "collection.\(rawValue)" }
    var symbol: String {
        switch self { case .vehicles: "car.side"; case .ocean: "fish"; case .cosmos: "sparkles"; case .nature: "leaf" }
    }
}

struct SceneConfiguration: Codable, Equatable, Sendable {
    var intensity: Double = 0.55
    var particles: Double = 0.45
    var depth: Double = 0.5
    var zoom: Double = 1
    var style: Int = 0
    var scoreMode = false

    init(intensity: Double = 0.55, particles: Double = 0.45, depth: Double = 0.5,
         zoom: Double = 1, style: Int = 0, scoreMode: Bool = false) {
        self.intensity = intensity
        self.particles = particles
        self.depth = depth
        self.zoom = zoom
        self.style = style
        self.scoreMode = scoreMode
    }

    private enum CodingKeys: String, CodingKey {
        case intensity, particles, depth, zoom, style, scoreMode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        intensity = try values.decode(Double.self, forKey: .intensity)
        particles = try values.decode(Double.self, forKey: .particles)
        depth = try values.decode(Double.self, forKey: .depth)
        zoom = try values.decode(Double.self, forKey: .zoom)
        style = try values.decode(Int.self, forKey: .style)
        scoreMode = try values.decodeIfPresent(Bool.self, forKey: .scoreMode) ?? false
    }
}

struct SavedDesign: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var themeID: String
    var configuration: SceneConfiguration
    var savedAt: Date = Date()
}

struct ThemePackage: Identifiable, Sendable {
    let collection: ThemeCollection
    var id: String { collection.rawValue }
    static let symbols = ["phone.fill", "message.fill", "envelope.fill", "safari.fill", "camera.fill", "photo.fill", "music.note", "gearshape.fill", "calendar", "clock.fill", "map.fill", "cloud.sun.fill", "note.text", "checklist", "folder.fill", "cart.fill", "book.fill", "heart.fill", "play.rectangle.fill", "mic.fill", "calculator.fill", "globe", "house.fill", "star.fill"]
}

struct ThemeCatalog: Sendable {
    let themes: [Theme]
    static let bundled: ThemeCatalog = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(CatalogFile.self, from: data), catalog.version == 1 else {
            return ThemeCatalog(themes: [])
        }
        return ThemeCatalog(themes: catalog.themes)
    }()
    func theme(_ id: String) -> Theme? { themes.first { $0.id == id } }
    private struct CatalogFile: Decodable { let version: Int; let themes: [Theme] }
}
