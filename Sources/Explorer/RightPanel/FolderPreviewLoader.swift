import Foundation

enum FolderPreviewLoader {
    static let maxChildren = 200

    struct LoadResult: Equatable {
        let children: [FileItem]
        let totalCount: Int
        let truncated: Bool
        let errorMessage: String?
    }

    static func load(at path: String, showHiddenFiles: Bool) async -> LoadResult {
        await Task.detached(priority: .userInitiated) {
            let propertyKeys: Set<URLResourceKey> = [
                .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
            ]
            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles
                ? [.skipsPackageDescendants]
                : [.skipsHiddenFiles, .skipsPackageDescendants]
            let url = URL(fileURLWithPath: path)

            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(propertyKeys),
                    options: options
                )

                var items: [FileItem] = []
                items.reserveCapacity(urls.count)
                for fileURL in urls {
                    guard let item = TrashLoader.fileItem(from: fileURL, propertyKeys: propertyKeys) else {
                        continue
                    }
                    items.append(item)
                }

                let sorted = sortChildren(items)
                let totalCount = sorted.count
                let truncated = totalCount > maxChildren
                let displayed = truncated ? Array(sorted.prefix(maxChildren)) : sorted

                return LoadResult(
                    children: displayed,
                    totalCount: totalCount,
                    truncated: truncated,
                    errorMessage: nil
                )
            } catch {
                return LoadResult(
                    children: [],
                    totalCount: 0,
                    truncated: false,
                    errorMessage: error.localizedDescription
                )
            }
        }.value
    }

    private static func sortChildren(_ items: [FileItem]) -> [FileItem] {
        items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}
