import AppKit
import Foundation

public extension Notification.Name {
    /// 文件列表内开始框选、拖放文件等内容区指针交互
    static let mf_contentPointerInteractionDidBegin = Notification.Name("mf.contentPointerInteractionDidBegin")
    /// 文件列表内结束框选、拖放文件等内容区指针交互
    static let mf_contentPointerInteractionDidEnd = Notification.Name("mf.contentPointerInteractionDidEnd")
}

public enum FileListContentInteractionNotifier {
    public static func notifyDidBegin() {
        NotificationCenter.default.post(name: .mf_contentPointerInteractionDidBegin, object: nil)
    }

    public static func notifyDidEnd() {
        NotificationCenter.default.post(name: .mf_contentPointerInteractionDidEnd, object: nil)
    }

    /// 当前是否存在应用内文件拖放（读 drag pasteboard）
    public static var hasActiveFileDrag: Bool {
        !FileListDragSupport.fileURLs(from: NSPasteboard(name: .drag)).isEmpty
    }
}
