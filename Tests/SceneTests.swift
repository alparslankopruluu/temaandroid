import UIKit
import XCTest
@testable import ScreenMotion

final class SceneTests: XCTestCase {
    private let midnight = Theme(id: "midnight", titleKey: "theme.midnight", collection: .vehicles,
                                 artwork: "midnight", isFree: true, symbol: "car.side")

    @MainActor
    func testMissingArtworkCannotProduceSuccessfulBlackExport() async {
        let missing = Theme(id: "missing", titleKey: "missing", collection: .vehicles,
                            artwork: "scene-test-resource-that-does-not-exist", isFree: true, symbol: "car.side")
        let prepared = await SceneFrameRenderer.prepare(theme: missing)
        XCTAssertFalse(prepared)
        XCTAssertNil(SceneFrameRenderer.image(theme: missing, configuration: .init(),
                                               size: CGSize(width: 390, height: 780), time: 0))
    }

    @MainActor
    func testBundledMidnightExportsExactPixelDimensionsAndVisibleArtwork() async throws {
        // Bundle.main is the application host, not the unit-test bundle.
        XCTAssertNotNil(UIImage(named: "midnight", in: Bundle.main, compatibleWith: nil))
        let prepared = await SceneFrameRenderer.prepare(theme: midnight)
        XCTAssertTrue(prepared)
        let image = try XCTUnwrap(SceneFrameRenderer.image(theme: midnight, configuration: .init(),
                                                           size: CGSize(width: 390, height: 780), time: 0)?.cgImage)
        XCTAssertEqual(image.width, 390, "Offscreen SpriteKit must not multiply output by Retina scale")
        XCTAssertEqual(image.height, 780)
        var pixels = [UInt8](repeating: 0, count: 16 * 32 * 4)
        let litPixels: Int = try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 16, height: 32,
                                                  bitsPerComponent: 8, bytesPerRow: 16 * 4,
                                                  space: CGColorSpaceCreateDeviceRGB(),
                                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: 16, height: 32))
            return stride(from: 0, to: buffer.count, by: 4).filter {
                Int(buffer[$0]) + Int(buffer[$0 + 1]) + Int(buffer[$0 + 2]) > 30
            }.count
        }
        XCTAssertGreaterThan(litPixels, 50, "A technically valid but black snapshot is not a successful export")
    }

    @MainActor
    func testExportIsRepeatableAtSameTimeAndChangesWithMotion() async throws {
        let prepared = await SceneFrameRenderer.prepare(theme: midnight)
        XCTAssertTrue(prepared)
        let configuration = SceneConfiguration(intensity: 1, particles: 0, depth: 1, zoom: 1, style: 0)
        let size = CGSize(width: 390, height: 780)
        let first = try XCTUnwrap(SceneFrameRenderer.image(theme: midnight, configuration: configuration, size: size, time: 0)?.pngData())
        let repeated = try XCTUnwrap(SceneFrameRenderer.image(theme: midnight, configuration: configuration, size: size, time: 0)?.pngData())
        let moved = try XCTUnwrap(SceneFrameRenderer.image(theme: midnight, configuration: configuration, size: size, time: 2)?.pngData())
        XCTAssertEqual(first, repeated)
        XCTAssertNotEqual(first, moved)
        XCTAssertNil(SceneFrameRenderer.image(theme: midnight, configuration: configuration, size: .zero, time: 0))
    }
}
