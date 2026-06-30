import XCTest
@testable import Explorer

final class ExternalImageFileClassifierTests: XCTestCase {
    func testRecognizesBuiltInImageExtensions() {
        let png = URL(fileURLWithPath: "/tmp/photo.png")
        let jpg = URL(fileURLWithPath: "/tmp/photo.JPG")
        XCTAssertTrue(ExternalImageFileClassifier.isExternalImagePreviewCandidate(png))
        XCTAssertTrue(ExternalImageFileClassifier.isExternalImagePreviewCandidate(jpg))
    }

    func testRecognizesQuickLookImageExtensions() {
        let svg = URL(fileURLWithPath: "/tmp/icon.svg")
        XCTAssertTrue(ExternalImageFileClassifier.isExternalImagePreviewCandidate(svg))
    }

    func testRejectsNonImages() {
        let txt = URL(fileURLWithPath: "/tmp/readme.txt")
        let folder = URL(fileURLWithPath: "/tmp/folder", isDirectory: true)
        XCTAssertFalse(ExternalImageFileClassifier.isExternalImagePreviewCandidate(txt))
        XCTAssertFalse(ExternalImageFileClassifier.isExternalImagePreviewCandidate(folder))
    }

    func testFiltersImageURLs() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.txt"),
            URL(fileURLWithPath: "/tmp/c.heic")
        ]
        let images = ExternalImageFileClassifier.imageURLs(from: urls)
        XCTAssertEqual(images.count, 2)
    }
}

final class DetachedPreviewWindowSizerTests: XCTestCase {
    func testSmallImageUpscaledToAvailableSpace() {
        let size = DetachedPreviewWindowSizer.contentSize(for: .init(
            imagePixelSize: CGSize(width: 800, height: 600),
            browserStripExpanded: false,
            canBrowse: false,
            screen: nil
        ))
        XCTAssertGreaterThan(size.width, 400)
        XCTAssertGreaterThan(size.height, 300)
    }

    func testLargeImageFitsScreen() {
        let size = DetachedPreviewWindowSizer.contentSize(for: .init(
            imagePixelSize: CGSize(width: 8000, height: 6000),
            browserStripExpanded: true,
            canBrowse: true,
            screen: nil
        ))
        XCTAssertLessThanOrEqual(size.width, 1280)
        XCTAssertLessThanOrEqual(size.height, 800)
    }

    func testPreviewWindowValueFitFlagRoundTrip() throws {
        let value = PreviewWindowValue(
            sessionID: PreviewSessionID(rawValue: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!),
            fitImageToScreen: true
        )
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(PreviewWindowValue.self, from: data)
        XCTAssertEqual(decoded, value)
        XCTAssertTrue(decoded.fitImageToScreen)
    }
}
