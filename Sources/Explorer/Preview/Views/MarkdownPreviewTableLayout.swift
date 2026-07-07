import AppKit
import Foundation

/// Markdown 预览表格排版：用 `\t` + `NSTextTab` 在 `NSTextView` 里对齐列，不依赖 WKWebView。
enum MarkdownPreviewTableLayout {
    struct Block: Equatable {
        let startLine: Int
        let endLine: Int
        let indent: String
    }

    struct FormattedBlock: Equatable {
        let lines: [String]
        let tabStopLocations: [CGFloat]
    }

    static func isFenceLine(_ line: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
    }

    static func isTableRowLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let pipeCount = trimmed.filter { $0 == "|" }.count
        return pipeCount >= 2 && trimmed.contains("|")
    }

    static func isSeparatorLine(_ line: String, separatorRegex: NSRegularExpression?) -> Bool {
        guard let separatorRegex else { return false }
        let range = NSRange(location: 0, length: (line as NSString).length)
        return separatorRegex.firstMatch(in: line, options: [], range: range) != nil
    }

    static func leadingIndent(_ line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    static func parseCells(_ line: String) -> [String] {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        var core = trimmed
        if core.hasPrefix("|") { core.removeFirst() }
        if core.hasSuffix("|") { core.removeLast() }
        return core
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    static func findBlocks(in lines: [String], separatorRegex: NSRegularExpression?) -> [Block] {
        var blocks: [Block] = []
        var inFence = false
        var index = 0

        while index < lines.count {
            let line = lines[index]
            if isFenceLine(line) {
                inFence.toggle()
                index += 1
                continue
            }
            if inFence {
                index += 1
                continue
            }

            if index + 1 < lines.count,
               isTableRowLine(lines[index]),
               isSeparatorLine(lines[index + 1], separatorRegex: separatorRegex) {
                let indent = leadingIndent(lines[index])
                var end = index + 2
                while end < lines.count, isTableRowLine(lines[end]) {
                    end += 1
                }
                blocks.append(Block(startLine: index, endLine: end, indent: indent))
                index = end
                continue
            }

            index += 1
        }

        return blocks
    }

    static func formatBlock(
        lines: [String],
        block: Block,
        font: NSFont
    ) -> FormattedBlock? {
        guard block.endLine > block.startLine + 1 else { return nil }

        let blockLines = Array(lines[block.startLine..<block.endLine])
        let headerCells = parseCells(blockLines[0])
        let bodyRows = blockLines.dropFirst(2).map { parseCells($0) }
        let allRows = [headerCells] + bodyRows
        let columnCount = allRows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return nil }

        var columnSegmentWidths = Array(repeating: CGFloat(0), count: columnCount)
        for row in allRows {
            for column in 0..<columnCount {
                let cell = column < row.count ? row[column] : ""
                let segment = columnSegment(for: cell, column: column, columnCount: columnCount)
                let width = measuredWidth(segment, font: font)
                columnSegmentWidths[column] = max(columnSegmentWidths[column], width)
            }
        }

        let indentWidth = measuredWidth(block.indent, font: font)
        var tabStopLocations: [CGFloat] = []
        var x = indentWidth
        for column in 0..<(columnCount - 1) {
            x += columnSegmentWidths[column]
            tabStopLocations.append(x)
        }

        var formattedLines: [String] = []
        formattedLines.reserveCapacity(blockLines.count)
        for (offset, _) in blockLines.enumerated() {
            if offset == 1 {
                let separatorCells = (0..<columnCount).map { _ in "---" }
                formattedLines.append(
                    formatRow(
                        cells: separatorCells,
                        columnCount: columnCount,
                        indent: block.indent
                    )
                )
            } else {
                let rowIndex = offset == 0 ? 0 : offset - 1
                let cells = rowIndex == 0 ? headerCells : bodyRows[rowIndex - 1]
                formattedLines.append(
                    formatRow(
                        cells: cells,
                        columnCount: columnCount,
                        indent: block.indent
                    )
                )
            }
        }

        return FormattedBlock(lines: formattedLines, tabStopLocations: tabStopLocations)
    }

    static func measuredWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static func columnSegment(for cell: String, column: Int, columnCount: Int) -> String {
        if column == columnCount - 1 {
            return "| \(cell) |"
        }
        return "| \(cell)"
    }

    private static func formatRow(cells: [String], columnCount: Int, indent: String) -> String {
        guard columnCount > 0 else { return indent }

        var row = indent
        for column in 0..<columnCount {
            let cell = column < cells.count ? cells[column] : ""
            if column == 0 {
                row += column == columnCount - 1 ? "| \(cell) |" : "| \(cell)"
            } else {
                row += column == columnCount - 1 ? "\t| \(cell) |" : "\t| \(cell)"
            }
        }
        return row
    }
}
