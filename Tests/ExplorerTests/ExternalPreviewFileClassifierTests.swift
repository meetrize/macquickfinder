import XCTest
@testable import Explorer

@MainActor
final class ExternalPreviewFileClassifierTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetCustomPreviewRules()
    }

    override func tearDown() {
        resetCustomPreviewRules()
        super.tearDown()
    }

    private func resetCustomPreviewRules() {
        let store = CustomPreviewRuleStore.shared
        for rule in store.rules {
            store.deleteRule(id: rule.id)
        }
    }

    private func fileURL(path: String, isDirectory: Bool = false) -> URL {
        URL(fileURLWithPath: path, isDirectory: isDirectory)
    }

    func testRecognizesBuiltInPreviewExtensions() {
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/photo.png")))
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/report.PDF")))
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/readme.md")))
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/clip.mp4")))
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/deck.pptx")))
    }

    func testRecognizesQuickLookImageAndArchiveExtensions() {
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/icon.svg")))
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/archive.zip")))
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/backup.tar.gz")))
    }

    func testRejectsFoldersAndUnknownExtensions() {
        XCTAssertFalse(ExternalPreviewFileClassifier.isExternalPreviewCandidate(
            fileURL(path: "/tmp/folder", isDirectory: true)
        ))
        XCTAssertFalse(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/folder/")))
        XCTAssertFalse(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/unknown.xyzunknown")))
    }

    func testRecognizesCustomPreviewRuleExtension() {
        CustomPreviewRuleStore.shared.upsertRule(forExtension: "proto", mode: .text)
        XCTAssertTrue(ExternalPreviewFileClassifier.isExternalPreviewCandidate(fileURL(path: "/tmp/schema.proto")))
    }

    func testFiltersPreviewableURLsPreservingOrder() {
        let urls = [
            fileURL(path: "/tmp/a.png"),
            fileURL(path: "/tmp/b.txt"),
            fileURL(path: "/tmp/c.pdf"),
            fileURL(path: "/tmp/d.unknown"),
            fileURL(path: "/tmp/e.heic"),
        ]
        let previewable = ExternalPreviewFileClassifier.previewableURLs(from: urls)
        XCTAssertEqual(previewable.map(\.path), ["/tmp/a.png", "/tmp/b.txt", "/tmp/c.pdf", "/tmp/e.heic"])
    }

    func testAlignsWithPreviewBrowserEligibilityForBuiltInTypes() {
        let extensions = ["png", "pdf", "txt", "mp4", "docx", "zip", "svg", "xyzunknown"]
        for ext in extensions {
            let url = fileURL(path: "/tmp/sample.\(ext)")
            let fileName = "sample.\(ext)"
            let item = FileItem(
                id: url.path,
                url: url,
                name: fileName,
                isDirectory: false,
                modificationDate: .distantPast,
                creationDate: .distantPast,
                size: 100,
                isHidden: false,
                fileType: ext,
                sizeDisplay: "100 B",
                dateDisplay: "",
                creationDateDisplay: "",
                finderComment: "",
                tags: []
            )
            let urlCandidate = ExternalPreviewFileClassifier.isExternalPreviewCandidate(url)
            let eligibility = PreviewBrowserEligibility.canPreviewInDetachedWindow(item)
            XCTAssertEqual(
                urlCandidate,
                eligibility,
                "Mismatch for .\(ext): url=\(urlCandidate) eligibility=\(eligibility)"
            )
        }
    }
}
