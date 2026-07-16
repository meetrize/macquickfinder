import Foundation

/// 目录列举选项；网络卷启用轻量模式以减少 SMB 往返。
struct DirectoryListingOptions: Sendable {
    var lightweightMetadata: Bool

    init(lightweightMetadata: Bool = false) {
        self.lightweightMetadata = lightweightMetadata
    }

    static func forPath(_ path: String) -> DirectoryListingOptions {
        DirectoryListingOptions(
            lightweightMetadata: DirectorySizeVolumeFilter.isNetworkVolume(path: path)
        )
    }
}

/// 统一的目录枚举与 `FileItem` 映射，供主列表、文件夹预览等复用。
enum DirectoryListingLoader {
    static let propertyKeys: Set<URLResourceKey> = propertyKeys(lightweight: false)

    static func propertyKeys(lightweight: Bool) -> Set<URLResourceKey> {
        var keys: Set<URLResourceKey> = [
            .isDirectoryKey,
            .contentModificationDateKey,
            .fileSizeKey,
            .isHiddenKey,
        ]
        if !lightweight {
            keys.insert(.creationDateKey)
            keys.insert(.tagNamesKey)
        }
        return keys
    }

    static func enumerationOptions(showHiddenFiles: Bool) -> FileManager.DirectoryEnumerationOptions {
        showHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]
    }

    static func contentsOfDirectory(
        at path: String,
        showHiddenFiles: Bool,
        options: DirectoryListingOptions = DirectoryListingOptions()
    ) throws -> [URL] {
        let keys = propertyKeys(lightweight: options.lightweightMetadata)
        return try FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: Array(keys),
            options: enumerationOptions(showHiddenFiles: showHiddenFiles)
        )
    }

    static func loadFileItems(
        at path: String,
        showHiddenFiles: Bool,
        options: DirectoryListingOptions = DirectoryListingOptions(),
        onEachURL: ((URL) throws -> Void)? = nil
    ) throws -> [FileItem] {
        if options.lightweightMetadata {
            return try NetworkDirectoryListingLoader.loadFileItems(
                at: path,
                showHiddenFiles: showHiddenFiles,
                onEachURL: onEachURL
            )
        }

        let keys = propertyKeys(lightweight: false)
        let urls = try contentsOfDirectory(
            at: path,
            showHiddenFiles: showHiddenFiles,
            options: options
        )
        var items: [FileItem] = []
        items.reserveCapacity(urls.count)
        for fileURL in urls {
            try onEachURL?(fileURL)
            let prefetchedValues = try? fileURL.resourceValues(forKeys: keys)
            // 列举热路径不读 Finder 注释（MDItem/xattr）；注释列可见时再后台补齐。
            guard let item = TrashLoader.fileItem(
                from: fileURL,
                propertyKeys: keys,
                prefetchedValues: prefetchedValues,
                skipExtendedMetadata: false,
                includeFinderComment: false
            ) else {
                continue
            }
            items.append(item)
        }
        return items
    }
}
