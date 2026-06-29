import Foundation

enum ArchiveMemberPathResolver {
    /// 将预览列表中的选中项展开为归档内实际成员路径（含目录下全部子项）。
    static func resolveMemberPaths(
        selectedPaths: Set<String>,
        allEntries: [ArchiveEntryPreview],
        expanded: Bool
    ) -> [String] {
        guard !selectedPaths.isEmpty else { return [] }

        var members = Set<String>()
        for selected in selectedPaths {
            members.formUnion(pathsForSelection(selected, allEntries: allEntries, expanded: expanded))
        }
        return members.sorted()
    }

    private static func pathsForSelection(
        _ selected: String,
        allEntries: [ArchiveEntryPreview],
        expanded: Bool
    ) -> Set<String> {
        if expanded {
            return pathsForExpandedSelection(selected, allEntries: allEntries)
        }
        return pathsForCollapsedSelection(selected, allEntries: allEntries)
    }

    private static func pathsForExpandedSelection(
        _ selected: String,
        allEntries: [ArchiveEntryPreview]
    ) -> Set<String> {
        guard let entry = allEntries.first(where: { $0.path == selected }) else {
            return [selected]
        }

        if entry.isDirectory || selected.hasSuffix("/") {
            let normalized = selected.hasSuffix("/") ? String(selected.dropLast()) : selected
            let prefix = normalized + "/"
            var result = Set(allEntries.map(\.path).filter { $0.hasPrefix(prefix) })
            result.insert(normalized)
            if selected.hasSuffix("/") {
                result.insert(selected)
            }
            return result
        }

        return [selected]
    }

    private static func pathsForCollapsedSelection(
        _ selected: String,
        allEntries: [ArchiveEntryPreview]
    ) -> Set<String> {
        let prefix = selected + "/"
        var result = Set(
            allEntries.map(\.path).filter { $0 == selected || $0.hasPrefix(prefix) }
        )
        if result.isEmpty {
            result.insert(selected)
        }
        return result
    }
}
