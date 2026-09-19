import Foundation

struct Theme: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let titleKey: String
    let collection: ThemeCollection
    let artwork: String
    let isFree: Bool
    let symbol: String
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
