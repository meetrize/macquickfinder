import AppKit
import SwiftUI

extension OutputPanelMetrics {
    static let resizeHandleHeight: CGFloat = 2
    /// 拖拽条视觉高度仅 2pt，命中区向外扩展以便抓取。
    static let resizeHandleHitHeight: CGFloat = 14
    /// 命令行 + 查找等底部控件的最小高度（含 Divider 与内边距）。
    static let bottomBarHeight: CGFloat = 44

    static var minimumExpandedChromeHeight: CGFloat {
        titleBarHeight + bottomBarHeight
    }

    /// unified compact 工具栏大致覆盖的内容区高度。
    static let estimatedToolbarOverlap: CGFloat = 52

    static func maxPanelHeight(forContainerHeight containerHeight: CGFloat) -> CGFloat {
        max(minimumExpandedChromeHeight, containerHeight * 0.92)
    }

    /// 根据窗口可用高度夹紧面板内容高度；缩窗时优先保留底部命令区。
    static func clampedPanelHeight(
        desired: CGFloat,
        containerHeight: CGFloat,
        isContentCollapsed: Bool
    ) -> CGFloat {
        if isContentCollapsed {
            return titleBarHeight
        }
        let maxPanel = max(bottomBarHeight, containerHeight)
        return min(max(desired, bottomBarHeight), maxPanel)
    }

    static func totalOverlayHeight(
        panelHeight: CGFloat,
        isContentCollapsed: Bool
    ) -> CGFloat {
        panelHeight
    }
}

/// 将输出面板宿主视图置于窗口 contentView 最前，避免被地址栏等兄弟视图遮挡。
struct OutputPanelWindowLayerInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> InstallerView { InstallerView() }
    func updateNSView(_ nsView: InstallerView, context: Context) {
        nsView.elevatePanelHost()
    }

    final class InstallerView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            elevatePanelHost()
        }

        override func layout() {
            super.layout()
            elevatePanelHost()
        }

        fileprivate func elevatePanelHost() {
            guard let window, let contentView = window.contentView else { return }
            var host: NSView? = self
            while let superview = host?.superview, superview !== contentView {
                host = superview
            }
            guard let panelHost = host, panelHost.superview === contentView else { return }
            contentView.addSubview(panelHost, positioned: .above, relativeTo: nil)
        }
    }
}

/// 输出面板升高至工具栏区域时，暂时隐藏窗口工具栏以免遮挡面板顶部。
@MainActor
enum OutputPanelToolbarVisibility {
    private static let suppressedWindows = NSHashTable<NSWindow>.weakObjects()

    static func sync(
        hostWindow: NSWindow?,
        isPanelVisible: Bool,
        overlayHeight: CGFloat,
        containerHeight: CGFloat
    ) {
        guard let hostWindow, let toolbar = hostWindow.toolbar else { return }
        if !isPanelVisible {
            if suppressedWindows.contains(hostWindow) {
                toolbar.isVisible = true
                suppressedWindows.remove(hostWindow)
            }
            return
        }
        let overlapLine = containerHeight - OutputPanelMetrics.estimatedToolbarOverlap
        let shouldSuppress = overlayHeight > overlapLine

        if shouldSuppress {
            if toolbar.isVisible {
                toolbar.isVisible = false
                suppressedWindows.add(hostWindow)
            }
        } else if suppressedWindows.contains(hostWindow) {
            toolbar.isVisible = true
            suppressedWindows.remove(hostWindow)
        }
    }

    static func restoreAll() {
        for window in suppressedWindows.allObjects {
            window.toolbar?.isVisible = true
        }
        suppressedWindows.removeAllObjects()
    }
}
