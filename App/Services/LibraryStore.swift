import Foundation
import Observation

@MainActor @Observable final class LibraryStore {
    var favorites: Set<String> = []
    var designs: [SavedDesign] = []
    var installationSteps: Set<String> = []
    var rewards: Set<String> = []
    var hasSeenWelcome = false
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favorites = Set(defaults.stringArray(forKey: "favorites") ?? [])
        installationSteps = Set(defaults.stringArray(forKey: "steps") ?? [])
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
    func grantReward(_ id: String) { rewards.insert(id); defaults.set(Array(rewards), forKey: "rewards") }
    func consumeReward(_ id: String) { rewards.remove(id); defaults.set(Array(rewards), forKey: "rewards") }
    private func persistDesigns() { if let data = try? JSONEncoder().encode(designs) { defaults.set(data, forKey: "designs") } }
}
