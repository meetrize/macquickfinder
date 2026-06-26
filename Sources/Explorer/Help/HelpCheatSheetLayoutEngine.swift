import AppKit
import Foundation

struct HelpCheatSheetEntryMetrics {
    let entryID: String
    let nameWidth: CGFloat
    let descriptionWidth: CGFloat
    let shortcutWidth: CGFloat

    var rowWidth: CGFloat {
        HelpCheatSheetLayoutEngine.horizontalPadding * 2
            + nameWidth
            + HelpCheatSheetLayoutEngine.columnSpacing
            + descriptionWidth
            + HelpCheatSheetLayoutEngine.columnSpacing
            + shortcutWidth
    }
}

struct HelpCheatSheetColumnLayout: Identifiable {
    let id: Int
    let sections: [HelpCheatSheetSection]
    let nameWidth: CGFloat
    let descriptionWidth: CGFloat
    let shortcutWidth: CGFloat

    var width: CGFloat {
        HelpCheatSheetLayoutEngine.horizontalPadding * 2
            + nameWidth
            + HelpCheatSheetLayoutEngine.columnSpacing
            + descriptionWidth
            + HelpCheatSheetLayoutEngine.columnSpacing
            + shortcutWidth
    }
}

struct HelpCheatSheetLayout {
    let columns: [HelpCheatSheetColumnLayout]
    let columnGap: CGFloat
    let contentWidth: CGFloat
}

enum HelpCheatSheetLayoutEngine {
    static let columnGap: CGFloat = 20
    static let columnSpacing: CGFloat = 12
    static let horizontalPadding: CGFloat = 12
    static let viewHorizontalPadding: CGFloat = 20
    static let maxColumns = 3

    private static let nameFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold)
    private static let descriptionFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    private static let shortcutFont = NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)

    static func layout(for availableWidth: CGFloat) -> HelpCheatSheetLayout {
        let entryMetrics = measureAllEntries()
        let usableWidth = max(availableWidth - viewHorizontalPadding * 2, 1)

        var selectedColumns: [HelpCheatSheetColumnLayout] = buildColumns(
            columnCount: 1,
            entryMetrics: entryMetrics
        )

        for columnCount in stride(from: maxColumns, through: 1, by: -1) {
            let candidate = buildColumns(columnCount: columnCount, entryMetrics: entryMetrics)
            let totalWidth = totalWidth(for: candidate)
            if totalWidth <= usableWidth {
                selectedColumns = candidate
                break
            }
        }

        let minContentWidth = totalWidth(for: selectedColumns)
        if minContentWidth < usableWidth {
            selectedColumns = expandColumns(selectedColumns, toTotalWidth: usableWidth)
        }

        return HelpCheatSheetLayout(
            columns: selectedColumns,
            columnGap: columnGap,
            contentWidth: max(minContentWidth, usableWidth)
        )
    }

    static func preferredWindowWidth(forScreenWidth screenWidth: CGFloat) -> CGFloat {
        let fullscreenLayout = layout(for: screenWidth)
        let compactWidth = fullscreenLayout.contentWidth + viewHorizontalPadding * 2
        return min(screenWidth * 0.92, max(compactWidth, 480))
    }

    static func measureAllEntries() -> [String: HelpCheatSheetEntryMetrics] {
        var metrics: [String: HelpCheatSheetEntryMetrics] = [:]
        for section in HelpCheatSheetContent.sections {
            for entryID in section.entries {
                metrics[entryID] = measureEntry(entryID)
            }
        }
        return metrics
    }

    private static func measureEntry(_ entryID: String) -> HelpCheatSheetEntryMetrics {
        let shortcut = L10n.Help.entryShortcut(entryID)
        let shortcutText = shortcut.isEmpty ? L10n.Help.noShortcut : shortcut
        return HelpCheatSheetEntryMetrics(
            entryID: entryID,
            nameWidth: ceil(measure(L10n.Help.entryName(entryID), font: nameFont)),
            descriptionWidth: ceil(measure(L10n.Help.entryDescription(entryID), font: descriptionFont)),
            shortcutWidth: ceil(measure(shortcutText, font: shortcutFont))
        )
    }

    private static func buildColumns(
        columnCount: Int,
        entryMetrics: [String: HelpCheatSheetEntryMetrics]
    ) -> [HelpCheatSheetColumnLayout] {
        let groups = distributeSections(HelpCheatSheetContent.sections, columnCount: columnCount)
        return groups.enumerated().map { index, sections in
            let entries = sections.flatMap(\.entries)
            let columnMetrics = entries.compactMap { entryMetrics[$0] }
            return HelpCheatSheetColumnLayout(
                id: index,
                sections: sections,
                nameWidth: columnMetrics.map(\.nameWidth).max() ?? 0,
                descriptionWidth: columnMetrics.map(\.descriptionWidth).max() ?? 0,
                shortcutWidth: columnMetrics.map(\.shortcutWidth).max() ?? 0
            )
        }
    }

    private static func distributeSections(
        _ sections: [HelpCheatSheetSection],
        columnCount: Int
    ) -> [[HelpCheatSheetSection]] {
        guard columnCount > 1 else { return [sections] }

        var columns = Array(repeating: [HelpCheatSheetSection](), count: columnCount)
        var entryCounts = Array(repeating: 0, count: columnCount)

        for section in sections {
            let targetIndex = entryCounts.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[targetIndex].append(section)
            entryCounts[targetIndex] += section.entries.count
        }

        return columns
    }

    private static func totalWidth(for columns: [HelpCheatSheetColumnLayout]) -> CGFloat {
        guard !columns.isEmpty else { return 0 }
        let columnsWidth = columns.reduce(0) { $0 + $1.width }
        let gaps = columnGap * CGFloat(max(columns.count - 1, 0))
        return columnsWidth + gaps
    }

    private static func expandColumns(
        _ columns: [HelpCheatSheetColumnLayout],
        toTotalWidth targetWidth: CGFloat
    ) -> [HelpCheatSheetColumnLayout] {
        let minTotal = totalWidth(for: columns)
        guard minTotal < targetWidth, !columns.isEmpty else { return columns }

        let extra = targetWidth - minTotal
        let perColumnExtra = extra / CGFloat(columns.count)

        return columns.map { column in
            let subMinTotal = column.nameWidth + column.descriptionWidth + column.shortcutWidth
            guard subMinTotal > 0 else { return column }

            let nameRatio = column.nameWidth / subMinTotal
            let descriptionRatio = column.descriptionWidth / subMinTotal
            let shortcutRatio = column.shortcutWidth / subMinTotal

            return HelpCheatSheetColumnLayout(
                id: column.id,
                sections: column.sections,
                nameWidth: column.nameWidth + perColumnExtra * nameRatio,
                descriptionWidth: column.descriptionWidth + perColumnExtra * descriptionRatio,
                shortcutWidth: column.shortcutWidth + perColumnExtra * shortcutRatio
            )
        }
    }

    private static func measure(_ text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
}
