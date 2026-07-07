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
        let separatorLineIndices: Set<Int>
    }

    struct LayoutOptions: Equatable {
        var availableWidth: CGFloat?

        static let natural = LayoutOptions(availableWidth: nil)
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
        font: NSFont,
        options: LayoutOptions = .natural
    ) -> FormattedBlock? {
        guard block.endLine > block.startLine + 1 else { return nil }

        let blockLines = Array(lines[block.startLine..<block.endLine])
        let headerCells = parseCells(blockLines[0])
        let bodyRows = blockLines.dropFirst(2).map { parseCells($0) }
        let allRows = [headerCells] + bodyRows
        let columnCount = allRows.map(\.count).max() ?? 0
        guard columnCount > 0 else { return nil }

        var naturalContentWidths = Array(repeating: CGFloat(0), count: columnCount)
        for row in allRows {
            for column in 0..<columnCount {
                let cell = column < row.count ? row[column] : ""
                naturalContentWidths[column] = max(
                    naturalContentWidths[column],
                    measuredWidth(cell, font: font)
                )
            }
        }

        let indentWidth = measuredWidth(block.indent, font: font)
        let assignedContentWidths = assignColumnContentWidths(
            naturalWidths: naturalContentWidths,
            columnCount: columnCount,
            availableWidth: options.availableWidth,
            indentWidth: indentWidth,
            font: font
        )

        var tabStopLocations: [CGFloat] = []
        var x = indentWidth
        for column in 0..<(columnCount - 1) {
            x += measuredWidth("| ", font: font) + assignedContentWidths[column]
            tabStopLocations.append(x)
        }

        var formattedLines: [String] = []
        var separatorLineIndices: Set<Int> = []
        formattedLines.reserveCapacity(blockLines.count)

        for (offset, _) in blockLines.enumerated() {
            if offset == 1 {
                separatorLineIndices.insert(formattedLines.count)
                formattedLines.append(
                    formatSeparatorRow(
                        columnContentWidths: assignedContentWidths,
                        columnCount: columnCount,
                        indent: block.indent,
                        font: font
                    )
                )
                continue
            }

            let cells: [String]
            if offset == 0 {
                cells = headerCells
            } else {
                cells = bodyRows[offset - 2]
            }

            let wrappedRows = expandWrappedRow(
                cells: cells,
                columnCount: columnCount,
                columnContentWidths: assignedContentWidths,
                font: font
            )
            for wrappedCells in wrappedRows {
                formattedLines.append(
                    formatRow(
                        cells: wrappedCells,
                        columnCount: columnCount,
                        indent: block.indent
                    )
                )
            }
        }

        return FormattedBlock(
            lines: formattedLines,
            tabStopLocations: tabStopLocations,
            separatorLineIndices: separatorLineIndices
        )
    }

    static func measuredWidth(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    static func assignColumnContentWidths(
        naturalWidths: [CGFloat],
        columnCount: Int,
        availableWidth: CGFloat?,
        indentWidth: CGFloat,
        font: NSFont
    ) -> [CGFloat] {
        let minContentWidth = measuredWidth("----", font: font)
        let normalizedNatural = normalizedWidths(naturalWidths, columnCount: columnCount, minimum: minContentWidth)

        guard let availableWidth, availableWidth > 0 else {
            return normalizedNatural
        }

        let overhead = tableHorizontalOverhead(
            columnCount: columnCount,
            indentWidth: indentWidth,
            font: font
        )
        let naturalTotal = overhead + normalizedNatural.reduce(0, +)
        if naturalTotal <= availableWidth {
            return normalizedNatural
        }

        let usableContentWidth = max(
            availableWidth - overhead,
            minContentWidth * CGFloat(columnCount)
        )
        let naturalSum = normalizedNatural.reduce(0, +)
        guard naturalSum > 0 else {
            return Array(repeating: max(minContentWidth, usableContentWidth / CGFloat(columnCount)), count: columnCount)
        }

        var assigned = normalizedNatural.map { width in
            max(minContentWidth, usableContentWidth * (width / naturalSum))
        }

        let assignedSum = assigned.reduce(0, +)
        if assignedSum > usableContentWidth, assignedSum > 0 {
            let scale = usableContentWidth / assignedSum
            assigned = assigned.map { max(minContentWidth, $0 * scale) }
        }

        return assigned
    }

    static func wrapCellText(_ text: String, maxWidth: CGFloat, font: NSFont) -> [String] {
        guard !text.isEmpty else { return [""] }
        guard maxWidth > 0 else { return [text] }
        if measuredWidth(text, font: font) <= maxWidth {
            return [text]
        }

        var lines: [String] = []
        var current = ""

        for word in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            if current.isEmpty {
                if measuredWidth(word, font: font) <= maxWidth {
                    current = word
                } else {
                    lines.append(contentsOf: breakByCharacter(word, maxWidth: maxWidth, font: font))
                }
                continue
            }

            let candidate = current + " " + word
            if measuredWidth(candidate, font: font) <= maxWidth {
                current = candidate
            } else {
                lines.append(current)
                if measuredWidth(word, font: font) <= maxWidth {
                    current = word
                } else {
                    lines.append(contentsOf: breakByCharacter(word, maxWidth: maxWidth, font: font))
                    current = ""
                }
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }
        return lines.isEmpty ? [""] : lines
    }

    private static func normalizedWidths(
        _ widths: [CGFloat],
        columnCount: Int,
        minimum: CGFloat
    ) -> [CGFloat] {
        (0..<columnCount).map { index in
            max(index < widths.count ? widths[index] : 0, minimum)
        }
    }

    private static func tableHorizontalOverhead(
        columnCount: Int,
        indentWidth: CGFloat,
        font: NSFont
    ) -> CGFloat {
        guard columnCount > 0 else { return indentWidth }
        let pipePrefix = measuredWidth("| ", font: font)
        let closingSuffix = measuredWidth(" |", font: font)
        return indentWidth + (pipePrefix * CGFloat(columnCount)) + closingSuffix
    }

    private static func expandWrappedRow(
        cells: [String],
        columnCount: Int,
        columnContentWidths: [CGFloat],
        font: NSFont
    ) -> [[String]] {
        let wrappedColumns: [[String]] = (0..<columnCount).map { column in
            let cell = column < cells.count ? cells[column] : ""
            let maxWidth = column < columnContentWidths.count ? columnContentWidths[column] : 0
            return wrapCellText(cell, maxWidth: maxWidth, font: font)
        }
        let lineCount = max(wrappedColumns.map(\.count).max() ?? 1, 1)

        return (0..<lineCount).map { lineIndex in
            (0..<columnCount).map { column in
                let lines = wrappedColumns[column]
                return lineIndex < lines.count ? lines[lineIndex] : ""
            }
        }
    }

    private static func breakByCharacter(_ text: String, maxWidth: CGFloat, font: NSFont) -> [String] {
        guard !text.isEmpty else { return [""] }

        var lines: [String] = []
        var current = ""

        for character in text {
            let candidate = current + String(character)
            if current.isEmpty || measuredWidth(candidate, font: font) <= maxWidth {
                current = candidate
            } else {
                lines.append(current)
                current = String(character)
            }
        }

        if !current.isEmpty {
            lines.append(current)
        }
        return lines.isEmpty ? [""] : lines
    }

    private static func formatSeparatorRow(
        columnContentWidths: [CGFloat],
        columnCount: Int,
        indent: String,
        font: NSFont
    ) -> String {
        let cells = (0..<columnCount).map { column in
            let width = column < columnContentWidths.count ? columnContentWidths[column] : measuredWidth("---", font: font)
            return separatorCell(contentWidth: width, font: font)
        }
        return formatRow(cells: cells, columnCount: columnCount, indent: indent)
    }

    private static func separatorCell(contentWidth: CGFloat, font: NSFont) -> String {
        let dashWidth = max(measuredWidth("-", font: font), 1)
        let count = max(3, Int(floor(contentWidth / dashWidth)))
        return String(repeating: "-", count: count)
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
