import Foundation

/// 子目录全景的收起状态：默认全部展开（集合为空）。
struct PanoramaTreeCollapseState: Equatable, Sendable {
    private(set) var collapsedDirectoryIDs: Set<String> = []

    var isEmpty: Bool { collapsedDirectoryIDs.isEmpty }

    func isExpanded(_ directoryID: String) -> Bool {
        !collapsedDirectoryIDs.contains(directoryID)
    }

    mutating func clear() {
        collapsedDirectoryIDs.removeAll(keepingCapacity: true)
    }

    mutating func collapse(_ directoryID: String) {
        collapsedDirectoryIDs.insert(directoryID)
    }

    mutating func expand(_ directoryID: String) {
        collapsedDirectoryIDs.remove(directoryID)
    }

    mutating func expandAll() {
        clear()
    }

    mutating func collapseAll(directoryIDs: some Sequence<String>) {
        collapsedDirectoryIDs = Set(directoryIDs)
    }

    /// 收起某目录时，仅标记该节点；子树 UI 由 DisplayBuilder 根据祖先是否收起截断。
    func isSubtreeVisible(for directoryID: String, ancestorIDs: [String]) -> Bool {
        guard isExpanded(directoryID) else { return false }
        return ancestorIDs.allSatisfy(isExpanded)
    }
}
