import Foundation
import FileList

enum SortOrder: String, CaseIterable, Identifiable {
    case nameAscending = "Name (A to Z)"
    case nameDescending = "Name (Z to A)"
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case sizeSmallest = "Size (Smallest First)"
    case sizeLargest = "Size (Largest First)"
    
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .nameAscending: return L10n.Sort.nameAscending
        case .nameDescending: return L10n.Sort.nameDescending
        case .dateNewest: return L10n.Sort.dateNewest
        case .dateOldest: return L10n.Sort.dateOldest
        case .sizeSmallest: return L10n.Sort.sizeSmallest
        case .sizeLargest: return L10n.Sort.sizeLargest
        }
    }
}

enum FileItemFormatters {
    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static func formatSize(_ bytes: Int64) -> String {
        sizeFormatter.string(fromByteCount: bytes)
    }
    
    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

struct FileItem: Identifiable, Hashable {
    static let parentDirectoryID = "__parent_directory__"
    
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let modificationDate: Date
    let size: Int64
    let isHidden: Bool
    let fileType: String
    let sizeDisplay: String
    let dateDisplay: String
    
    var isParentDirectoryEntry: Bool {
        id == Self.parentDirectoryID
    }
    
    static func parentDirectoryEntry() -> FileItem {
        FileItem(
            id: parentDirectoryID,
            url: URL(fileURLWithPath: "/"),
            name: "..",
            isDirectory: true,
            modificationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "",
            sizeDisplay: "",
            dateDisplay: ""
        )
    }
    
    static func fileType(for name: String, isDirectory: Bool) -> String {
        if isDirectory {
            return "文件夹"
        }
        return (name as NSString).pathExtension
    }
    
    static func canNavigateUp(from path: String) -> Bool {
        parentDirectoryURL(from: path) != nil
    }
    
    static func parentDirectoryURL(from path: String) -> URL? {
        if TrashLoader.isTrashPath(path) {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent()
        guard parent.path != url.path else { return nil }
        return parent
    }
    
    /// 先用当前列表命中，再回查文件系统，保证树展开后选中的子目录文件可被预览/作用域识别。
    static func resolveSelection(
        ids: Set<String>,
        from knownItems: [FileItem]
    ) -> [FileItem] {
        guard !ids.isEmpty else { return [] }
        let knownByID = Dictionary(uniqueKeysWithValues: knownItems.map { ($0.id, $0) })
        var resolved: [FileItem] = []
        resolved.reserveCapacity(ids.count)
        
        for id in ids {
            if let known = knownByID[id] {
                resolved.append(known)
                continue
            }
            guard id != parentDirectoryID else { continue }
            if let lookedUp = itemFromFileSystem(path: id) {
                resolved.append(lookedUp)
            }
        }
        return resolved
    }
    
    private static func itemFromFileSystem(path: String) -> FileItem? {
        let standardized = (path as NSString).standardizingPath
        let url = URL(fileURLWithPath: standardized)
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
        ]
        
        do {
            let values = try url.resourceValues(forKeys: keys)
            guard let isDirectory = values.isDirectory else { return nil }
            let modificationDate = values.contentModificationDate ?? .distantPast
            let fileSize = Int64(values.fileSize ?? 0)
            let isHidden = values.isHidden ?? false
            let name = url.lastPathComponent
            let sizeDisplay = isDirectory ? "--" : FileItemFormatters.formatSize(fileSize)
            return FileItem(
                id: standardized,
                url: url,
                name: name,
                isDirectory: isDirectory,
                modificationDate: modificationDate,
                size: fileSize,
                isHidden: isHidden,
                fileType: fileType(for: name, isDirectory: isDirectory),
                sizeDisplay: sizeDisplay,
                dateDisplay: FileItemFormatters.formatDate(modificationDate)
            )
        } catch {
            return nil
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}
