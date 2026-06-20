import XCTest
@testable import Explorer

@MainActor
final class PreviewBrowserEligibilityTests: XCTestCase {
    private func makeFileItem(
        id: String = "file-a",
        name: String = "file-a.txt",
        isDirectory: Bool = false,
        ext: String? = nil,
        size: Int64 = 100
    ) -> FileItem {
        let fileName = ext.map { "name.\($0)" } ?? name
        let path = "/tmp/\(fileName)"
        return FileItem(
            id: id,
            url: URL(fileURLWithPath: path),
            name: fileName,
            isDirectory: isDirectory,
            modificationDate: .distantPast,
            size: size,
            isHidden: false,
            fileType: ext ?? "txt",
            sizeDisplay: "100 B",
            dateDisplay: ""
        )
    }

    func testBuiltInRejectsDirectory() {
        XCTAssertFalse(PreviewBrowserEligibility.canPreviewBuiltIn(makeFileItem(isDirectory: true)))
        XCTAssertFalse(PreviewBrowserEligibility.canPreviewBuiltIn(FileItem.parentDirectoryEntry()))
    }

    func testBuiltInAcceptsImageAndPDF() {
        XCTAssertTrue(PreviewBrowserEligibility.canPreviewBuiltIn(makeFileItem(ext: "png")))
        XCTAssertTrue(PreviewBrowserEligibility.canPreviewBuiltIn(makeFileItem(ext: "pdf")))
    }

    func testBuiltInAcceptsArchiveByFileName() {
        let zip = makeFileItem(name: "archive.zip")
        XCTAssertTrue(PreviewBrowserEligibility.canPreviewBuiltIn(zip))
    }

    func testBuiltInRejectsUnknownExtension() {
        XCTAssertFalse(PreviewBrowserEligibility.canPreviewBuiltIn(makeFileItem(ext: "xyzunknown")))
    }

    func testFilterSameTypeKeepsMatchingExtension() {
        let pngA = makeFileItem(id: "a", ext: "png")
        let pngB = makeFileItem(id: "b", ext: "png")
        let pdf = makeFileItem(id: "c", ext: "pdf")
        let filtered = PreviewBrowserEligibility.filterSameType([pngA, pngB, pdf], as: pngA)
        XCTAssertEqual(filtered.map(\.id), ["a", "b"])
    }

    func testPrefetchEligibleAcceptsSmallImageAndPDF() {
        XCTAssertTrue(PreviewBrowserContentPrefetcher.isPrefetchEligible(makeFileItem(ext: "jpg", size: 1024)))
        XCTAssertTrue(PreviewBrowserContentPrefetcher.isPrefetchEligible(makeFileItem(ext: "pdf", size: 1024)))
    }

    func testPrefetchEligibleRejectsVideoOfficeAndOversized() {
        XCTAssertFalse(PreviewBrowserContentPrefetcher.isPrefetchEligible(makeFileItem(ext: "mp4", size: 1024)))
        XCTAssertFalse(PreviewBrowserContentPrefetcher.isPrefetchEligible(makeFileItem(ext: "docx", size: 1024)))
        let oversized = PreviewBrowserContentPrefetcher.isPrefetchEligible(
            makeFileItem(ext: "png", size: PreviewBrowserStripMetrics.contentPrefetchMaxFileSize + 1)
        )
        XCTAssertFalse(oversized)
    }
}
