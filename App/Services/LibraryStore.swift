import Foundation
import Observation

enum InstallKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case wallpaper, icons, widgets
    var id: String { rawValue }
    var steps: [String] { (1...3).map { "install.\(rawValue).\($0)" } }
    var symbols: [String] {
        switch self {
        case .wallpaper: ["photo.on.rectangle", "lock.rectangle", "checkmark.rectangle"]
        case .icons: ["square.and.arrow.down", "arrow.triangle.branch", "plus.app"]
        case .widgets: ["hand.tap", "plus.circle", "square.grid.2x2"]
        }
    }
}

struct DesignInstallationProgress: Codable, Equatable, Sendable {
    var exported: Set<InstallKind> = []
    var completedSteps: Set<String> = []
    var installed: Set<InstallKind> = []
}

@MainActor @Observable final class LibraryStore {
    var favorites: Set<String> = []
    var designs: [SavedDesign] = []
    var installationSteps: Set<String> = []
    private(set) var designInstallationProgress: [String: DesignInstallationProgress] = [:]
    var rewards: Set<String> = []
    var hasSeenWelcome = false
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        installationSteps = Set(defaults.stringArray(forKey: "steps") ?? [])
        if let data = defaults.data(forKey: "installation-progress.v2"),
           let decoded = try? JSONDecoder().decode([String: DesignInstallationProgress].self, from: data) {
            designInstallationProgress = decoded
        }
        rewards = Set(defaults.stringArray(forKey: "rewards") ?? [])
        hasSeenWelcome = defaults.bool(forKey: "welcome")
        if let data = defaults.data(forKey: "designs"), let decoded = try? JSONDecoder().decode([SavedDesign].self, from: data) { designs = decoded }
    }
    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        defaults.set(Array(favorites), forKey: "favorites")
    }
    func save(_ theme: Theme, configuration: SceneConfiguration) {
        if let index = designs.firstIndex(where: { $0.themeID == theme.id && $0.configuration == configuration }) { designs[index].savedAt = Date() }
        else { designs.insert(SavedDesign(themeID: theme.id, configuration: configuration), at: 0) }
        persistDesigns()
    }
    func delete(_ id: UUID) { designs.removeAll { $0.id == id }; persistDesigns() }
    func finishWelcome() { hasSeenWelcome = true; defaults.set(true, forKey: "welcome") }
    func toggleStep(_ key: String) {
        if installationSteps.contains(key) { installationSteps.remove(key) } else { installationSteps.insert(key) }
        defaults.set(Array(installationSteps), forKey: "steps")
    }
    func installationProgress(themeID: String, configuration: SceneConfiguration) -> DesignInstallationProgress {
        designInstallationProgress[Self.designKey(themeID: themeID, configuration: configuration)] ?? .init()
    }
    func markExported(_ kind: InstallKind, themeID: String, configuration: SceneConfiguration) {
        let key = Self.designKey(themeID: themeID, configuration: configuration)
        var progress = designInstallationProgress[key] ?? .init()
        progress.exported.insert(kind)
        designInstallationProgress[key] = progress
        persistInstallationProgress()
    }
    func toggleInstallationStep(_ step: Int, kind: InstallKind, themeID: String,
                                configuration: SceneConfiguration) {
        guard kind.steps.indices.contains(step - 1) else { return }
        let key = Self.designKey(themeID: themeID, configuration: configuration)
        var progress = designInstallationProgress[key] ?? .init()
        let stepKey = "\(kind.rawValue).\(step)"
        if progress.completedSteps.contains(stepKey) { progress.completedSteps.remove(stepKey) }
        else { progress.completedSteps.insert(stepKey) }
        let complete = progress.exported.contains(kind)
            && kind.steps.indices.allSatisfy { progress.completedSteps.contains("\(kind.rawValue).\($0 + 1)") }
        if complete { progress.installed.insert(kind) } else { progress.installed.remove(kind) }
        designInstallationProgress[key] = progress
        persistInstallationProgress()
    }
    static func designKey(themeID: String, configuration: SceneConfiguration) -> String {
        "\(themeID)|\(configuration.intensity)|\(configuration.particles)|\(configuration.depth)|\(configuration.zoom)|\(configuration.style)|\(configuration.scoreMode)"
    }
    func grantReward(_ id: String) { rewards.insert(id); defaults.set(Array(rewards), forKey: "rewards") }
    func consumeReward(_ id: String) { rewards.remove(id); defaults.set(Array(rewards), forKey: "rewards") }
    private func persistDesigns() { if let data = try? JSONEncoder().encode(designs) { defaults.set(data, forKey: "designs") } }
    private func persistInstallationProgress() {
        if let data = try? JSONEncoder().encode(designInstallationProgress) {
            defaults.set(data, forKey: "installation-progress.v2")
        }
    }
}
