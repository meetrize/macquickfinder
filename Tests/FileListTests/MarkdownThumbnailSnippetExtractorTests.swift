import XCTest
@testable import FileList

final class MarkdownThumbnailSnippetExtractorTests: XCTestCase {
    func testExtractsFirstATXHeadingAndBody() {
        let markdown = """
        ---
        title: ignored
        ---

        # 项目说明

        这是正文第一段，应该出现在缩略图下方。
        第二段也会被截取。
        """

        let snippet = MarkdownThumbnailSnippetExtractor.extract(from: markdown)
        XCTAssertEqual(snippet?.titleText, "项目说明")
        XCTAssertEqual(snippet?.headingLevel, 1)
        XCTAssertFalse(snippet?.isFallbackTitle ?? true)
        XCTAssertTrue(snippet?.bodyPreview.contains("正文第一段") ?? false)
    }

    func testUsesFirstHeadingInDocumentOrderRegardlessOfLevel() {
        let markdown = """
        ## 二级标题

        正文内容。
        """

        let snippet = MarkdownThumbnailSnippetExtractor.extract(from: markdown)
        XCTAssertEqual(snippet?.titleText, "二级标题")
        XCTAssertEqual(snippet?.headingLevel, 2)
        XCTAssertEqual(snippet?.bodyPreview, "正文内容。")
    }

    func testFallbackToFirstLineWhenNoHeading() {
        let markdown = """
        这是没有标题的笔记，应该从首句截取标题。

        后续段落作为正文预览。
        """

        let snippet = MarkdownThumbnailSnippetExtractor.extract(from: markdown)
        XCTAssertEqual(snippet?.titleText, "这是没有标题的笔记，应该从首")
        XCTAssertNil(snippet?.headingLevel)
        XCTAssertTrue(snippet?.isFallbackTitle ?? false)
        XCTAssertTrue(snippet?.bodyPreview.contains("后续段落") ?? false)
    }

    func testSkipsFencedCodeBlocksInBody() {
        let markdown = """
        # 标题

        可见正文。

        ```
        let secret = 1
        ```

        另一段正文。
        """

        let snippet = MarkdownThumbnailSnippetExtractor.extract(from: markdown)
        XCTAssertEqual(snippet?.titleText, "标题")
        XCTAssertTrue(snippet?.bodyPreview.contains("可见正文") ?? false)
        XCTAssertFalse(snippet?.bodyPreview.contains("secret") ?? true)
        XCTAssertTrue(snippet?.bodyPreview.contains("另一段正文") ?? false)
    }

    func testStripInlineMarkdown() {
        XCTAssertEqual(
            MarkdownThumbnailSnippetExtractor.stripInlineMarkdown("**粗体**与`代码`"),
            "粗体与代码"
        )
        XCTAssertEqual(
            MarkdownThumbnailSnippetExtractor.stripInlineMarkdown("[链接文字](https://example.com)"),
            "链接文字"
        )
    }

    func testReturnsNilForEmptyContent() {
        XCTAssertNil(MarkdownThumbnailSnippetExtractor.extract(from: ""))
        XCTAssertNil(MarkdownThumbnailSnippetExtractor.extract(from: "   \n\n   "))
    }

    func testUtf8SafePrefixAvoidsSplittingMultibyteCharacter() {
        let text = String(repeating: "文", count: 100)
        let data = Data((text + "# 标题").utf8)
        let splitIndex = data.count - 2
        let truncated = Data(data.prefix(splitIndex))
        XCTAssertNil(String(data: truncated, encoding: .utf8))
        let repaired = MarkdownThumbnailSnippetExtractor.utf8SafePrefix(of: truncated)
        XCTAssertNotNil(String(data: repaired, encoding: .utf8))
    }

    func testDecodePreviewTextSupportsUTF8Chinese() {
        let data = Data("# 全球行业文件格式\n\n正文".utf8)
        let decoded = MarkdownThumbnailSnippetExtractor.decodePreviewText(from: data)
        XCTAssertEqual(decoded?.contains("全球行业"), true)
    }
}

final class MarkdownThumbnailLayoutMetricsTests: XCTestCase {
    func testTitleZoneUsesConfiguredRatioOfDrawableHeight() {
        let cellSize: CGFloat = 128
        let topInset = MarkdownThumbnailLayoutMetrics.contentTopInset(for: cellSize)
        let drawable = MarkdownThumbnailLayoutMetrics.drawableHeight(cellSize: cellSize)
        let titleZone = MarkdownThumbnailLayoutMetrics.titleZoneHeight(cellSize: cellSize)
        XCTAssertEqual(drawable, 128 - 20 - topInset, accuracy: 0.01)
        XCTAssertEqual(titleZone / drawable, 0.32, accuracy: 0.01)
    }

    func testTitleFontSizeScalesWithHeadingLevel() {
        let h1 = MarkdownThumbnailLayoutMetrics.titleFontSize(cellSize: 128, headingLevel: 1)
        let h3 = MarkdownThumbnailLayoutMetrics.titleFontSize(cellSize: 128, headingLevel: 3)
        XCTAssertGreaterThan(h1, h3)
    }
}

final class MarkdownThumbnailCacheKeyTests: XCTestCase {
    private func row(name: String, iconPath: String) -> FileListRow {
        FileListRow(
            id: name,
            name: name,
            fileType: "txt",
            sizeDisplay: "0",
            dateDisplay: "",
            size: 100,
            modificationDate: Date(timeIntervalSinceReferenceDate: 0),
            isDirectory: false,
            isHidden: false,
            isParentDirectoryEntry: false,
            iconPath: iconPath
        )
    }

    func testMarkdownCacheKeyUsesRendererRevision() {
        let mdKey = ThumbnailCache.Key(row: row(name: "note.md", iconPath: "/tmp/note.md"), sizeBucket: 128)
        let txtKey = ThumbnailCache.Key(row: row(name: "note.txt", iconPath: "/tmp/note.txt"), sizeBucket: 128)
        XCTAssertEqual(mdKey.rendererRevision, ThumbnailCache.Key.markdownThumbnailRendererRevision)
        XCTAssertEqual(txtKey.rendererRevision, 0)
        XCTAssertNotEqual(mdKey, txtKey)
    }
}
