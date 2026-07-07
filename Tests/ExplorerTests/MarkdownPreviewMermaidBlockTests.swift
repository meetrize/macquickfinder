import XCTest
@testable import Explorer

final class MarkdownPreviewMermaidBlockTests: XCTestCase {
    func testFindsBasicMermaidBlock() {
        let lines = [
            "## 阶段流程图",
            "",
            "```mermaid",
            "flowchart TD",
            "    A --> B",
            "```",
            "",
            "tail",
        ]

        let blocks = MarkdownPreviewMermaidBlock.findBlocks(in: lines)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].startLine, 2)
        XCTAssertEqual(blocks[0].endLine, 6)
        XCTAssertEqual(blocks[0].source, "flowchart TD\n    A --> B")
    }

    func testRecognizesCaseInsensitiveOpenFence() {
        XCTAssertTrue(MarkdownPreviewMermaidBlock.isMermaidOpenFence("```Mermaid"))
        XCTAssertTrue(MarkdownPreviewMermaidBlock.isMermaidOpenFence("  ``` mermaid  "))
        XCTAssertFalse(MarkdownPreviewMermaidBlock.isMermaidOpenFence("```markdown"))
        XCTAssertFalse(MarkdownPreviewMermaidBlock.isMermaidOpenFence("```mermaidjs"))
    }

    func testIgnoresMermaidInsideGenericFence() {
        let lines = [
            "```swift",
            "```mermaid",
            "flowchart TD",
            "```",
            "```",
        ]

        XCTAssertTrue(MarkdownPreviewMermaidBlock.findBlocks(in: lines).isEmpty)
    }

    func testIgnoresUnclosedMermaidBlock() {
        let lines = [
            "```mermaid",
            "flowchart TD",
            "    A --> B",
        ]

        XCTAssertTrue(MarkdownPreviewMermaidBlock.findBlocks(in: lines).isEmpty)
    }

    func testApplyReplacesFenceWithAttachmentPlaceholder() {
        let markdown = """
        before

        ```mermaid
        flowchart TD
            A --> B
        ```

        after
        """
        let rendered = NSMutableAttributedString(string: markdown)
        let pending = MarkdownPreviewMermaidBlock.apply(
            in: rendered,
            layoutWidth: 320,
            renderingLabel: "Rendering diagram…",
            isDark: false,
            cachedRenders: [:]
        )

        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending[0].source, "flowchart TD\n    A --> B")
        XCTAssertFalse(rendered.string.contains("```mermaid"))
        XCTAssertFalse(rendered.string.contains("flowchart TD"))

        var attachmentCount = 0
        rendered.enumerateAttribute(.attachment, in: NSRange(location: 0, length: rendered.length)) { value, _, _ in
            if value is MarkdownMermaidAttachment {
                attachmentCount += 1
            }
        }
        XCTAssertEqual(attachmentCount, 1)
    }
}
