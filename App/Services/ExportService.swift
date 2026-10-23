import AVFoundation
import CoreImage
import ImageIO
import Observation
import Photos
import UIKit
import UniformTypeIdentifiers

/// Every save becomes something iOS can use as a moving wallpaper: a Live Photo, or the still a Spatial Scene
/// needs on iOS 26. Plain video was removed because iOS cannot set a video as wallpaper.
/// Files remain available for sharing until the next export or the OS purges temporary storage.
enum ExportFormat: String, Sendable {
    case still, livePhoto
}

enum ExportFailure: LocalizedError {
    case busy, permission, renderer, storage, encoding, cancelled

    /// A short analytics label; unknown errors keep their domain so new failure modes stay visible.
    static func reason(_ error: Error) -> String {
        if let failure = error as? ExportFailure { return "\(failure)" }
        let nsError = error as NSError
        return "\(nsError.domain):\(nsError.code)"
    }
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
        if let loop = theme.loopResource {
            let source = VideoFrameSource(url: loop, start: 0, zoom: configuration.zoom, style: configuration.style)
            return try await write(format: format) { time in try await source.frame(at: time) }
        }
        guard await SceneFrameRenderer.prepare(theme: theme) else { throw ExportFailure.renderer }
        return try await write(format: format) { time in
            autoreleasepool {
                SceneFrameRenderer.image(theme: theme, configuration: configuration, size: Self.size, time: time)?.cgImage
            }
        }
    }

    /// Turns three seconds of the user's own clip, starting at `start`, into a Live Photo.
    func exportClip(_ url: URL, start: Double, fit: Bool = false) async throws -> URL {
        let source = VideoFrameSource(url: url, start: start, zoom: 1, style: 0, fit: fit)
        return try await write(format: .livePhoto) { time in try await source.frame(at: time) }
    }

    static let size = CGSize(width: 1080, height: 1920)
    static let frameCount = 90

    private func write(format: ExportFormat, frame: (Double) async throws -> CGImage?) async throws -> URL {
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
            let photo = directory.appendingPathComponent("ScreenMotion.jpg")
            let movie = directory.appendingPathComponent("ScreenMotion.mov")
            let identifier = UUID().uuidString
            let stillTime = format == .livePhoto ? 1.5 : 0
            guard let image = try await frame(stillTime) else { throw ExportFailure.renderer }
            try await writer.writePhoto(image, to: photo, identifier: format == .livePhoto ? identifier : nil)
            if format == .livePhoto {
                try await writer.beginVideo(at: movie, size: Self.size, identifier: identifier)
                for index in 0..<Self.frameCount {
                    try checkCancellation()
                    guard let rendered = try await frame(Double(index) / 30) else { throw ExportFailure.renderer }
                    try await writer.append(rendered, frame: index)
                    progress = Double(index + 1) / Double(Self.frameCount) * 0.9
                }
                try await writer.finishVideo()
            }
            try checkCancellation()
            // PhotoKit commits atomically. Once submitted, cancellation cannot claim the save was undone.
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: photo, options: nil)
                if format == .livePhoto {
                    request.addResource(with: .pairedVideo, fileURL: movie, options: nil)
                }
            }
            committed = true
            previousDirectory = directory
            progress = 1
            return photo
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

/// Reads exact frames from a movie and fills the 9:16 export canvas, so loops and user clips share the Live Photo writer.
actor VideoFrameSource {
    private let url: URL
    private let start: Double
    private let zoom: Double
    private let style: Int
    /// Fit keeps the whole frame over a blurred fill of itself, so landscape clips are not cropped.
    private let fit: Bool
    private var generator: AVAssetImageGenerator?
    private var duration: Double = 0
    private let context = CIContext(options: [.cacheIntermediates: false])

    init(url: URL, start: Double, zoom: Double, style: Int, fit: Bool = false) {
        self.url = url
        self.start = max(0, start)
        self.zoom = max(1, zoom)
        self.style = style
        self.fit = fit
    }

    func frame(at time: Double) async throws -> CGImage? {
        let generator = try await prepared()
        // Loops are seamless, so wrapping keeps a short source valid for the full three seconds.
        let offset = duration > 0 ? (start + time).truncatingRemainder(dividingBy: duration) : start + time
        let (image, _) = try await generator.image(at: CMTime(seconds: offset, preferredTimescale: 600))
        return fill(image)
    }

    private func prepared() async throws -> AVAssetImageGenerator {
        if let generator { return generator }
        let asset = AVURLAsset(url: url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard !tracks.isEmpty else { throw ExportFailure.renderer }
        duration = try await asset.load(.duration).seconds
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: 2160, height: 2160)
        self.generator = generator
        return generator
    }

    private func fill(_ image: CGImage) -> CGImage? {
        let target = ExportService.size
        var input = CIImage(cgImage: image)
        if style != 0 {
            let filter = CIFilter(name: "CITemperatureAndTint")
            filter?.setValue(input, forKey: kCIInputImageKey)
            filter?.setValue(CIVector(x: 6500, y: 0), forKey: "inputNeutral")
            filter?.setValue(CIVector(x: style == 1 ? 8200 : 4800, y: 0), forKey: "inputTargetNeutral")
            input = filter?.outputImage ?? input
        }
        let canvas = CGRect(origin: .zero, size: target)
        let filled = Self.centered(input, scale: max(target.width / input.extent.width, target.height / input.extent.height) * zoom, in: canvas)
        guard fit else { return context.createCGImage(filled, from: canvas) }
        let backdrop = filled.clampedToExtent().applyingGaussianBlur(sigma: 40).cropped(to: canvas)
            .applyingFilter("CIColorControls", parameters: [kCIInputBrightnessKey: -0.12])
        let whole = Self.centered(input, scale: min(target.width / input.extent.width, target.height / input.extent.height), in: canvas)
        return context.createCGImage(whole.composited(over: backdrop), from: canvas)
    }
}

extension VideoFrameSource {
    /// Scales `image` and moves its centre onto the centre of `canvas`.
    static func centered(_ image: CIImage, scale: CGFloat, in canvas: CGRect) -> CIImage {
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        return scaled.transformed(by: CGAffineTransform(translationX: canvas.midX - scaled.extent.midX, y: canvas.midY - scaled.extent.midY))
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
            writer.metadata = [identity] + Self.livePhotoWallpaperMetadata
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

    /// Keys an iPhone camera writes on every Live Photo movie. Lock Screen Live Photo wallpapers (iOS 17+)
    /// may show "Motion not available" for movies without them; Photos ignores keys it does not use.
    private static var livePhotoWallpaperMetadata: [AVMetadataItem] {
        func item(_ key: String, _ value: NSNumber, _ type: CFString) -> AVMetadataItem {
            let item = AVMutableMetadataItem()
            item.keySpace = .quickTimeMetadata
            item.key = key as NSString
            item.value = value
            item.dataType = type as String
            return item
        }
        return [
            item("com.apple.quicktime.live-photo.auto", NSNumber(value: UInt8(1)), kCMMetadataBaseDataType_UInt8),
            item("com.apple.quicktime.live-photo.vitality-score", NSNumber(value: Float(1)), kCMMetadataBaseDataType_Float32),
            item("com.apple.quicktime.live-photo.vitality-scoring-version", NSNumber(value: Int64(4)), kCMMetadataBaseDataType_SInt64),
        ]
    }
}
