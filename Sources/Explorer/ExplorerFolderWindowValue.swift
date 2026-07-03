import Foundation

/// 文件夹窗口 `WindowGroup(for:)` 的参数。
/// `instanceID` 保证每次 `openWindow` 都能创建新实例（SwiftUI 按整值去重，仅用路径会无法新建第三及以后标签）。
struct ExplorerFolderWindowValue: Hashable, Codable, Sendable {
    let path: String
    let selectionPath: String?
    let instanceID: UUID

    init(path: String, selectionPath: String? = nil, instanceID: UUID = UUID()) {
        self.path = path
        self.selectionPath = selectionPath
        self.instanceID = instanceID
    }
}
