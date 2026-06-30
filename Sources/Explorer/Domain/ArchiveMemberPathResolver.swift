import Foundation

enum ArchiveMemberPathResolver {
    /// 将预览列表中的选中项展开为归档内实际成员路径（含目录下全部子项）。
    static func resolveMemberPaths(
        selectedPaths: Set<String>,
        allEntries: [ArchiveEntryPreview]
    ) -> [String] {
        guard !selectedPaths.isEmpty else { return [] }

        var members = Set<String>()
        for selected in selectedPaths {
            members.formUnion(pathsForSelection(selected, allEntries: allEntries))
        }
        return members.sorted()
    }

    private static func pathsForSelection(
        _ selected: String,
        allEntries: [ArchiveEntryPreview]
    ) -> Set<String> {
        let normalized = selected.hasSuffix("/") ? String(selected.dropLast()) : selected
        let prefix = normalized + "/"

        if selected.hasSuffix("/") {
            var result = Set(allEntries.map(\.path).filter { $0.hasPrefix(prefix) || $0 == normalized || $0 == selected })
            result.insert(normalized)
            result.insert(selected)
            return result
        }

        if allEntries.contains(where: { $0.path == selected }) {
            return [selected]
        }

        var result = Set(allEntries.map(\.path).filter { $0 == selected || $0.hasPrefix(prefix) })
        if result.isEmpty {
            result.insert(selected)
        }
        return result
    }
}
