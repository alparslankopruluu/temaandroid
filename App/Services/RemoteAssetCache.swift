import Foundation
import UIKit

actor RemoteAssetCache {
    private let directory: URL
    private let session: URLSession
    private let fileManager: FileManager

    init(directory: URL, session: URLSession = .shared, fileManager: FileManager = .default) {
        self.directory = directory
        self.session = session
        self.fileManager = fileManager
    }

    func imageURL(source: URL, contentVersion: String, itemID: String) async -> URL? {
        let versionDirectory = directory.appending(path: contentVersion, directoryHint: .isDirectory)
        let destination = versionDirectory.appending(path: itemID + "-artwork.img")
        if fileManager.fileExists(atPath: destination.path), UIImage(contentsOfFile: destination.path) != nil {
            return destination
        }
        do {
            let (data, response) = try await session.data(from: source)
            guard let response = response as? HTTPURLResponse,
                  (200...299).contains(response.statusCode),
                  response.mimeType?.hasPrefix("image/") == true,
                  data.count <= 15_000_000,
                  UIImage(data: data) != nil else { return nil }
            try fileManager.createDirectory(at: versionDirectory, withIntermediateDirectories: true)
            try data.write(to: destination, options: [.atomic, .completeFileProtection])
            return destination
        } catch {
            return nil
        }
    }
}
