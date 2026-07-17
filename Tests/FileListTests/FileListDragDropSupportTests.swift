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

    func testDraggingFrameAnchorsIconCenterOnMouse() {
        let ghostSize = NSSize(width: 120, height: 40)
        let mouse = NSPoint(x: 200, y: 150)
        let frame = FileListDragSupport.draggingFrame(
            at: mouse,
            ghostSize: ghostSize,
            index: 0,
            showLabel: true
        )
        let iconCenterX = frame.origin.x + FileListDragSupport.iconCenterX(showLabel: true)

        XCTAssertEqual(iconCenterX, mouse.x, accuracy: 0.01)
        XCTAssertEqual(frame.midY, mouse.y, accuracy: 0.01)

        let dragImageLocation = NSPoint(x: frame.origin.x, y: frame.origin.y + frame.height)
        let offset = NSSize(
            width: mouse.x - dragImageLocation.x,
            height: mouse.y - dragImageLocation.y
        )
        XCTAssertEqual(offset.width, FileListDragSupport.iconCenterX(showLabel: true), accuracy: 0.01)
        XCTAssertEqual(offset.height, -ghostSize.height / 2, accuracy: 0.01)
        XCTAssertEqual(dragImageLocation.x + offset.width, mouse.x, accuracy: 0.01)
        XCTAssertEqual(dragImageLocation.y + offset.height, mouse.y, accuracy: 0.01)
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

    func testPreparePasteboardWritesSingleFileReference() {
        let url = URL(fileURLWithPath: "/tmp/sample.apk")
        let pasteboard = FileListExternalFileDrag.preparePasteboard(urls: [url])

        let modernCount = (pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL])?.count ?? 0
        let legacyCount = (pasteboard.propertyList(
            forType: FileListExternalFileDrag.legacyFilenamesType
        ) as? [String])?.count ?? 0

        XCTAssertEqual(modernCount, 1)
        XCTAssertEqual(legacyCount, 0)
        XCTAssertEqual(modernCount + legacyCount, 1)
    }

    func testPreparePasteboardWritesAllMultiFileURLs() {
        let urls = [
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt"),
        ]
        let pasteboard = FileListExternalFileDrag.preparePasteboard(urls: urls)

        let modernPaths = ((pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]) ?? []).map(\.path).sorted()
        let legacyCount = (pasteboard.propertyList(
            forType: FileListExternalFileDrag.legacyFilenamesType
        ) as? [String])?.count ?? 0

        XCTAssertEqual(modernPaths, ["/tmp/a.txt", "/tmp/b.txt"])
        XCTAssertEqual(legacyCount, 0)
    }

    func testMakeDraggingItemsCreatesOneItemPerSelectedFile() {
        let rows = [
            makeDirectoryRow(id: "/tmp/a", name: "a"),
            makeDirectoryRow(id: "/tmp/b", name: "b"),
            makeDirectoryRow(id: "/tmp/c", name: "c"),
        ]
        let items = FileListInteractionCoordinator.makeDraggingItems(
            for: rows[1],
            in: rows,
            selection: ["/tmp/a", "/tmp/b"],
            mousePoint: NSPoint(x: 40, y: 40)
        )
        XCTAssertEqual(items.count, 2)
    }

    func testDraggedRowsReturnsAllSelectedWhenClickedRowIsSelected() {
        let rows = [
            makeDirectoryRow(id: "/tmp/a", name: "a"),
            makeDirectoryRow(id: "/tmp/b", name: "b"),
            makeDirectoryRow(id: "/tmp/c", name: "c"),
        ]
        let dragged = FileListDragSupport.draggedRows(
            for: rows[1],
            in: rows,
            selection: ["/tmp/a", "/tmp/b"]
        )
        XCTAssertEqual(dragged.map(\.id), ["/tmp/a", "/tmp/b"])
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
