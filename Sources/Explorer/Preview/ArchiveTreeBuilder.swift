import Foundation

struct ArchiveTreeNode: Identifiable, Equatable {
    let name: String
    let fullPath: String
    let isDirectory: Bool
    let size: Int64?
    let children: [ArchiveTreeNode]

    var id: String { fullPath }
}

struct ArchiveFlatRow: Identifiable, Equatable {
    let node: ArchiveTreeNode
    let depth: Int
    let hasChildren: Bool
    let isExpanded: Bool

    var id: String { node.id }
}

enum ArchiveTreeBuilder {
    private final class MutableNode {
        let name: String
        var isDirectory: Bool
        var size: Int64?
        var children: [String: MutableNode] = [:]

        init(name: String, isDirectory: Bool, size: Int64?) {
            self.name = name
            self.isDirectory = isDirectory
            self.size = size
        }
    }

    static func build(from entries: [ArchiveEntryPreview]) -> [ArchiveTreeNode] {
        let root = MutableNode(name: "", isDirectory: true, size: nil)
        for entry in entries {
            insert(entry: entry, into: root)
        }
        return finalize(root.children)
    }

    static func visibleRows(
        roots: [ArchiveTreeNode],
        expandedDirectoryPaths: Set<String>
    ) -> [ArchiveFlatRow] {
        flatten(nodes: roots, depth: 0, expandedDirectoryPaths: expandedDirectoryPaths)
    }

    private static func insert(entry: ArchiveEntryPreview, into root: MutableNode) {
        var trimmed = entry.path
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        guard !trimmed.isEmpty else { return }

        let components = trimmed.split(separator: "/").map(String.init)
        var current = root
        for (index, component) in components.enumerated() {
            let isLast = index == components.count - 1
            if current.children[component] == nil {
                current.children[component] = MutableNode(
                    name: component,
                    isDirectory: !isLast || entry.isDirectory || entry.path.hasSuffix("/"),
                    size: nil
                )
            }
            let node = current.children[component]!
            if isLast {
                node.isDirectory = node.isDirectory || entry.isDirectory || entry.path.hasSuffix("/")
                if !node.isDirectory {
                    node.size = entry.size
                }
            } else {
                node.isDirectory = true
            }
            current = node
        }
    }

    private static func finalize(_ children: [String: MutableNode]) -> [ArchiveTreeNode] {
        children.values
            .sorted(by: sortNodes)
            .map { node in
                ArchiveTreeNode(
                    name: node.name,
                    fullPath: node.name,
                    isDirectory: node.isDirectory,
                    size: node.size,
                    children: finalizeWithPrefix(node.children, parentPath: node.name)
                )
            }
    }

    private static func finalizeWithPrefix(
        _ children: [String: MutableNode],
        parentPath: String
    ) -> [ArchiveTreeNode] {
        children.values
            .sorted(by: sortNodes)
            .map { node in
                let fullPath = "\(parentPath)/\(node.name)"
                return ArchiveTreeNode(
                    name: node.name,
                    fullPath: fullPath,
                    isDirectory: node.isDirectory,
                    size: node.size,
                    children: finalizeWithPrefix(node.children, parentPath: fullPath)
                )
            }
    }

    private static func sortNodes(_ lhs: MutableNode, _ rhs: MutableNode) -> Bool {
        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private static func flatten(
        nodes: [ArchiveTreeNode],
        depth: Int,
        expandedDirectoryPaths: Set<String>
    ) -> [ArchiveFlatRow] {
        var rows: [ArchiveFlatRow] = []
        for node in nodes {
            let hasChildren = node.isDirectory && !node.children.isEmpty
            let isExpanded = expandedDirectoryPaths.contains(node.fullPath)
            rows.append(
                ArchiveFlatRow(
                    node: node,
                    depth: depth,
                    hasChildren: hasChildren,
                    isExpanded: isExpanded
                )
            )
            if hasChildren, isExpanded {
                rows.append(
                    contentsOf: flatten(
                        nodes: node.children,
                        depth: depth + 1,
                        expandedDirectoryPaths: expandedDirectoryPaths
                    )
                )
            }
        }
        return rows
    }
}
