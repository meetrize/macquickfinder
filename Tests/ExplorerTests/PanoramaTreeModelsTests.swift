import FileList
import XCTest

@testable import Explorer

final class PanoramaTreeModelsTests: XCTestCase {
    func testPanoramaDirectoryIDUsesPath() {
        let id = PanoramaDirectoryID(path: "/tmp/Photos")
        XCTAssertEqual(id.path, "/tmp/Photos")
    }

    func testPanoramaListingStateItemCount() {
        let item = makeFileItem(id: "/tmp/a.txt", name: "a.txt", isDirectory: false)
        XCTAssertNil(PanoramaListingState.unloaded.itemCount)
        XCTAssertNil(PanoramaListingState.loading.itemCount)
        XCTAssertEqual(PanoramaListingState.loaded([item]).itemCount, 1)
        XCTAssertNil(PanoramaListingState.failed("err").itemCount)
    }

    func testPanoramaDirectoryNodeIdentity() {
        let folder = makeFileItem(id: "/tmp/Photos", name: "Photos", isDirectory: true)
        let node = PanoramaDirectoryNode(item: folder, depth: 1, childCountHint: 3)

        XCTAssertEqual(node.id, PanoramaDirectoryID(path: "/tmp/Photos"))
        XCTAssertEqual(node.path, "/tmp/Photos")
        XCTAssertEqual(node.depth, 1)
        XCTAssertEqual(node.childCountHint, 3)
        XCTAssertEqual(node.listing, .unloaded)
    }

    func testPanoramaDisplayBlockIDs() {
        let row = FileListRow(item: makeFileItem(id: "/tmp/Photos", name: "Photos", isDirectory: true))
        XCTAssertEqual(
            PanoramaDisplayBlock.expandedFolderSection(row: row, blocks: []).id,
            "expanded:/tmp/Photos"
        )
        XCTAssertEqual(
            PanoramaDisplayBlock.itemGrid(
                depth: 1,
                directoryID: "/tmp/Photos",
                gridInstanceID: "segment-a",
                items: []
            ).id,
            "grid:/tmp/Photos:segment-a"
        )
        XCTAssertEqual(
            PanoramaDisplayBlock.childBlocks(parentDirectoryID: "/tmp", blocks: []).id,
            "children:/tmp"
        )
    }

    func testPanoramaGridItemIDs() {
        let fileRow = FileListRow(item: makeFileItem(id: "/tmp/a.txt", name: "a.txt", isDirectory: false))
        let folderRow = FileListRow(item: makeFileItem(id: "/tmp/Dir", name: "Dir", isDirectory: true))

        XCTAssertEqual(PanoramaGridItem.file(fileRow).id, "/tmp/a.txt")
        XCTAssertEqual(PanoramaGridItem.folderCollapsed(folderRow).id, "/tmp/Dir")
        XCTAssertEqual(
            PanoramaGridItem.overflow(directoryID: "/tmp/Dir", remaining: 5).id,
            "overflow:/tmp/Dir:5"
        )
    }

    func testPanoramaMetricsLeadingPaddingAndColumns() {
        XCTAssertEqual(PanoramaMetrics.leadingPadding(forDepth: 0), 0)
        XCTAssertEqual(PanoramaMetrics.leadingPadding(forDepth: 2), 40)
        XCTAssertEqual(
            PanoramaMetrics.contentLeadingInset(forDepth: 0),
            PanoramaMetrics.gridContentInset
        )
        XCTAssertEqual(
            PanoramaMetrics.contentLeadingInset(forDepth: 2),
            40 + PanoramaMetrics.gridContentInset
        )

        let columns = PanoramaMetrics.gridColumnCount(availableWidth: 400, cellSize: 128)
        XCTAssertGreaterThanOrEqual(columns, 1)
    }

    func testCappedGridItemsOrdersFoldersBeforeFiles() {
        let folder = FileListRow(item: makeFileItem(id: "/tmp/Dir", name: "Dir", isDirectory: true))
        let file = FileListRow(item: makeFileItem(id: "/tmp/a.txt", name: "a.txt", isDirectory: false))

        let items = PanoramaMetrics.cappedGridItems(
            files: [file],
            collapsedFolders: [folder],
            directoryID: "/tmp"
        )

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0], .folderCollapsed(folder))
        XCTAssertEqual(items[1], .file(file))
    }

    func testCappedGridItemsAppendsOverflow() {
        var files: [FileListRow] = []
        files.reserveCapacity(50)
        for index in 0..<50 {
            files.append(
                FileListRow(
                    item: makeFileItem(
                        id: "/tmp/file-\(index).txt",
                        name: "file-\(index).txt",
                        isDirectory: false
                    )
                )
            )
        }

        let items = PanoramaMetrics.cappedGridItems(
            files: files,
            collapsedFolders: [],
            directoryID: "/tmp",
            cap: 48
        )

        XCTAssertEqual(items.count, 48)
        guard case let .overflow(directoryID, remaining) = items.last else {
            return XCTFail("Expected overflow tail")
        }
        XCTAssertEqual(directoryID, "/tmp")
        XCTAssertEqual(remaining, 3)
    }

    func testPanoramaDisplayRootEquality() {
        let left = PanoramaDisplayRoot(rootDirectoryPath: "/tmp", blocks: [])
        let right = PanoramaDisplayRoot(rootDirectoryPath: "/tmp", blocks: [])
        XCTAssertEqual(left, right)
    }

    // MARK: - Fixtures

    private func makeFileItem(id: String, name: String, isDirectory: Bool) -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: id.hasPrefix("/") ? id : "/tmp/\(id)"),
            name: name,
            isDirectory: isDirectory,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: isDirectory ? "Folder" : "txt",
            sizeDisplay: "0 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }
}
