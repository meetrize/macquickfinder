import Foundation

enum FolderPreviewLoader {
    static let maxChildren = 200

    struct LoadResult: Equatable {
        let children: [FileItem]
        let truncated: Bool
        let errorMessage: String?
    }

    static func load(at path: String, showHiddenFiles: Bool) async -> LoadResult {
        let options = DirectoryListingOptions.forPath(path)
        return await Task.detached(priority: .userInitiated) {
            do {
                let items = try DirectoryListingLoader.loadFileItems(
                    at: path,
                    showHiddenFiles: showHiddenFiles,
                    options: options
                )
                let sorted = sortChildren(items)
                let totalCount = sorted.count
                let truncated = totalCount > maxChildren
                let displayed = truncated ? Array(sorted.prefix(maxChildren)) : sorted

                return LoadResult(
                    children: displayed,
                    truncated: truncated,
                    errorMessage: nil
                )
            } catch {
                return LoadResult(
                    children: [],
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
