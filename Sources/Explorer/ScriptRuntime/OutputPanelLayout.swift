import AppKit
import SwiftUI

extension OutputPanelMetrics {
    static let resizeHandleHeight: CGFloat = 2
    /// 拖拽条视觉高度仅 2pt，命中区向外扩展以便抓取。
    static let resizeHandleHitHeight: CGFloat = 14
    /// 命令行 + 查找等底部控件的最小高度（含 Divider 与内边距）。
    static let bottomBarHeight: CGFloat = 44
    /// 输出面板展开时，主内容区（文件列表 + 预览）保留的最小高度。
    static let minimumMainContentHeight: CGFloat = 120

    static var minimumExpandedChromeHeight: CGFloat {
        titleBarHeight + bottomBarHeight
    }

    static func maxPanelHeight(forContainerHeight containerHeight: CGFloat) -> CGFloat {
        let reservedForMain = minimumMainContentHeight
        let available = max(0, containerHeight - reservedForMain)
        let ratioCap = containerHeight * 0.92
        return max(minimumExpandedChromeHeight, min(ratioCap, available))
    }

    /// 根据窗口可用高度夹紧面板内容高度；缩窗时为主内容区保留最小高度。
    static func clampedPanelHeight(
        desired: CGFloat,
        containerHeight: CGFloat,
        isContentCollapsed: Bool
    ) -> CGFloat {
        if isContentCollapsed {
            return titleBarHeight
        }
        let maxPanel = max(
            minimumExpandedChromeHeight,
            containerHeight - minimumMainContentHeight
        )
        return min(max(desired, minimumExpandedChromeHeight), maxPanel)
    }
}
