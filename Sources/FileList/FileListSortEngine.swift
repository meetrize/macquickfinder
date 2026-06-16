import Foundation

public enum FileListSortEngine {
    public static func sorted(_ rows: [FileListRow], by sort: FileListSortState) -> [FileListRow] {
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
