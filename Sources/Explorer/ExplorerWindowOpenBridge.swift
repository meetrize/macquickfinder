import SwiftUI

/// 保存 SwiftUI `openWindow` 闭包，供 AppDelegate / 标签栏等非 View 上下文新建标签页。
@MainActor
final class ExplorerWindowOpenBridge {
    static let shared = ExplorerWindowOpenBridge()

    var openFolderWindow: ((ExplorerFolderWindowValue) -> Void)?
    var openMainWindow: (() -> Void)?
    var openPreviewWindow: ((PreviewWindowValue) -> Void)?

    private init() {}
}
