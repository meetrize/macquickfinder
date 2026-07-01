import CoreGraphics
import XCTest
@testable import Explorer

final class PreviewDetachedWindowFrameStoreTests: XCTestCase {
    override func tearDown() {
        for kind in [PreviewDetachedWindowContentKind.pdf, .text] {
            UserDefaults.standard.removeObject(forKey: "preview.detachedFrame.\(kind.rawValue)")
        }
        super.tearDown()
    }

    func testSaveAndLoadContentSize() {
        let kind = PreviewDetachedWindowContentKind.pdf
        let size = CGSize(width: 820, height: 1040)
        PreviewDetachedWindowFrameStore.saveContentSize(size, for: kind)
        XCTAssertEqual(PreviewDetachedWindowFrameStore.savedContentSize(for: kind), size)
    }

    func testMissingFrameReturnsNil() {
        XCTAssertNil(PreviewDetachedWindowFrameStore.savedContentSize(for: .text))
    }
}

final class PreviewDetachedWindowContentKindTests: XCTestCase {
    func testPDFRouteMapsToPDFKind() {
        XCTAssertEqual(PreviewDetachedWindowContentKind.from(route: .builtInPDF), .pdf)
    }

    func testArchiveRouteMapsToArchiveKind() {
        XCTAssertEqual(PreviewDetachedWindowContentKind.from(route: .archive), .archive)
    }
}
