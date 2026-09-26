import Foundation
import UIKit

enum RemoteAssetKind: Sendable {
    case thumbnail
    case image
    case audio

    var maximumBytes: Int {
        switch self {
        case .thumbnail: 3_000_000
        case .image: 15_000_000
        case .audio: 8_000_000
        }
    }

    func accepts(mimeType: String?) -> Bool {
        guard let mimeType = mimeType?.lowercased() else { return false }
        switch self {
        case .thumbnail, .image:
            return ["image/png", "image/jpeg", "image/webp"].contains(mimeType)
        case .audio:
            return ["audio/mp4", "audio/mpeg", "audio/aac", "audio/x-m4a"].contains(mimeType)
        }
    }
}

actor RemoteAssetCache {
    static let shared = RemoteAssetCache(
        directory: URL.cachesDirectory.appending(path: "remote-content/assets", directoryHint: .isDirectory)
    )

    private let directory: URL
    private let session: URLSession
    private let fileManager: FileManager

    init(directory: URL, session: URLSession = .shared, fileManager: FileManager = .default) {
        self.directory = directory
        self.session = session
        self.fileManager = fileManager
    }

    func imageURL(source: URL, contentVersion: String, itemID: String) async -> URL? {
        await assetURL(source: source, contentVersion: contentVersion, itemID: itemID,
                       assetName: "artwork", kind: .image)
    }

    func thumbnailURL(source: URL, contentVersion: String, itemID: String) async -> URL? {
        await assetURL(source: source, contentVersion: contentVersion, itemID: itemID,
                       assetName: "artwork", kind: .thumbnail)
    }

    func imageURL(source: URL, contentVersion: String, itemID: String, assetName: String) async -> URL? {
        await assetURL(source: source, contentVersion: contentVersion, itemID: itemID,
                       assetName: assetName, kind: .image)
    }

    func audioURL(source: URL, contentVersion: String, itemID: String, assetName: String) async -> URL? {
        await assetURL(source: source, contentVersion: contentVersion, itemID: itemID,
                       assetName: assetName, kind: .audio)
    }

    func assetURL(source: URL, contentVersion: String, itemID: String,
                  assetName: String, kind: RemoteAssetKind) async -> URL? {
        guard ValidatedRemoteContent.isSafeHTTPSBaseURL(source),
              Self.isSafeComponent(contentVersion), Self.isSafeComponent(itemID),
              Self.isSafeComponent(assetName) else { return nil }

        let versionDirectory = directory.appending(path: contentVersion, directoryHint: .isDirectory)
        let fileExtension = source.pathExtension.lowercased()
        let destination = versionDirectory.appending(path: "\(itemID)-\(assetName).\(fileExtension)")
        if fileManager.fileExists(atPath: destination.path), Self.isUsable(destination, kind: kind) {
            return destination
        }

        do {
            var request = URLRequest(url: source)
            request.timeoutInterval = 20
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  kind.accepts(mimeType: response.mimeType),
                  data.count <= kind.maximumBytes,
                  Self.isDecodable(data, kind: kind) else { return nil }

            try fileManager.createDirectory(at: versionDirectory, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableDirectory = versionDirectory
            try? mutableDirectory.setResourceValues(values)
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            return destination
        } catch {
            return nil
        }
    }

    private static func isSafeComponent(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.allSatisfy { byte in
            (byte >= 48 && byte <= 57) || (byte >= 65 && byte <= 90)
                || (byte >= 97 && byte <= 122) || byte == 45 || byte == 95 || byte == 46
        } && value != "." && value != ".."
    }

    private static func isUsable(_ url: URL, kind: RemoteAssetKind) -> Bool {
        switch kind {
        case .thumbnail, .image:
            UIImage(contentsOfFile: url.path) != nil
        case .audio:
            ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) > 0
        }
    }

    private static func isDecodable(_ data: Data, kind: RemoteAssetKind) -> Bool {
        switch kind {
        case .thumbnail, .image:
            UIImage(data: data) != nil
        case .audio:
            !data.isEmpty
        }
    }
}
