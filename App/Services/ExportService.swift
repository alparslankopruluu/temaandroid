import AVFoundation
import ImageIO
import Observation
import Photos
import UIKit
import UniformTypeIdentifiers

/// Files remain available for sharing until the next export or the OS purges temporary storage.
enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case still, livePhoto, video
    var id: String { rawValue }
    var titleKey: String { "export.\(rawValue)" }
}

enum ExportFailure: LocalizedError {
    case busy, permission, renderer, storage, encoding, cancelled
    var errorDescription: String? {
        let key: String
        switch self {
        case .busy: key = "export.error.busy"
        case .permission: key = "export.error.permission"
        case .renderer: key = "export.error.renderer"
        case .storage: key = "export.error.storage"
        case .encoding: key = "export.error.encoding"
        case .cancelled: key = "export.error.cancelled"
        }
        return NSLocalizedString(key, comment: "")
    }
}

@MainActor @Observable final class ExportService {
    private(set) var progress = 0.0
    private(set) var isExporting = false
    private var cancelled = false
    private var previousDirectory: URL?

    func cancel() { cancelled = true }

    func export(theme: Theme, configuration: SceneConfiguration, format: ExportFormat) async throws -> URL {
        guard !isExporting else { throw ExportFailure.busy }
        isExporting = true
        cancelled = false
        progress = 0
        defer { isExporting = false }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ExportFailure.permission }
        try checkCancellation()
        let writer = ExportWriter()
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("screenmotion-\(UUID().uuidString)", isDirectory: true)
        var committed = false
        defer {
            if !committed { Task { await writer.remove(directory) } }
        }
        do {
            try await writer.prepare(directory, removing: previousDirectory)
            previousDirectory = nil
            let size = CGSize(width: 1080, height: 1920)
            let photo = directory.appendingPathComponent("ScreenMotion.jpg")
            let movie = directory.appendingPathComponent("ScreenMotion.mov")
            let identifier = UUID().uuidString
            let stillTime = format == .livePhoto ? 1.5 : 0
            guard let image = SceneFrameRenderer.image(theme: theme, configuration: configuration, size: size, time: stillTime)?.cgImage else { throw ExportFailure.renderer }
            try await writer.writePhoto(image, to: photo, identifier: format == .livePhoto ? identifier : nil)
            if format != .still {
                try await writer.beginVideo(at: movie, size: size, identifier: format == .livePhoto ? identifier : nil)
                let frameCount = 90
                for frame in 0..<frameCount {
                    try checkCancellation()
                    let time = Double(frame) / 30
                    guard let rendered = autoreleasepool(invoking: {
                        SceneFrameRenderer.image(theme: theme, configuration: configuration, size: size, time: time)?.cgImage
                    }) else { throw ExportFailure.renderer }
                    try await writer.append(rendered, frame: frame)
                    progress = Double(frame + 1) / Double(frameCount) * 0.9
                }
                try await writer.finishVideo()
            }
            try checkCancellation()
            // PhotoKit commits atomically. Once submitted, cancellation cannot claim the save was undone.
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                if format == .video {
                    request.addResource(with: .video, fileURL: movie, options: nil)
                } else {
                    request.addResource(with: .photo, fileURL: photo, options: nil)
                    if format == .livePhoto {
                        request.addResource(with: .pairedVideo, fileURL: movie, options: nil)
                    }
                }
            }
            committed = true
            previousDirectory = directory
            progress = 1
            return format == .video ? movie : photo
        } catch {
            await writer.abort()
            if error is CancellationError { throw ExportFailure.cancelled }
            throw error
        }
    }

    private func checkCancellation() throws {
        if cancelled || Task.isCancelled { throw ExportFailure.cancelled }
    }
}

/// Serializes file IO, pixel conversion and AVFoundation encoding away from the main actor.
actor ExportWriter {
    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var metadataInput: AVAssetWriterInput?

    func prepare(_ directory: URL, removing oldDirectory: URL?) throws {
        if let oldDirectory { remove(oldDirectory) }
        let values = try FileManager.default.temporaryDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let bytes = values.volumeAvailableCapacityForImportantUsage, bytes < 150_000_000 { throw ExportFailure.storage }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func remove(_ directory: URL) { try? FileManager.default.removeItem(at: directory) }

    func writePhoto(_ image: CGImage, to url: URL, identifier: String?) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { throw ExportFailure.storage }
        var metadata: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 0.96]
        if let identifier { metadata[kCGImagePropertyMakerAppleDictionary] = ["17": identifier] }
        CGImageDestinationAddImage(destination, image, metadata as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw ExportFailure.storage }
    }

    func beginVideo(at url: URL, size: CGSize, identifier: String?) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 8_000_000]
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ])
        guard writer.canAdd(input) else { throw ExportFailure.encoding }
        writer.add(input)
        var timedAdaptor: AVAssetWriterInputMetadataAdaptor?
        if let identifier {
            let identity = AVMutableMetadataItem()
            identity.keySpace = .quickTimeMetadata
            identity.key = "com.apple.quicktime.content.identifier" as NSString
            identity.value = identifier as NSString
            identity.dataType = kCMMetadataBaseDataType_UTF8 as String
            writer.metadata = [identity]
            var description: CMFormatDescription?
            let specification: [String: Any] = [
                kCMMetadataFormatDescriptionMetadataSpecificationKey_Identifier as String: "mdta/com.apple.quicktime.still-image-time",
                kCMMetadataFormatDescriptionMetadataSpecificationKey_DataType as String: "com.apple.metadata.datatype.int8"
            ]
            guard CMMetadataFormatDescriptionCreateWithMetadataSpecifications(allocator: kCFAllocatorDefault, metadataType: kCMMetadataFormatType_Boxed, metadataSpecifications: [specification] as CFArray, formatDescriptionOut: &description) == noErr,
                  let description else { throw ExportFailure.encoding }
            let metadataInput = AVAssetWriterInput(mediaType: .metadata, outputSettings: nil, sourceFormatHint: description)
            guard writer.canAdd(metadataInput) else { throw ExportFailure.encoding }
            writer.add(metadataInput)
            self.metadataInput = metadataInput
            timedAdaptor = AVAssetWriterInputMetadataAdaptor(assetWriterInput: metadataInput)
        }
        guard writer.startWriting() else { throw writer.error ?? ExportFailure.encoding }
        writer.startSession(atSourceTime: .zero)
        self.writer = writer
        self.input = input
        self.adaptor = adaptor
        if let timedAdaptor {
            let still = AVMutableMetadataItem()
            still.keySpace = .quickTimeMetadata
            still.key = "com.apple.quicktime.still-image-time" as NSString
            still.value = NSNumber(value: Int8(0))
            still.dataType = "com.apple.metadata.datatype.int8"
            let range = CMTimeRange(start: CMTime(value: 45, timescale: 30), duration: CMTime(value: 1, timescale: 30))
            guard timedAdaptor.append(AVTimedMetadataGroup(items: [still], timeRange: range)) else { throw ExportFailure.encoding }
            metadataInput?.markAsFinished()
        }
    }

    func append(_ image: CGImage, frame: Int) async throws {
        guard let writer, let input, let adaptor else { throw ExportFailure.encoding }
        var attempts = 0
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing, attempts < 500 else { throw writer.error ?? ExportFailure.encoding }
            try await Task.sleep(for: .milliseconds(10))
            attempts += 1
        }
        guard let pool = adaptor.pixelBufferPool else { throw ExportFailure.encoding }
        var possibleBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &possibleBuffer) == kCVReturnSuccess, let buffer = possibleBuffer else { throw ExportFailure.storage }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { throw ExportFailure.encoding }
        context.draw(image, in: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)))
        guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else { throw writer.error ?? ExportFailure.encoding }
    }

    func finishVideo() async throws {
        guard let writer, let input else { throw ExportFailure.encoding }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: 3, timescale: 1))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? ExportFailure.encoding }
    }

    func abort() { writer?.cancelWriting() }
}
