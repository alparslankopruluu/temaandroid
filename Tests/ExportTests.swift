import AVFoundation
import ImageIO
import XCTest
@testable import ScreenMotion

final class ExportTests: XCTestCase {
    func testLivePhotoResourcesContainMatchingIdentifierAndTimedTrack() async throws {
        let writer = ExportWriter()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try await writer.prepare(directory, removing: nil)
        let imageURL = directory.appendingPathComponent("still.jpg")
        let movieURL = directory.appendingPathComponent("paired.mov")
        let identifier = UUID().uuidString
        guard let context = CGContext(data: nil, width: 64, height: 96, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue), let image = context.makeImage() else {
            XCTFail("Could not create test image")
            return
        }
        do {
            try await writer.writePhoto(image, to: imageURL, identifier: identifier)
            try await writer.beginVideo(at: movieURL, size: CGSize(width: 64, height: 96), identifier: identifier)
            for frame in 0..<90 { try await writer.append(image, frame: frame) }
            try await writer.finishVideo()
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(imageURL as CFURL, nil))
            let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any])
            let maker = try XCTUnwrap(properties[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any])
            XCTAssertEqual(maker["17"] as? String, identifier)
            let asset = AVURLAsset(url: movieURL)
            let metadata = try await asset.load(.metadata)
            let identity = try XCTUnwrap(metadata.first { ($0.key as? String) == "com.apple.quicktime.content.identifier" })
            let stringValue = try await identity.load(.stringValue)
            XCTAssertEqual(stringValue, identifier)
            let tracks = try await asset.loadTracks(withMediaType: .metadata)
            XCTAssertEqual(tracks.count, 1)
            let track = try XCTUnwrap(tracks.first)
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: nil)
            reader.add(output)
            let metadataReader = AVAssetReaderOutputMetadataAdaptor(assetReaderTrackOutput: output)
            XCTAssertTrue(reader.startReading())
            var stillGroup: AVTimedMetadataGroup?
            while let group = metadataReader.nextTimedMetadataGroup() {
                if group.items.contains(where: { ($0.key as? String) == "com.apple.quicktime.still-image-time" }) { stillGroup = group; break }
            }
            let group = try XCTUnwrap(stillGroup)
            XCTAssertEqual(CMTimeGetSeconds(group.timeRange.start), 1.5, accuracy: 0.04)
            let duration = try await asset.load(.duration)
            XCTAssertEqual(duration.seconds, 3, accuracy: 0.04)
            await writer.remove(directory)
        } catch {
            await writer.abort()
            await writer.remove(directory)
            throw error
        }
    }
}
