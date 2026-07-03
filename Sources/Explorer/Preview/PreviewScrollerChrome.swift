import AppKit

/// 内嵌右侧面板中的 NSScrollView 边界配置，避免 overlay 滚动条绘制到相邻面板。
enum PreviewScrollerChrome {
    static func applyPanelSafeBounds(to scrollView: NSScrollView) {
        scrollView.clipsToBounds = true
        scrollView.scrollerStyle = .legacy
    }
}
