import Foundation

/// 统一的目录枚举与 `FileItem` 映射，供主列表、文件夹预览等复用。
enum DirectoryListingLoader {
    static let propertyKeys: Set<URLResourceKey> = [
        .isDirectoryKey, .contentModificationDateKey, .creationDateKey,
        .fileSizeKey, .isHiddenKey, .tagNamesKey
    ]

    static func enumerationOptions(showHiddenFiles: Bool) -> FileManager.DirectoryEnumerationOptions {
        showHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]
    }

    static func contentsOfDirectory(
        at path: String,
        showHiddenFiles: Bool
    ) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(propertyKeys),
            options: enumerationOptions(showHiddenFiles: showHiddenFiles)
        )
    }

    static func loadFileItems(
        at path: String,
        showHiddenFiles: Bool,
        onEachURL: ((URL) throws -> Void)? = nil
    ) throws -> [FileItem] {
        let urls = try contentsOfDirectory(at: path, showHiddenFiles: showHiddenFiles)
        var items: [FileItem] = []
        items.reserveCapacity(urls.count)
        for fileURL in urls {
            try onEachURL?(fileURL)
            guard let item = TrashLoader.fileItem(from: fileURL, propertyKeys: propertyKeys) else {
                continue
            }
            items.append(item)
        }
        return items
    }
}
