import XCTest
@testable import Explorer

@MainActor
final class PreviewCapabilityTests: XCTestCase {
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

    private func makeFileItem(
        id: String = "file-a",
        name: String = "file-a.txt",
        isDirectory: Bool = false,
        ext: String? = nil,
        size: Int64 = 100,
        isHidden: Bool = false
    ) -> FileItem {
        let fileName = ext.map { "name.\($0)" } ?? name
        let path = "/tmp/\(fileName)"
        return FileItem(
            id: id,
            url: URL(fileURLWithPath: path),
            name: fileName,
            isDirectory: isDirectory,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: size,
            isHidden: isHidden,
            fileType: ext ?? "txt",
            sizeDisplay: "100 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testHasBuiltInRejectsDirectory() {
        XCTAssertFalse(PreviewCapability.hasBuiltInPreview(makeFileItem(isDirectory: true)))
        XCTAssertFalse(PreviewCapability.hasBuiltInPreview(FileItem.parentDirectoryEntry()))
    }

    func testHasBuiltInAcceptsImagePDFAndArchive() {
        XCTAssertTrue(PreviewCapability.hasBuiltInPreview(makeFileItem(ext: "png")))
        XCTAssertTrue(PreviewCapability.hasBuiltInPreview(makeFileItem(ext: "pdf")))
        XCTAssertTrue(PreviewCapability.hasBuiltInPreview(makeFileItem(name: "archive.zip")))
    }

    func testCanLoadPreviewMatchesBuiltInForKnownTypes() {
        XCTAssertTrue(PreviewCapability.canLoadPreview(for: makeFileItem(ext: "png")))
        XCTAssertFalse(PreviewCapability.canLoadPreview(for: makeFileItem(ext: "xyzunknown")))
    }

    func testCanLoadPreviewUsesCustomRuleForUnknownExtension() {
        let store = CustomPreviewRuleStore.shared
        store.upsertRule(forExtension: "proto", mode: .text)

        XCTAssertTrue(PreviewCapability.canLoadPreview(for: makeFileItem(ext: "proto")))
    }

    func testCanLoadPreviewRejectsDirectoryAndParentEntry() {
        XCTAssertFalse(PreviewCapability.canLoadPreview(for: makeFileItem(isDirectory: true)))
        XCTAssertFalse(PreviewCapability.canLoadPreview(for: FileItem.parentDirectoryEntry()))
    }

    func testIsBrowserCandidateRespectsHiddenFilesSetting() {
        let hiddenPNG = makeFileItem(ext: "png", isHidden: true)
        XCTAssertFalse(PreviewCapability.isBrowserCandidate(hiddenPNG, showHiddenFiles: false))
        XCTAssertTrue(PreviewCapability.isBrowserCandidate(hiddenPNG, showHiddenFiles: true))
    }

    func testIsBrowserCandidateRejectsDirectoryAndParentEntry() {
        XCTAssertFalse(PreviewCapability.isBrowserCandidate(
            makeFileItem(isDirectory: true),
            showHiddenFiles: true
        ))
        XCTAssertFalse(PreviewCapability.isBrowserCandidate(
            FileItem.parentDirectoryEntry(),
            showHiddenFiles: true
        ))
    }

    func testCanDetachRequiresPreviewContentAndNotAlreadyDetached() {
        let file = makeFileItem(ext: "png")
        let session = PreviewSession(hostWindowID: UUID(), file: file)
        XCTAssertTrue(PreviewCapability.canDetach(session: session, selectedItem: file))

        session.location = .detached(windowNumber: nil)
        XCTAssertFalse(PreviewCapability.canDetach(session: session, selectedItem: file))
    }

    func testCanDetachRejectsDirectoryWithoutInlineChild() {
        let dir = FileItem(
            id: "/tmp/folder",
            url: URL(fileURLWithPath: "/tmp/folder"),
            name: "folder",
            isDirectory: true,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "文件夹",
            sizeDisplay: "--",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let session = PreviewSession(hostWindowID: UUID(), file: dir)
        XCTAssertFalse(PreviewCapability.canDetach(session: session, selectedItem: dir))
    }

    func testCanDetachAllowsDirectoryWithInlineChild() {
        let dir = FileItem(
            id: "/tmp/folder",
            url: URL(fileURLWithPath: "/tmp/folder"),
            name: "folder",
            isDirectory: true,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "文件夹",
            sizeDisplay: "--",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let child = makeFileItem(id: "child", ext: "png")
        let session = PreviewSession(hostWindowID: UUID(), file: dir)
        session.folderInlineChild = child
        XCTAssertTrue(PreviewCapability.canDetach(session: session, selectedItem: dir))
    }

    func testMatchesSameExtensionTreatsEmptyExtensionSeparately() {
        let noExt = makeFileItem(name: "README")
        let txt = makeFileItem(ext: "txt")
        XCTAssertTrue(PreviewCapability.matchesSameExtension(noExt, as: makeFileItem(name: "LICENSE")))
        XCTAssertFalse(PreviewCapability.matchesSameExtension(txt, as: noExt))
    }

    func testFilterSameType() {
        let pngA = makeFileItem(id: "a", ext: "png")
        let pngB = makeFileItem(id: "b", ext: "png")
        let pdf = makeFileItem(id: "c", ext: "pdf")
        let filtered = PreviewCapability.filterSameType([pngA, pngB, pdf], as: pngA)
        XCTAssertEqual(filtered.map(\.id), ["a", "b"])
    }

    func testIsPrefetchEligible() {
        XCTAssertTrue(PreviewCapability.isPrefetchEligible(makeFileItem(ext: "jpg", size: 1024)))
        XCTAssertFalse(PreviewCapability.isPrefetchEligible(makeFileItem(ext: "mp4", size: 1024)))
        XCTAssertFalse(PreviewCapability.isPrefetchEligible(
            makeFileItem(ext: "png", size: PreviewBrowserStripMetrics.contentPrefetchMaxFileSize + 1)
        ))
    }

    func testIsPrefetchEligibleRejectsZeroSizeAndDirectory() {
        XCTAssertFalse(PreviewCapability.isPrefetchEligible(makeFileItem(ext: "png", size: 0)))
        XCTAssertFalse(PreviewCapability.isPrefetchEligible(makeFileItem(isDirectory: true)))
    }
}
