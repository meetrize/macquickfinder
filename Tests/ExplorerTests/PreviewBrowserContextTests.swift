import XCTest
@testable import Explorer

@MainActor
final class PreviewBrowserContextTests: XCTestCase {
    private func makeFileItem(
        id: String,
        name: String,
        size: Int64 = 0,
        date: Date = .distantPast
    ) -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: false,
            modificationDate: date,
            size: size,
            isHidden: false,
            fileType: (name as NSString).pathExtension,
            sizeDisplay: "\(size) B",
            dateDisplay: ""
        )
    }

    func testSameTypeOnlyFilterKeepsCurrentExtension() {
        let items = [
            makeFileItem(id: "a", name: "a.png"),
            makeFileItem(id: "b", name: "b.png"),
            makeFileItem(id: "c", name: "c.pdf"),
        ]

        guard let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "a",
            sameTypeOnly: true
        ) else {
            return XCTFail("expected context")
        }

        XCTAssertEqual(context.orderedItems.map(\.id), ["a", "b"])
        XCTAssertEqual(context.currentItem.id, "a")
        XCTAssertTrue(context.canBrowse)
    }

    func testSetSameTypeOnlyRepositionsCurrentFile() {
        let items = [
            makeFileItem(id: "a", name: "a.png"),
            makeFileItem(id: "b", name: "b.png"),
            makeFileItem(id: "c", name: "c.pdf"),
        ]

        guard let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "c",
            sameTypeOnly: false
        ) else {
            return XCTFail("expected context")
        }

        XCTAssertEqual(context.count, 3)
        context.setSameTypeOnly(true)
        XCTAssertEqual(context.orderedItems.map(\.id), ["c"])
        XCTAssertFalse(context.canBrowse)
    }

    func testSinglePreviewableFileCannotBrowse() {
        let items = [makeFileItem(id: "a", name: "a.png")]
        let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "a"
        )
        XCTAssertNotNil(context)
        XCTAssertFalse(context?.canBrowse ?? true)
        XCTAssertEqual(context?.count, 1)
    }

    func testFiltersDirectoriesAndNonPreviewable() {
        let folder = FileItem(
            id: "/tmp/folder",
            url: URL(fileURLWithPath: "/tmp/folder"),
            name: "folder",
            isDirectory: true,
            modificationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "文件夹",
            sizeDisplay: "--",
            dateDisplay: ""
        )
        let items = [
            folder,
            makeFileItem(id: "a", name: "a.png"),
            makeFileItem(id: "b", name: "b.xyzunknown"),
            makeFileItem(id: "c", name: "c.pdf"),
        ]

        let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "a"
        )

        XCTAssertEqual(context?.count, 2)
        XCTAssertEqual(context?.orderedItems.map(\.id), ["a", "c"])
        XCTAssertTrue(context?.canBrowse ?? false)
    }

    func testSortOrderMatchesFileListSortEngine() {
        let items = [
            makeFileItem(id: "b", name: "b.png", size: 200),
            makeFileItem(id: "a", name: "a.png", size: 100),
        ]

        let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .sizeSmallest,
            showHiddenFiles: true,
            currentFileID: "b"
        )

        XCTAssertEqual(context?.orderedItems.map(\.id), ["a", "b"])
        XCTAssertEqual(context?.currentIndex, 1)
    }

    func testSelectPreviousAndNextAtBoundaries() {
        let items = [
            makeFileItem(id: "a", name: "a.png"),
            makeFileItem(id: "b", name: "b.png"),
            makeFileItem(id: "c", name: "c.png"),
        ]
        guard let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "a"
        ) else {
            return XCTFail("expected context")
        }

        XCTAssertFalse(context.selectPrevious())
        XCTAssertEqual(context.currentIndex, 0)

        XCTAssertTrue(context.selectNext())
        XCTAssertEqual(context.currentItem.id, "b")
        XCTAssertTrue(context.selectNext())
        XCTAssertEqual(context.currentItem.id, "c")
        XCTAssertFalse(context.selectNext())

        XCTAssertTrue(context.select(index: 0))
        XCTAssertEqual(context.currentItem.id, "a")
        XCTAssertFalse(context.select(index: 99))
    }

    func testHiddenFilesRespectShowHiddenFilesFlag() {
        var hidden = makeFileItem(id: "h", name: "hidden.png")
        hidden = FileItem(
            id: hidden.id,
            url: hidden.url,
            name: hidden.name,
            isDirectory: false,
            modificationDate: hidden.modificationDate,
            size: hidden.size,
            isHidden: true,
            fileType: hidden.fileType,
            sizeDisplay: hidden.sizeDisplay,
            dateDisplay: hidden.dateDisplay
        )
        let visible = makeFileItem(id: "v", name: "visible.png")

        let hiddenShown = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: [hidden, visible],
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "v"
        )
        XCTAssertEqual(hiddenShown?.count, 2)

        let hiddenFiltered = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: [hidden, visible],
            sortOrder: .nameAscending,
            showHiddenFiles: false,
            currentFileID: "v"
        )
        XCTAssertEqual(hiddenFiltered?.count, 1)
        XCTAssertEqual(hiddenFiltered?.orderedItems.first?.id, "v")
    }

    func testRemoveCurrentItemSelectsNext() {
        let items = [
            makeFileItem(id: "a", name: "a.png"),
            makeFileItem(id: "b", name: "b.png"),
            makeFileItem(id: "c", name: "c.png"),
        ]
        guard let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "b"
        ) else {
            return XCTFail("expected context")
        }

        XCTAssertTrue(context.removeItem(withID: "b"))
        XCTAssertEqual(context.orderedItems.map(\.id), ["a", "c"])
        XCTAssertEqual(context.currentItem.id, "c")
    }

    func testRemoveLastCurrentItemSelectsPrevious() {
        let items = [
            makeFileItem(id: "a", name: "a.png"),
            makeFileItem(id: "b", name: "b.png"),
            makeFileItem(id: "c", name: "c.png"),
        ]
        guard let context = PreviewBrowserContext.makeSnapshot(
            directoryPath: "/tmp",
            items: items,
            sortOrder: .nameAscending,
            showHiddenFiles: true,
            currentFileID: "c"
        ) else {
            return XCTFail("expected context")
        }

        XCTAssertTrue(context.removeItem(withID: "c"))
        XCTAssertEqual(context.orderedItems.map(\.id), ["a", "b"])
        XCTAssertEqual(context.currentItem.id, "b")
    }
}
