import Foundation
import FileList

/// Finder 风格：浏览 `/Applications` 时合并 `/System/Applications`（Utilities 同理）。
///
/// 现代 macOS 系统自带应用在 `/System/Applications`，用户安装应用在 `/Applications`。
/// Finder 侧栏「应用程序」会合并二者；本枚举复现该行为。同名项优先保留主目录（用户侧）。
enum ApplicationsDirectoryMerge {
    private static let pairs: [(primary: String, supplemental: String)] = [
        ("/Applications", "/System/Applications"),
        ("/Applications/Utilities", "/System/Applications/Utilities"),
    ]

    /// 浏览 `path` 时应额外枚举的目录（不含 `path` 本身）。
    static func supplementalPaths(
        for path: String,
        fileExists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
    ) -> [String] {
        let canonical = DirectoryListingPathNormalization.canonicalPath(path)
        guard !canonical.isEmpty else { return [] }

        for pair in pairs {
            let primary = DirectoryListingPathNormalization.canonicalPath(pair.primary)
            guard canonical == primary else { continue }
            let supplemental = DirectoryListingPathNormalization.canonicalPath(pair.supplemental)
            guard supplemental != primary, fileExists(pair.supplemental) else { return [] }
            return [pair.supplemental]
        }
        return []
    }

    /// 按文件名去重合并；`primary` 优先于后续 supplemental 组。
    static func mergeURLs(primary: [URL], supplementalGroups: [[URL]]) -> [URL] {
        var seenNames = Set<String>()
        var result: [URL] = []
        result.reserveCapacity(primary.count + supplementalGroups.reduce(0) { $0 + $1.count })

        func appendUnique(from urls: [URL]) {
            for url in urls {
                let name = url.lastPathComponent
                guard seenNames.insert(name).inserted else { continue }
                result.append(url)
            }
        }

        appendUnique(from: primary)
        for group in supplementalGroups {
            appendUnique(from: group)
        }
        return result
    }
}
