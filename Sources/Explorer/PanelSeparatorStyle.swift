import AppKit
import SwiftUI

/// 主窗口各面板之间的实线分界样式（不透明、无渐变、高对比）。
enum PanelSeparatorStyle {
    private static let colorName = NSColor.Name("MeoFind.PanelSeparator")

    /// 接近系统分隔线观感，略浅、不透明，避免与面板底色混合发虚。
    static var nsColor: NSColor {
        NSColor(name: colorName, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(calibratedWhite: 0.38, alpha: 1)
            }
            return NSColor(calibratedWhite: 0.87, alpha: 1)
        })
    }

    static var color: Color { Color(nsColor: nsColor) }

    /// 1 个物理像素对应的点高（Retina 上为 0.5pt）。
    static func hairlineThickness(for scale: CGFloat) -> CGFloat {
        1.0 / max(scale, 1)
    }

    static func fill(_ rect: NSRect, in view: NSView? = nil) {
        let draw: () -> Void = {
            nsColor.setFill()
            rect.fill()
        }
        if let view {
            view.effectiveAppearance.performAsCurrentDrawingAppearance(draw)
        } else {
            draw()
        }
    }

    static func fillWindowBackground(_ rect: NSRect, in view: NSView) {
        view.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            rect.fill()
        }
    }

    /// 顶部遮罩带高度：覆盖工具栏底部阴影渗漏，再在其下缘绘制 1 物理像素线。
    static let toolbarSeparatorMaskHeight: CGFloat = 1
}

struct PanelSolidSeparatorView: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelSolidSeparatorNSView {
        PanelSolidSeparatorNSView()
    }

    func updateNSView(_ nsView: PanelSolidSeparatorNSView, context: Context) {}
}

final class PanelSolidSeparatorNSView: NSView {
    override var isOpaque: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        PanelSeparatorStyle.fill(dirtyRect.intersection(bounds), in: self)
    }
}

/// 顶部工具栏下方：先用窗口底色遮住系统阴影，再绘制 1 物理像素实线。
struct PanelToolbarBottomSeparatorOverlay: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelToolbarBottomSeparatorOverlayNSView {
        PanelToolbarBottomSeparatorOverlayNSView()
    }

    func updateNSView(_ nsView: PanelToolbarBottomSeparatorOverlayNSView, context: Context) {}
}

final class PanelToolbarBottomSeparatorOverlayNSView: NSView {
    override var isOpaque: Bool { true }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let thickness = PanelSeparatorStyle.hairlineThickness(for: scale)
        let snappedBottom = floor(bounds.maxY * scale) / scale
        let maskRect = NSRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)
        PanelSeparatorStyle.fillWindowBackground(dirtyRect.intersection(maskRect), in: self)
        let lineRect = NSRect(
            x: bounds.minX,
            y: snappedBottom - thickness,
            width: bounds.width,
            height: thickness
        )
        PanelSeparatorStyle.fill(dirtyRect.intersection(lineRect), in: self)
    }
}
