import Foundation

/// SwiftUI `WindowGroup(id:for:)` 场景标识。
enum ExplorerWindowScene {
    static let main = "main"
    static let folder = "folder"
    static let preview = "preview"
}

/// Explorer 主窗口所属 SwiftUI 场景（新建标签须与当前窗口同场景，否则会变成独立窗口）。
enum ExplorerWindowSceneKind {
    case main
    case folder
}
