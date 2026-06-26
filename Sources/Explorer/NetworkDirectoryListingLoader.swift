import Darwin
import Foundation

/// 网络卷快速列目录：用 `readdir` + `d_type` 避免 URL 批量预取属性（SMB 上极慢）。
enum NetworkDirectoryListingLoader {
    static func loadFileItems(
        at path: String,
        showHiddenFiles: Bool,
        onEachURL: ((URL) throws -> Void)? = nil
    ) throws -> [FileItem] {
        guard let directory = opendir(path) else {
            throw CocoaError(.fileReadUnknown)
        }
        defer { closedir(directory) }

        var items: [FileItem] = []
        items.reserveCapacity(64)

        while let entry = readdir(directory) {
            let name = entryFileName(entry)
            if name == "." || name == ".." { continue }
            if !showHiddenFiles && name.hasPrefix(".") { continue }

            let fullPath = (path as NSString).appendingPathComponent(name)
            let fileURL = URL(fileURLWithPath: fullPath)
            try onEachURL?(fileURL)

            let isDirectory: Bool = autoreleasepool {
                isDirectoryEntry(entry, fullPath: fullPath)
            }
            items.append(
                makePlaceholderItem(
                    url: fileURL,
                    name: name,
                    isDirectory: isDirectory
                )
            )
        }

        return items
    }

    /// 后台补全大小与修改时间（`stat`，不经过 URL 资源预取）。
    static func enrichWithStat(_ items: [FileItem]) -> [FileItem] {
        items.map { item in
            enrichItemWithStat(item)
        }
    }

    private static func enrichItemWithStat(_ item: FileItem) -> FileItem {
        var status = stat()
        guard stat(item.url.path, &status) == 0 else { return item }

        let isDirectory = (status.st_mode & S_IFMT) == S_IFDIR
        let fileSize = isDirectory ? Int64(0) : Int64(status.st_size)
        let modificationDate = Date(
            timeIntervalSince1970: TimeInterval(status.st_mtimespec.tv_sec)
        )

        return FileItem(
            id: item.id,
            url: item.url,
            name: item.name,
            isDirectory: isDirectory,
            modificationDate: modificationDate,
            creationDate: modificationDate,
            size: fileSize,
            isHidden: item.isHidden,
            fileType: FileItem.fileType(for: item.name, isDirectory: isDirectory),
            sizeDisplay: isDirectory ? "--" : FileItemFormatters.formatSize(fileSize),
            dateDisplay: FileItemFormatters.formatDate(modificationDate),
            creationDateDisplay: FileItemFormatters.formatDate(modificationDate),
            finderComment: item.finderComment,
            tags: item.tags
        )
    }

    private static func makePlaceholderItem(
        url: URL,
        name: String,
        isDirectory: Bool
    ) -> FileItem {
        FileItem(
            id: url.path,
            url: url,
            name: name,
            isDirectory: isDirectory,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: name.hasPrefix("."),
            fileType: FileItem.fileType(for: name, isDirectory: isDirectory),
            sizeDisplay: "--",
            dateDisplay: "--",
            creationDateDisplay: "--",
            finderComment: "",
            tags: []
        )
    }

    private static func entryFileName(_ entry: UnsafePointer<dirent>) -> String {
        withUnsafePointer(to: entry.pointee.d_name) { namePointer in
            namePointer.withMemoryRebound(to: CChar.self, capacity: Int(NAME_MAX)) {
                String(cString: $0)
            }
        }
    }

    private static func isDirectoryEntry(_ entry: UnsafePointer<dirent>, fullPath: String) -> Bool {
        switch entry.pointee.d_type {
        case UInt8(DT_DIR):
            return true
        case UInt8(DT_REG), UInt8(DT_LNK), UInt8(DT_FIFO), UInt8(DT_SOCK), UInt8(DT_CHR), UInt8(DT_BLK):
            return false
        default:
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDirectory) else {
                return false
            }
            return isDirectory.boolValue
        }
    }
}
