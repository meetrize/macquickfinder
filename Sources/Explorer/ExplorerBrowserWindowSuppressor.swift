import AppKit
import SwiftUI

/// 图片专用外部打开时，阻止 SwiftUI 自动弹出的主/文件夹浏览窗停留。
struct ExplorerBrowserWindowSuppressor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard ExternalImagePreviewOpenCenter.shared.shouldSuppressExplorerWindows else { return }
            view.window?.close()
            ExternalImagePreviewOpenCenter.shared.clearSuppressExplorerWindows()
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard ExternalImagePreviewOpenCenter.shared.shouldSuppressExplorerWindows else { return }
            nsView.window?.close()
            ExternalImagePreviewOpenCenter.shared.clearSuppressExplorerWindows()
        }
    }
}
