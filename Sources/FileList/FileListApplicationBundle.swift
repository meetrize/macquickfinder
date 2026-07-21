import Foundation

/// macOS 文件包识别（`.app`、`.bundle`、文档包等）；此类目录按包处理，不统计内部子项、不可加入收藏。
public enum FileListApplicationBundle {
    /// 常见包扩展名（不依赖文件系统查询的快速路径）。
    private static let knownPackageExtensions: Set<String> = [
        "app", "appex", "framework", "bundle", "plugin", "kext", "xpc",
        "qlgenerator", "saver", "mdimporter", "prefPane",
        "rtfd", "pages", "numbers", "key", "playground",
    ]

    public static func isBundle(path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if knownPackageExtensions.contains(ext) {
            return true
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        return (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true
    }

    /// 可作为侧栏收藏的普通目录（存在、为目录、且非文件包）。
    public static func isFavoriteableDirectory(path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue,
              !isBundle(path: path) else {
            return false
        }
        return true
    }
}
