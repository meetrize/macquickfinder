import SwiftUI

enum ToolbarMainGroup: Int, CaseIterable {
    case fileActions
    case windowTabs
    case panels
    case viewModes
    case utilities
    case customApps

    static func index(for entry: ToolbarVisibleEntry) -> Int? {
        switch entry.kind {
        case .openApp:
            return ToolbarMainGroup.customApps.rawValue
        case .builtin:
            guard let builtin = ToolbarBuiltinID(rawValue: entry.id) else { return nil }
            return Self.index(for: builtin)
        }
    }

    static func index(for builtin: ToolbarBuiltinID) -> Int? {
        switch builtin {
        case .newFile, .newFolder, .delete:
            return ToolbarMainGroup.fileActions.rawValue
        case .newWindow, .newTab, .showAllTabs, .toggleTabBar:
            return ToolbarMainGroup.windowTabs.rawValue
        case .preview, .snippets, .git, .outputPanel:
            return ToolbarMainGroup.panels.rawValue
        case .listView, .thumbnailView, .panoramaView:
            return ToolbarMainGroup.viewModes.rawValue
        case .recordOperations, .toggleHiddenFiles, .sortMenu, .browseSettingsMenu:
            return ToolbarMainGroup.utilities.rawValue
        case .leftPanel, .thumbnailSizeSlider:
            return nil
        }
    }

    static func groupedEntries(_ entries: [ToolbarVisibleEntry]) -> [[ToolbarVisibleEntry]] {
        var buckets = Array(repeating: [(originalIndex: Int, entry: ToolbarVisibleEntry)](), count: ToolbarMainGroup.allCases.count)
        for (originalIndex, entry) in entries.enumerated() {
            guard let bucketIndex = Self.index(for: entry) else { continue }
            buckets[bucketIndex].append((originalIndex, entry))
        }
        return buckets.compactMap { bucket in
            guard !bucket.isEmpty else { return nil }
            return bucket
                .sorted { lhs, rhs in
                    let leftRank = sortRank(for: lhs.entry)
                    let rightRank = sortRank(for: rhs.entry)
                    if leftRank != rightRank { return leftRank < rightRank }
                    return lhs.originalIndex < rhs.originalIndex
                }
                .map(\.entry)
        }
    }

    private static let canonicalBuiltinOrder: [ToolbarBuiltinID] = [
        .newFile,
        .newFolder,
        .delete,
        .newWindow,
        .newTab,
        .showAllTabs,
        .toggleTabBar,
        .preview,
        .snippets,
        .git,
        .outputPanel,
        .listView,
        .thumbnailView,
        .panoramaView,
        .recordOperations,
        .toggleHiddenFiles,
        .sortMenu,
        .browseSettingsMenu,
    ]

    static func sortedEntries(_ entries: [ToolbarVisibleEntry]) -> [ToolbarVisibleEntry] {
        entries
            .enumerated()
            .sorted { lhs, rhs in
                let leftRank = sortRank(for: lhs.element)
                let rightRank = sortRank(for: rhs.element)
                if leftRank != rightRank { return leftRank < rightRank }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    private static func sortRank(for entry: ToolbarVisibleEntry) -> Int {
        switch entry.kind {
        case .openApp:
            return canonicalBuiltinOrder.count
        case .builtin:
            guard let builtin = ToolbarBuiltinID(rawValue: entry.id),
                  let index = canonicalBuiltinOrder.firstIndex(of: builtin) else {
                return Int.max
            }
            return index
        }
    }
}

struct ToolbarGroupDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: 1, height: ExplorerToolbarMetrics.iconHitSize - 4)
    }
}
