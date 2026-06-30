import AppKit
import XCTest
@testable import Explorer

final class ImagePreviewLoaderTests: XCTestCase {
    func testRecommendedMaxPixelSizeCapsLargeSources() {
        let source = CGSize(width: 6000, height: 4000)
        let recommended = ImagePreviewLoader.recommendedMaxPixelSize(
            sourcePixelSize: source,
            displayPixelBudget: 4096
        )
        XCTAssertEqual(recommended, 4096)
    }

    func testRecommendedMaxPixelSizeReturnsNilForSmallSources() {
        let source = CGSize(width: 800, height: 600)
        let recommended = ImagePreviewLoader.recommendedMaxPixelSize(
            sourcePixelSize: source,
            displayPixelBudget: 4096
        )
        XCTAssertNil(recommended)
    }

    func testDecodeDownsamplesLargePNG() throws {
        let url = try makeTemporaryPNG(width: 128, height: 96)
        defer { try? FileManager.default.removeItem(at: url) }

        let downsampled = ImagePreviewLoader.decode(data: try Data(contentsOf: url), maxPixelSize: 32)
        XCTAssertNotNil(downsampled)

        let pixelSize = ImagePreviewTransformApplier.pixelSize(of: downsampled!)
        let maxDimension = max(pixelSize.width, pixelSize.height)
        XCTAssertLessThanOrEqual(maxDimension, 32.5)
    }

    func testDecodeWithoutLimitPreservesDimensions() throws {
        let url = try makeTemporaryPNG(width: 64, height: 48)
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = ImagePreviewLoader.decode(data: try Data(contentsOf: url), maxPixelSize: nil)
        XCTAssertNotNil(decoded)

        let pixelSize = ImagePreviewTransformApplier.pixelSize(of: decoded!)
        XCTAssertEqual(pixelSize.width, 64, accuracy: 0.5)
        XCTAssertEqual(pixelSize.height, 48, accuracy: 0.5)
    }

    private func makeTemporaryPNG(width: Int, height: Int) throws -> URL {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            throw NSError(domain: "ImagePreviewLoaderTests", code: 1)
        }

        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "ImagePreviewLoaderTests", code: 2)
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("image-preview-loader-\(UUID().uuidString).png")
        try pngData.write(to: url)
        return url
    }
}

@MainActor
final class PreviewSessionImageResolutionTests: XCTestCase {
    func testIsDisplayResolutionLimitedWhenDecodedBelowSource() {
        let session = PreviewSession(hostWindowID: UUID(), file: makePNGFileItem())
        session.image.sourcePixelSize = CGSize(width: 6000, height: 4000)
        session.image.decodedMaxPixelSize = 4096

        XCTAssertTrue(session.image.isDisplayResolutionLimited)
    }

    func testIsNotDisplayResolutionLimitedAtFullResolution() {
        let session = PreviewSession(hostWindowID: UUID(), file: makePNGFileItem())
        session.image.sourcePixelSize = CGSize(width: 6000, height: 4000)
        session.image.decodedMaxPixelSize = 0

        XCTAssertFalse(session.image.isDisplayResolutionLimited)
    }

    private func makePNGFileItem() -> FileItem {
        FileItem(
            id: "/tmp/test.png",
            url: URL(fileURLWithPath: "/tmp/test.png"),
            name: "test.png",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 1024,
            isHidden: false,
            fileType: "png",
            sizeDisplay: "1 KB",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }
}
