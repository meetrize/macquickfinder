import XCTest
@testable import Explorer

final class SnippetAskParserTests: XCTestCase {
    func testParseAnonymousAndNamed() throws {
        let template = "zip -P %ask[password]{请输入压缩密码} %ask{输出文件名}.zip"
        let params = try SnippetAskParser.uniqueParameters(in: template)
        XCTAssertEqual(params.count, 2)
        XCTAssertEqual(params[0].askId, "password")
        XCTAssertEqual(params[0].prompt, "请输入压缩密码")
        XCTAssertTrue(params[0].isSecret)
        XCTAssertEqual(params[1].askId, nil)
        XCTAssertEqual(params[1].prompt, "输出文件名")
        XCTAssertFalse(params[1].isSecret)
    }

    func testDedupeById() throws {
        let template = "%ask[name]{A} then %ask[name]{B}"
        let params = try SnippetAskParser.uniqueParameters(in: template)
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].prompt, "A")
    }

    func testDedupeByPrompt() throws {
        let template = "%ask{同一提示} %ask{同一提示}"
        let params = try SnippetAskParser.uniqueParameters(in: template)
        XCTAssertEqual(params.count, 1)
    }

    func testEmptyPrompt() {
        XCTAssertThrowsError(try SnippetAskParser.uniqueParameters(in: "x %ask{} y")) { error in
            XCTAssertEqual(error as? SnippetAskParseError, .emptyPrompt)
        }
    }

    func testUnclosedBrace() {
        XCTAssertThrowsError(try SnippetAskParser.uniqueParameters(in: "%ask{未闭合")) { error in
            XCTAssertEqual(error as? SnippetAskParseError, .unclosedBrace)
        }
    }

    func testInvalidId() {
        XCTAssertThrowsError(try SnippetAskParser.uniqueParameters(in: "%ask[1bad]{x}")) { error in
            XCTAssertEqual(error as? SnippetAskParseError, .invalidId("1bad"))
        }
    }

    func testIgnoreIncompleteAskPrefix() throws {
        let params = try SnippetAskParser.uniqueParameters(in: "echo %askme %ask{真的}")
        XCTAssertEqual(params.count, 1)
        XCTAssertEqual(params[0].prompt, "真的")
    }
}

final class SnippetAskExpanderTests: XCTestCase {
    private func file(path: String) -> FileItem {
        FileItem(
            id: path,
            url: URL(fileURLWithPath: path),
            name: (path as NSString).lastPathComponent,
            isDirectory: false,
            modificationDate: Date(),
            creationDate: Date(),
            size: 100,
            isHidden: false,
            fileType: (path as NSString).pathExtension,
            sizeDisplay: "100",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testShellQuotesAskValue() throws {
        let ctx = SnippetExecutionContext(cwd: "/tmp", selectedItems: [])
        let params = try SnippetAskParser.uniqueParameters(in: "echo %ask{名称}")
        let key = params[0].key
        let result = try SnippetExpander.expand(
            "echo %ask{名称}",
            context: ctx,
            scriptType: .shell,
            askValues: [key: "hello world"]
        )
        XCTAssertEqual(result, "echo 'hello world'")
    }

    func testAskValueWithPercentPNotReexpanded() throws {
        let f = file(path: "/Users/me/file.txt")
        let ctx = SnippetExecutionContext(cwd: "/Users/me", selectedItems: [f])
        let template = "printf %ask{内容} %p"
        let params = try SnippetAskParser.uniqueParameters(in: template)
        let result = try SnippetExpander.expand(
            template,
            context: ctx,
            scriptType: .shell,
            askValues: [params[0].key: "%p"]
        )
        XCTAssertTrue(result.contains("'%p'"))
        XCTAssertTrue(result.contains("file.txt"))
        XCTAssertFalse(result.hasPrefix("printf '/Users"))
    }

    func testNamedAskReused() throws {
        let ctx = SnippetExecutionContext(cwd: "/tmp", selectedItems: [])
        let template = "a=%ask[x]{X};b=%ask[x]{X}"
        let params = try SnippetAskParser.uniqueParameters(in: template)
        XCTAssertEqual(params.count, 1)
        let result = try SnippetExpander.expand(
            template,
            context: ctx,
            scriptType: .python3,
            askValues: [params[0].key: "v"]
        )
        XCTAssertEqual(result, "a=v;b=v")
    }

    func testPythonDoesNotQuote() throws {
        let ctx = SnippetExecutionContext(cwd: "/tmp", selectedItems: [])
        let template = "print(%ask{消息})"
        let params = try SnippetAskParser.uniqueParameters(in: template)
        let result = try SnippetExpander.expand(
            template,
            context: ctx,
            scriptType: .python3,
            askValues: [params[0].key: "hi"]
        )
        XCTAssertEqual(result, "print(hi)")
    }
}
