import AppKit
import XCTest
@testable import Explorer

@MainActor
final class ImagePreviewCropTests: XCTestCase {
    func testClampNormalizedCropRectKeepsMinimumSide() {
        let clamped = ImagePreviewTransformApplier.clampedNormalizedCropRect(
            CGRect(x: 0.9, y: 0.9, width: 0.01, height: 0.01)
        )
        XCTAssertGreaterThanOrEqual(clamped.width, 0.05)
        XCTAssertGreaterThanOrEqual(clamped.height, 0.05)
        XCTAssertLessThanOrEqual(clamped.maxX, 1.0 + 0.0001)
        XCTAssertLessThanOrEqual(clamped.maxY, 1.0 + 0.0001)
    }

    func testCropProducesExpectedPixelSize() throws {
        let image = makeSolidImage(width: 100, height: 80, color: .red)
        let cropped = try XCTUnwrap(
            ImagePreviewTransformApplier.crop(
                image,
                normalizedRect: CGRect(x: 0.1, y: 0.1, width: 0.5, height: 0.5)
            )
        )
        let size = ImagePreviewTransformApplier.pixelSize(of: cropped)
        XCTAssertEqual(Int(size.width.rounded()), 50)
        XCTAssertEqual(Int(size.height.rounded()), 40)
    }

    func testHasEditsIncludesCrop() {
        let state = PreviewSessionImageState()
        XCTAssertFalse(state.hasEdits)
        state.cropRectNormalized = CGRect(x: 0.2, y: 0.2, width: 0.5, height: 0.5)
        XCTAssertTrue(state.hasEdits)
    }

    func testApplyCropDraftClearsResizeAndStoresRect() {
        let state = PreviewSessionImageState()
        state.resizeTargetSize = CGSize(width: 10, height: 10)
        state.beginCropping()
        XCTAssertTrue(state.isCropping)
        state.cropDraftNormalized = CGRect(x: 0.2, y: 0.25, width: 0.4, height: 0.3)
        state.applyCropDraft()
        XCTAssertFalse(state.isCropping)
        XCTAssertNil(state.resizeTargetSize)
        XCTAssertEqual(state.cropRectNormalized?.origin.x ?? -1, 0.2, accuracy: 0.0001)
        XCTAssertEqual(state.cropRectNormalized?.width ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertTrue(state.hasEdits)
    }

    func testUndoRestoresPreviousCrop() {
        let state = PreviewSessionImageState()
        state.cropRectNormalized = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
        state.beginCropping()
        state.cropDraftNormalized = CGRect(x: 0.2, y: 0.2, width: 0.3, height: 0.3)
        state.applyCropDraft()
        state.undoLastEdit()
        XCTAssertEqual(state.cropRectNormalized?.origin.x ?? -1, 0.1, accuracy: 0.0001)
        XCTAssertEqual(state.cropRectNormalized?.width ?? -1, 0.8, accuracy: 0.0001)
    }

    private func makeSolidImage(width: Int, height: Int, color: NSColor) -> NSImage {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        color.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(rep)
        return image
    }
}
