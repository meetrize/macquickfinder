import AppKit

/// 破坏性 Snippet 等操作的 AppKit 确认对话框（与 SwiftUI `.alert` 路径文案一致）。
enum DestructiveActionConfirmer {
    static func confirmDestructiveSnippet(
        title: String = "危险命令确认",
        message: String = "此 Snippet 可能删除或移动文件，确定执行？"
    ) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "取消")
        alert.addButton(withTitle: "仍要执行")
        return alert.runModal() == .alertSecondButtonReturn
    }
}
