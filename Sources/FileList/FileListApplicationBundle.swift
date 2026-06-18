import Foundation

/// macOS 应用程序包（`.app`）识别；此类目录按包处理，不统计内部子项数量。
public enum FileListApplicationBundle {
    public static func isBundle(path: String) -> Bool {
        path.lowercased().hasSuffix(".app")
    }
}
