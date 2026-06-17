import Foundation

public enum FileListSortEngine {
    public static func sorted(_ rows: [FileListRow], by sort: FileListSortState) -> [FileListRow] {
        if rows.contains(where: { $0.parentID != nil || $0.depth > 0 }) {
            return sortedTree(rows, by: sort)
        }
        
        var parent: FileListRow?
        var files: [FileListRow] = []
        files.reserveCapacity(rows.count)
        
        for row in rows {
            if row.isParentDirectoryEntry {
                parent = row
            } else {
                files.append(row)
            }
        }
        
        files.sort { lhs, rhs in
            if sort.column == .size {
                return compareSize(lhs.size, rhs.size, ascending: sort.ascending)
            }
            let compared = compare(lhs, rhs, column: sort.column)
            return sort.ascending ? compared : !compared
        }
        
        if let parent {
            return [parent] + files
        }
        return files
    }
    
    private static func sortedTree(_ rows: [FileListRow], by sort: FileListSortState) -> [FileListRow] {
        var parentRow: FileListRow?
        var normalRows: [FileListRow] = []
        normalRows.reserveCapacity(rows.count)
        
        for row in rows {
            if row.isParentDirectoryEntry {
                parentRow = row
            } else {
                normalRows.append(row)
            }
        }
        
        let byID = Dictionary(uniqueKeysWithValues: normalRows.map { ($0.id, $0) })
        let childrenMap = Dictionary(grouping: normalRows, by: { $0.parentID })
        
        func sortedChildren(for parentID: String?) -> [FileListRow] {
            let children = childrenMap[parentID] ?? []
            return children.sorted { lhs, rhs in
                if sort.column == .size {
                    return compareSize(lhs.size, rhs.size, ascending: sort.ascending)
                }
                let compared = compare(lhs, rhs, column: sort.column)
                return sort.ascending ? compared : !compared
            }
        }
        
        var output: [FileListRow] = []
        if let parentRow {
            output.append(parentRow)
        }
        
        func appendSubtree(parentID: String?, depth: Int) {
            for child in sortedChildren(for: parentID) {
                output.append(child)
                guard child.depth >= depth else { continue }
                if byID[child.id]?.isExpanded == true {
                    appendSubtree(parentID: child.id, depth: depth + 1)
                }
            }
        }
        
        appendSubtree(parentID: nil, depth: 0)
        return output
    }
    
    public static func defaultAscending(for column: FileListColumnID) -> Bool {
        switch column {
        case .name, .type, .size:
            return true
        case .dateModified:
            return false
        }
    }
    
    /// 未知文件夹大小用 `-1` 表示，升序/降序均排在末尾。
    private static func compareSize(_ lhs: Int64, _ rhs: Int64, ascending: Bool) -> Bool {
        let lhsUnknown = lhs < 0
        let rhsUnknown = rhs < 0
        if lhsUnknown && rhsUnknown { return false }
        if lhsUnknown { return false }
        if rhsUnknown { return true }
        return ascending ? lhs < rhs : lhs > rhs
    }
    
    private static func compare(_ lhs: FileListRow, _ rhs: FileListRow, column: FileListColumnID) -> Bool {
        switch column {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .type:
            return lhs.fileType.localizedStandardCompare(rhs.fileType) == .orderedAscending
        case .size:
            return compareSize(lhs.size, rhs.size, ascending: true)
        case .dateModified:
            return lhs.modificationDate < rhs.modificationDate
        }
    }
}
