import XCTest
@testable import Explorer

final class FileItemRealSelectionTests: XCTestCase {
    func testEmptySelectionIsNotReal() {
        XCTAssertFalse(FileItem.hasRealSelection(ids: [], in: [makeItem(id: "/tmp/a")]))
    }

    func testParentDirectoryOnlyIsNotReal() {
        XCTAssertFalse(
            FileItem.hasRealSelection(
                ids: [FileItem.parentDirectoryID],
                in: [FileItem.parentDirectoryEntry(), makeItem(id: "/tmp/a")]
            )
        )
    }

    func testListedFileIsReal() {
        let item = makeItem(id: "/tmp/a")
        XCTAssertTrue(FileItem.hasRealSelection(ids: [item.id], in: [item]))
    }

    func testOutOfListContentSearchPathIsReal() {
        // 内容搜索命中当前目录外的子文件时，selection 不在 items 中。
        XCTAssertTrue(
            FileItem.hasRealSelection(
                ids: ["/tmp/project/src/main.swift"],
                in: [makeItem(id: "/tmp/project")]
            )
        )
    }

    func testOutOfListParentSentinelStillIgnored() {
        XCTAssertFalse(
            FileItem.hasRealSelection(
                ids: [FileItem.parentDirectoryID],
                in: []
            )
        )
    }

    func testAutoModeShowsPanelWhenContentSearchSelectsOutOfListFile() {
        let defaults = UserDefaults(suiteName: "FileItemRealSelection.\(UUID().uuidString)")!
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        layout.setRightPanelMode(.auto)
        layout.showPreview = true
        layout.showSnippets = false

        let hasSelection = FileItem.hasRealSelection(
            ids: ["/Applications/Demo.app/Contents/Info.plist"],
            in: [makeItem(id: "/Applications", isDirectory: true)]
        )
        XCTAssertTrue(hasSelection)
        let effective = layout.effectiveRightPanelVisibility(hasSelection: hasSelection)
        XCTAssertTrue(effective.showPreview)
        XCTAssertTrue(layout.isRightPanelEffectivelyVisible(hasSelection: hasSelection))
    }

    private func makeItem(id: String, isDirectory: Bool = false) -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: id),
            name: (id as NSString).lastPathComponent,
            isDirectory: isDirectory,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: isDirectory ? "文件夹" : "swift",
            sizeDisplay: "—",
            dateDisplay: "—",
            creationDateDisplay: "—",
            finderComment: "",
            tags: []
        )
    }
}
