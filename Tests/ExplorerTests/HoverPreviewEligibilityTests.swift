import FileList
import XCTest
@testable import Explorer

@MainActor
final class HoverPreviewEligibilityTests: XCTestCase {
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
        name: String = "photo.png",
        isDirectory: Bool = false,
        ext: String = "png"
    ) -> FileItem {
        let fileName = name.contains(".") ? name : "name.\(ext)"
        return FileItem(
            id: "/tmp/\(fileName)",
            url: URL(fileURLWithPath: "/tmp/\(fileName)"),
            name: fileName,
            isDirectory: isDirectory,
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
    }

    func testRejectsDirectoryAndParent() {
        XCTAssertFalse(
            HoverPreviewEligibility.shouldShow(
                for: makeFileItem(isDirectory: true),
                rightPanelVisible: false,
                rightPanelURL: nil
            )
        )
        XCTAssertFalse(
            HoverPreviewEligibility.shouldShow(
                for: FileItem.parentDirectoryEntry(),
                rightPanelVisible: false,
                rightPanelURL: nil
            )
        )
    }

    func testAcceptsPreviewableFile() {
        XCTAssertTrue(
            HoverPreviewEligibility.shouldShow(
                for: makeFileItem(ext: "png"),
                rightPanelVisible: false,
                rightPanelURL: nil
            )
        )
    }

    func testSkipsWhenRightPanelShowsSameFile() {
        let item = makeFileItem(ext: "png")
        XCTAssertFalse(
            HoverPreviewEligibility.shouldShow(
                for: item,
                rightPanelVisible: true,
                rightPanelURL: item.url
            )
        )
        XCTAssertTrue(
            HoverPreviewEligibility.shouldShow(
                for: item,
                rightPanelVisible: true,
                rightPanelURL: URL(fileURLWithPath: "/tmp/other.png")
            )
        )
    }

    func testCandidateRowFiltersDirectories() {
        let file = FileListRow(item: makeFileItem(ext: "txt"))
        let folder = FileListRow(item: makeFileItem(name: "docs", isDirectory: true, ext: ""))
        XCTAssertTrue(HoverPreviewEligibility.isCandidateRow(file))
        XCTAssertFalse(HoverPreviewEligibility.isCandidateRow(folder))
        XCTAssertFalse(HoverPreviewEligibility.isCandidateRow(FileListRow(item: FileItem.parentDirectoryEntry())))
    }
}
