import XCTest
@testable import FileList

final class FileListDragDropSupportTests: XCTestCase {
    private func makeInteraction(
        currentDirectory: String = "/tmp/current",
        dropDestination: String? = "/tmp/current/subdir"
    ) -> FileListTableInteraction {
        FileListTableInteraction(
            dropDestinationPath: { _ in dropDestination },
            currentDirectoryDropPath: currentDirectory,
            canAcceptDrop: { _, _ in true },
            performDrop: { _, _, _ in }
        )
    }

    private func makeDirectoryRow(id: String, name: String) -> FileListRow {
        FileListRow(
            id: id,
            name: name,
            fileType: "Folder",
            sizeDisplay: "—",
            dateDisplay: "",
            size: 0,
            modificationDate: .distantPast,
            isDirectory: true,
            isHidden: false,
            isParentDirectoryEntry: false,
            iconPath: id
        )
    }

    func testEvaluateDropHighlightsTargetRow() {
        let rows = [makeDirectoryRow(id: "/tmp/current/subdir", name: "subdir")]
        let interaction = makeInteraction(dropDestination: "/tmp/current/subdir")
        let urls = [URL(fileURLWithPath: "/tmp/file.txt")]

        let evaluation = FileListDragDropSupport.evaluateDrop(
            displayRows: rows,
            rowIndex: 0,
            interaction: interaction,
            urls: urls,
            copy: false
        )

        XCTAssertEqual(evaluation?.highlight, .itemRow(0))
        XCTAssertEqual(evaluation?.destinationPath, "/tmp/current/subdir")
        XCTAssertEqual(evaluation?.operation, .move)
    }

    func testEvaluateDropHighlightsCurrentDirectoryWhenNoRow() {
        let interaction = makeInteraction()
        let urls = [URL(fileURLWithPath: "/tmp/file.txt")]

        let evaluation = FileListDragDropSupport.evaluateDrop(
            displayRows: [],
            rowIndex: nil,
            interaction: interaction,
            urls: urls,
            copy: true
        )

        XCTAssertEqual(evaluation?.highlight, .currentDirectory)
        XCTAssertEqual(evaluation?.destinationPath, "/tmp/current")
        XCTAssertEqual(evaluation?.operation, .copy)
    }

    func testResolvedURLsUsesActiveDragFallback() {
        let pasteboard = NSPasteboard(name: .drag)
        pasteboard.clearContents()

        let fallback = [URL(fileURLWithPath: "/tmp/active.txt")]
        let urls = FileListDragDropSupport.resolvedURLs(from: pasteboard, fallback: fallback)

        XCTAssertEqual(urls.map(\.path), ["/tmp/active.txt"])
    }

    func testSourceOperationMaskOutsideApplicationIncludesCopyAndGeneric() {
        let mask = FileListExternalFileDrag.sourceOperationMask(for: .outsideApplication)
        XCTAssertTrue(mask.contains(.copy))
        XCTAssertTrue(mask.contains(.generic))
    }

    func testSourceOperationMaskWithinApplicationIsMove() {
        XCTAssertEqual(
            FileListExternalFileDrag.sourceOperationMask(for: .withinApplication),
            .move
        )
    }

    func testPreparePasteboardIncludesLegacyFilenamesType() {
        let url = URL(fileURLWithPath: "/tmp/sample.apk")
        let pasteboard = FileListExternalFileDrag.preparePasteboard(urls: [url])
        let legacy = FileListExternalFileDrag.legacyFilenamesType

        XCTAssertNotNil(pasteboard.data(forType: legacy))
        XCTAssertEqual(pasteboard.propertyList(forType: legacy) as? [String], [url.path])
    }

    func testPerformAcceptedDropUsesExplicitCopyFlag() {
        var performed: (String, [URL], Bool)?
        let interaction = FileListTableInteraction(
            performDrop: { path, urls, copy in
                performed = (path, urls, copy)
            }
        )
        let urls = [URL(fileURLWithPath: "/tmp/a.txt")]

        FileListDragDropSupport.performAcceptedDrop(
            destinationPath: "/tmp/dest",
            urls: urls,
            draggingInfo: nil,
            interaction: interaction,
            copy: true
        )

        XCTAssertEqual(performed?.0, "/tmp/dest")
        XCTAssertEqual(performed?.1.map(\.path), ["/tmp/a.txt"])
        XCTAssertEqual(performed?.2, true)
    }
}
