import AppKit
import FileList
import XCTest

@testable import Explorer

@MainActor
final class PanoramaThumbnailSchedulerTests: XCTestCase {
    func testUpdatePrunesImagesOutsideVisibleWindow() {
        let scheduler = PanoramaThumbnailScheduler()
        let rows = makeRows(count: 10)

        scheduler.update(
            PanoramaThumbnailLoadRequest(
                orderedRowIDs: rows.map(\.id),
                rowsByID: Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) }),
                visibleRowIDs: Set(rows.map(\.id)),
                cellSize: 128,
                screenScale: 2
            )
        )

        let firstTrackedCount = scheduler.trackedRowCountForTesting
        XCTAssertGreaterThan(firstTrackedCount, 0)

        scheduler.update(
            PanoramaThumbnailLoadRequest(
                orderedRowIDs: rows.map(\.id),
                rowsByID: Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) }),
                visibleRowIDs: [rows[5].id],
                cellSize: 128,
                screenScale: 2
            )
        )

        let allowedIDs = Set(["row-3", "row-4", "row-5", "row-6", "row-7"])
        for key in scheduler.imageByRowID.keys {
            XCTAssertTrue(allowedIDs.contains(key), "Unexpected cached row: \(key)")
        }
    }

    func testShutdownClearsImages() {
        let scheduler = PanoramaThumbnailScheduler()
        let row = makeRows(count: 1)[0]

        scheduler.update(
            PanoramaThumbnailLoadRequest(
                orderedRowIDs: [row.id],
                rowsByID: [row.id: row],
                visibleRowIDs: [row.id],
                cellSize: 128,
                screenScale: 2
            )
        )
        XCTAssertGreaterThan(scheduler.trackedRowCountForTesting, 0)

        scheduler.shutdown()
        XCTAssertEqual(scheduler.trackedRowCountForTesting, 0)
    }

    private func makeRows(count: Int) -> [FileListRow] {
        (0..<count).map { index in
            FileListRow(
                id: "row-\(index)",
                name: "file-\(index).txt",
                fileType: "txt",
                sizeDisplay: "1k",
                dateDisplay: "",
                size: 1024,
                modificationDate: .distantPast,
                isDirectory: false,
                isHidden: false,
                isParentDirectoryEntry: false,
                iconPath: "/tmp/file-\(index).txt"
            )
        }
    }
}

final class PanoramaVisibleCellTrackerTests: XCTestCase {
    @MainActor
    func testVisibleCellsAndDirectoryPathsDerivedFromViewport() {
        let tracker = PanoramaVisibleCellTracker()

        tracker.applyImmediatelyForTesting(
            cellReports: [
                PanoramaCellVisibility(rowID: "a", directoryID: "/root", frame: CGRect(x: 10, y: 10, width: 80, height: 80)),
                PanoramaCellVisibility(rowID: "b", directoryID: "/root/Photos", frame: CGRect(x: 10, y: 400, width: 80, height: 80)),
                PanoramaCellVisibility(rowID: "c", directoryID: "/root/Docs", frame: CGRect(x: 900, y: 10, width: 80, height: 80)),
            ],
            viewport: CGRect(x: 0, y: 0, width: 300, height: 200)
        )

        XCTAssertEqual(tracker.snapshot.visibleRowIDs, ["a"])
        XCTAssertEqual(tracker.snapshot.visibleDirectoryPaths, ["/root"])
        XCTAssertTrue(tracker.snapshot.prefetchDirectoryPaths.contains("/root/Photos"))
    }
}

final class PanoramaThumbnailCatalogBuilderTests: XCTestCase {
    func testBuildCollectsGridRowsInVisualOrder() {
        let fileA = makeRow(id: "/root/a.txt", name: "a.txt")
        let fileB = makeRow(id: "/root/b.txt", name: "b.txt")
        let folder = makeRow(id: "/root/Photos", name: "Photos", isDirectory: true)

        let display = PanoramaDisplayRoot(
            rootDirectoryPath: "/root",
            blocks: [
                .itemGrid(
                    depth: 0,
                    directoryID: "/root",
                    gridInstanceID: fileA.id,
                    items: [.file(fileA), .folderCollapsed(folder), .file(fileB)]
                ),
            ]
        )

        let catalog = PanoramaThumbnailCatalogBuilder.build(from: display)
        XCTAssertEqual(catalog.orderedRowIDs, [fileA.id, folder.id, fileB.id])
        XCTAssertEqual(catalog.directoryIDByRowID[fileA.id], "/root")
    }

    private func makeRow(id: String, name: String, isDirectory: Bool = false) -> FileListRow {
        FileListRow(
            id: id,
            name: name,
            fileType: isDirectory ? "Folder" : "txt",
            sizeDisplay: "1k",
            dateDisplay: "",
            size: 1024,
            modificationDate: .distantPast,
            isDirectory: isDirectory,
            isHidden: false,
            isParentDirectoryEntry: false,
            iconPath: id
        )
    }
}
