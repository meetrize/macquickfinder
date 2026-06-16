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
    
    private static func compare(_ lhs: FileListRow, _ rhs: FileListRow, column: FileListColumnID) -> Bool {
        switch column {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        case .type:
            return lhs.fileType.localizedStandardCompare(rhs.fileType) == .orderedAscending
        case .size:
            return lhs.size < rhs.size
        case .dateModified:
            return lhs.modificationDate < rhs.modificationDate
        }
    }
}
