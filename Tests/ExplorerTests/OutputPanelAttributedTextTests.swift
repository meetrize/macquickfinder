import XCTest
@testable import Explorer

final class OutputPanelAttributedTextTests: XCTestCase {
    func testStderrUsesDistinctColorFromStdout() {
        let attr = OutputPanelAttributedText.make(
            stdout: "ok\n",
            stderr: "err\n",
            emptyPlaceholder: "(empty)",
            findText: ""
        )

        let source = String(attr.characters)
        XCTAssertTrue(source.contains("ok"))
        XCTAssertTrue(source.contains("err"))

        XCTAssertFalse(attr.runs.filter { $0.foregroundColor == OutputPanelStyle.stdoutColor }.isEmpty)
        XCTAssertFalse(attr.runs.filter { $0.foregroundColor == OutputPanelStyle.stderrColor }.isEmpty)
    }

    func testHighlightsPromptPathAndCommand() {
        let stdout = "\n\nProjects $ ls -la\n"
        let attr = OutputPanelAttributedText.make(
            stdout: stdout,
            stderr: "",
            emptyPlaceholder: "(empty)",
            findText: ""
        )

        XCTAssertNotNil(attr.range(of: "Projects"))
        XCTAssertNotNil(attr.range(of: "ls -la"))
    }

    func testInlineStderrRendersBeforeNextPrompt() {
        let stdout = """
        \n\nProjects $ cd bad\n\(OutputSessionFormatting.wrapStderr("cd: no such file\n"))\n✗\n\n\nProjects $ true\n\n✓\n
        """
        let attr = OutputPanelAttributedText.make(
            stdout: stdout,
            stderr: "",
            emptyPlaceholder: "(empty)",
            findText: ""
        )
        let source = String(attr.characters)
        let errorIndex = source.range(of: "cd: no such file")!.lowerBound
        let nextCommandIndex = source.range(of: "true")!.lowerBound
        XCTAssertLessThan(errorIndex, nextCommandIndex)
    }

    func testStripStderrMarkersRemovesControlCharacters() {
        let wrapped = OutputSessionFormatting.wrapStderr("err\n")
        XCTAssertEqual(OutputSessionFormatting.stripStderrMarkers(wrapped), "err\n")
    }
}
