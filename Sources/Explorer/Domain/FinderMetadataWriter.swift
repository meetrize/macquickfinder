import Foundation
import Darwin

enum FinderMetadataWriter {
    private static let finderCommentXattrName = "com.apple.metadata:kMDItemFinderComment"
    private static let finderTagsXattrName = "com.apple.metadata:_kMDItemUserTags"

    static func setTags(for url: URL, tags: [String]) throws {
        let cleaned = tags
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if cleaned.isEmpty {
            url.path.withCString { pathCStr in
                finderTagsXattrName.withCString { nameCStr in
                    _ = removexattr(pathCStr, nameCStr, 0)
                }
            }
            return
        }

        // Finder tags 的 xattr 值是一个 binary plist：
        // NSArray<String>，其中每个元素是 "tagName\ncolorIndex(0-7)"。
        // 本期先把 colorIndex 统一为 0（UI 颜色由本应用自己映射）。
        let plistObject: [String] = cleaned.map { "\($0)\n0" }
        let data = try PropertyListSerialization.data(
            fromPropertyList: plistObject,
            format: .binary,
            options: 0
        )

        let writeResult = data.withUnsafeBytes { bytes in
            url.path.withCString { pathCStr in
                finderTagsXattrName.withCString { nameCStr in
                    setxattr(
                        pathCStr,
                        nameCStr,
                        bytes.baseAddress,
                        data.count,
                        0,
                        0
                    )
                }
            }
        }

        if writeResult != 0 {
            throw NSError(
                domain: "FinderMetadataWriter",
                code: Int(writeResult),
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to set Finder tags xattr."
                ]
            )
        }
    }

    static func setFinderComment(for url: URL, comment: String) throws {
        let cleaned = comment.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleaned.isEmpty {
            // 清空：移除 Finder comment 的 xattr（比写入空字符串更接近用户期望）。
            url.path.withCString { pathCStr in
                finderCommentXattrName.withCString { nameCStr in
                    _ = removexattr(pathCStr, nameCStr, 0)
                }
            }
            return
        }

        // Finder comment 的 xattr 值本质是一个 plist（可能是 String 或 [String]）。
        let plistObject: Any = cleaned
        let data = try PropertyListSerialization.data(
            fromPropertyList: plistObject,
            format: .binary,
            options: 0
        )

        let writeResult = data.withUnsafeBytes { bytes in
            url.path.withCString { pathCStr in
                finderCommentXattrName.withCString { nameCStr in
                    setxattr(
                        pathCStr,
                        nameCStr,
                        bytes.baseAddress,
                        data.count,
                        0,
                        0
                    )
                }
            }
        }

        if writeResult != 0 {
            throw NSError(
                domain: "FinderMetadataWriter",
                code: Int(writeResult),
                userInfo: [
                    NSLocalizedDescriptionKey: "Failed to set Finder comment xattr."
                ]
            )
        }
    }
}

