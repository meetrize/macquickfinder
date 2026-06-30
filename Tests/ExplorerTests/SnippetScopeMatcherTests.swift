import XCTest
@testable import Explorer

final class SnippetScopeMatcherTests: XCTestCase {
    private func item(path: String, isDirectory: Bool) -> FileItem {
        FileItem(
            id: path,
            url: URL(fileURLWithPath: path),
            name: (path as NSString).lastPathComponent,
            isDirectory: isDirectory,
            modificationDate: Date(),
            creationDate: Date(),
            size: 0,
            isHidden: false,
            fileType: isDirectory ? "文件夹" : (path as NSString).pathExtension,
            sizeDisplay: "",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    private func context(selected: [FileItem]) -> SnippetVisibilityContext {
        SnippetVisibilityContext(cwd: "/Users/me", selectedItems: selected, showHiddenFiles: false)
    }

    func testGlobalRequiresSelection() {
        XCTAssertFalse(SnippetScopeMatcher.isVisible(scope: .global, context: context(selected: [])))
        XCTAssertTrue(SnippetScopeMatcher.isVisible(scope: .global, context: context(selected: [item(path: "/a", isDirectory: true)])))
    }

    func testFilesOnly() {
        let dir = item(path: "/d", isDirectory: true)
        let file = item(path: "/f.txt", isDirectory: false)
        XCTAssertFalse(SnippetScopeMatcher.isVisible(scope: .filesOnly, context: context(selected: [dir])))
        XCTAssertTrue(SnippetScopeMatcher.isVisible(scope: .filesOnly, context: context(selected: [file])))
    }

    func testSingleSelection() {
        let a = item(path: "/a", isDirectory: false)
        let b = item(path: "/b", isDirectory: false)
        XCTAssertTrue(SnippetScopeMatcher.isVisible(scope: .singleSelection, context: context(selected: [a])))
        XCTAssertFalse(SnippetScopeMatcher.isVisible(scope: .singleSelection, context: context(selected: [a, b])))
    }

    func testFileExtensions() {
        let pdf = item(path: "/doc.pdf", isDirectory: false)
        let txt = item(path: "/doc.txt", isDirectory: false)
        XCTAssertTrue(SnippetScopeMatcher.isVisible(scope: .fileExtensions(["pdf"]), context: context(selected: [pdf])))
        XCTAssertFalse(SnippetScopeMatcher.isVisible(scope: .fileExtensions(["pdf"]), context: context(selected: [txt])))
    }
}
