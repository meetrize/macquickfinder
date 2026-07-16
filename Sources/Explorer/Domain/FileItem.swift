import Foundation
import CoreServices
import Darwin
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
    let creationDate: Date
    let size: Int64
    let isHidden: Bool
    let fileType: String
    let sizeDisplay: String
    let dateDisplay: String
    let creationDateDisplay: String
    let finderComment: String
    let tags: [String]
    
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
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "",
            sizeDisplay: "",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func withFinderComment(_ comment: String) -> FileItem {
        FileItem(
            id: id,
            url: url,
            name: name,
            isDirectory: isDirectory,
            modificationDate: modificationDate,
            creationDate: creationDate,
            size: size,
            isHidden: isHidden,
            fileType: fileType,
            sizeDisplay: sizeDisplay,
            dateDisplay: dateDisplay,
            creationDateDisplay: creationDateDisplay,
            finderComment: comment,
            tags: tags
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
        let options = DirectoryListingOptions.forPath(standardized)
        let keys = DirectoryListingLoader.propertyKeys(lightweight: options.lightweightMetadata)
        let prefetchedValues = try? url.resourceValues(forKeys: keys)
        return TrashLoader.fileItem(
            from: url,
            propertyKeys: keys,
            prefetchedValues: prefetchedValues,
            skipExtendedMetadata: options.lightweightMetadata
        )
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }

    static func finderComment(for url: URL) -> String {
        if let item = MDItemCreate(nil, url.path as CFString),
           let value = MDItemCopyAttribute(item, kMDItemFinderComment as CFString) {
            if let comment = value as? String, !comment.isEmpty {
                return comment
            }
            if let comments = value as? [String], !comments.isEmpty {
                return comments.joined(separator: "\n")
            }
        }

        // 回退：直接读取 Finder 注释 xattr，规避 Spotlight 未命中/未刷新场景。
        let xattrName = "com.apple.metadata:kMDItemFinderComment"
        let path = url.path
        let length = getxattr(path, xattrName, nil, 0, 0, 0)
        guard length > 0 else { return "" }

        var bytes = [UInt8](repeating: 0, count: length)
        let readLength = getxattr(path, xattrName, &bytes, length, 0, 0)
        guard readLength > 0 else { return "" }

        let data = Data(bytes.prefix(readLength))
        guard let object = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) else {
            return ""
        }

        if let comment = object as? String {
            return comment
        }
        if let comments = object as? [String] {
            return comments.joined(separator: "\n")
        }

        return ""
    }
}
