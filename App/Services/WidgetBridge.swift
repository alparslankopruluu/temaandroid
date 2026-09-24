import Foundation
import WidgetKit
#if !WIDGET_EXTENSION
import UIKit
#endif

struct WidgetSnapshot: Codable, Sendable {
    var themeID: String
    var titleKey: String
    var collection: String
    var artworkFile: String
    static let group = "group.com.screenmotion.studio"
    static let filename = "widget-snapshot.json"
    static var placeholder: WidgetSnapshot {
        .init(themeID: "", titleKey: "widget.choose", collection: "ocean", artworkFile: "")
    }
    static func read() -> WidgetSnapshot {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              let data = try? Data(contentsOf: directory.appendingPathComponent(filename)),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data) else { return .placeholder }
        return snapshot
    }
    var artworkURL: URL? {
        guard !artworkFile.isEmpty else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.group)?.appendingPathComponent(artworkFile)
    }
    var deepLink: URL? { URL(string: themeID.isEmpty ? "screenmotion://home" : "screenmotion://theme/\(themeID)") }
}

#if !WIDGET_EXTENSION
@MainActor
enum WidgetBridge {
    static func select(theme: Theme, configuration: SceneConfiguration) async throws {
        guard let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: WidgetSnapshot.group) else {
            throw WidgetBridgeError.unavailable
        }
        guard await SceneFrameRenderer.prepare(theme: theme) else { throw WidgetBridgeError.artwork }
        let image = SceneFrameRenderer.image(theme: theme, configuration: configuration,
                                             size: CGSize(width: 600, height: 800), time: 1)
        guard let image, let data = image.jpegData(compressionQuality: 0.88) else {
            throw WidgetBridgeError.artwork
        }
        let snapshot = WidgetSnapshot(themeID: theme.id, titleKey: theme.displayTitle, collection: theme.collection.rawValue, artworkFile: "selected-artwork.jpg")
        try await Task.detached(priority: .utility) {
            try data.write(to: directory.appendingPathComponent(snapshot.artworkFile), options: .atomic)
            try JSONEncoder().encode(snapshot).write(to: directory.appendingPathComponent(WidgetSnapshot.filename), options: .atomic)
        }.value
        WidgetCenter.shared.reloadAllTimelines()
    }
}

enum WidgetBridgeError: LocalizedError {
    case unavailable, artwork
    var errorDescription: String? {
        String(localized: self == .unavailable ? "widget.error.group" : "widget.error.artwork")
    }
}
#endif
