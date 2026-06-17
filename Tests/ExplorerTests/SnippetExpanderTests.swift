import XCTest
@testable import Explorer

final class SnippetExpanderTests: XCTestCase {
    private func file(path: String) -> FileItem {
        FileItem(
            id: path,
            url: URL(fileURLWithPath: path),
            name: (path as NSString).lastPathComponent,
            isDirectory: false,
            modificationDate: Date(),
            size: 100,
            isHidden: false,
            fileType: (path as NSString).pathExtension,
            sizeDisplay: "100",
            dateDisplay: ""
        )
    }

    func testExpandDirectory() throws {
        let ctx = SnippetExecutionContext(cwd: "/Users/me/Projects", selectedItems: [])
        let result = try SnippetExpander.expand("ls %d", context: ctx)
        XCTAssertTrue(result.contains("Projects"))
    }

    func testExpandSinglePath() throws {
        let f = file(path: "/Users/me/file.txt")
        let ctx = SnippetExecutionContext(cwd: "/Users/me", selectedItems: [f])
        let result = try SnippetExpander.expand("stat %p", context: ctx)
        XCTAssertTrue(result.contains("file.txt"))
    }

    func testRequiresSelectionForPercentP() {
        let ctx = SnippetExecutionContext(cwd: "/Users/me", selectedItems: [])
        XCTAssertThrowsError(try SnippetExpander.expand("stat %p", context: ctx)) { error in
            XCTAssertEqual(error as? SnippetExpansionError, .requiresSingleSelection)
        }
    }

    func testRequiresFileForPercentF() {
        let dir = FileItem(
            id: "/d",
            url: URL(fileURLWithPath: "/d"),
            name: "d",
            isDirectory: true,
            modificationDate: Date(),
            size: 0,
            isHidden: false,
            fileType: "文件夹",
            sizeDisplay: "",
            dateDisplay: ""
        )
        let ctx = SnippetExecutionContext(cwd: "/", selectedItems: [dir])
        XCTAssertThrowsError(try SnippetExpander.expand("%f", context: ctx)) { error in
            XCTAssertEqual(error as? SnippetExpansionError, .requiresFileSelection)
        }
    }
}
