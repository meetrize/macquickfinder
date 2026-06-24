import XCTest
@testable import Explorer

final class OutputPanelAttributedTextTests: XCTestCase {
    func testStderrUsesDistinctColorFromStdout() {
        let nsAttr = OutputPanelAttributedText.makeNSAttributedString(
            stdout: "ok\n",
            stderr: "err\n",
            findText: ""
        )

        XCTAssertTrue(nsAttr.string.contains("ok"))
        XCTAssertTrue(nsAttr.string.contains("err"))

        var hasStdoutColor = false
        var hasStderrColor = false
        nsAttr.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: nsAttr.length)) { value, _, _ in
            guard let color = value as? NSColor else { return }
            if color == OutputPanelStyle.stdoutNSColor { hasStdoutColor = true }
            if color == OutputPanelStyle.stderrNSColor { hasStderrColor = true }
        }
        XCTAssertTrue(hasStdoutColor)
        XCTAssertTrue(hasStderrColor)
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
