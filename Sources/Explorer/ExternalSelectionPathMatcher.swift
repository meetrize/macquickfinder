import FileList
import Foundation

enum ExternalSelectionPathMatcher {
    static func standardizedPath(_ path: String) -> String {
        let standardized = (path as NSString).standardizingPath
        // APFS/HFS 上非 ASCII 文件名常为 NFD；统一 NFC 再比。
        return standardized.precomposedStringWithCanonicalMapping
    }

    static func matchingItem(in items: [FileItem], selectionPath: String) -> FileItem? {
        let standardized = standardizedPath(selectionPath)
        let canonical = DirectoryListingPathNormalization.canonicalPath(selectionPath)
            .precomposedStringWithCanonicalMapping

        if let exact = items.first(where: { standardizedPath($0.id) == standardized }) {
            return exact
        }
        if let byCanonical = items.first(where: {
            DirectoryListingPathNormalization.canonicalPath($0.id)
                .precomposedStringWithCanonicalMapping == canonical
        }) {
            return byCanonical
        }

        let targetName = (standardized as NSString).lastPathComponent
            .precomposedStringWithCanonicalMapping
            .lowercased()
        guard !targetName.isEmpty else { return nil }
        return items.first {
            $0.name.precomposedStringWithCanonicalMapping.lowercased() == targetName
                || ($0.id as NSString).lastPathComponent
                    .precomposedStringWithCanonicalMapping
                    .lowercased() == targetName
        }
    }
}
