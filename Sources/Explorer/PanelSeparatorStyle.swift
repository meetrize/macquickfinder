import AppKit
import SwiftUI

/// 主窗口各面板之间的实线分界样式（不透明、无渐变、高对比）。
enum PanelSeparatorStyle {
    private static let colorName = NSColor.Name("MeoFind.PanelSeparator")

    /// 比系统 `gridColor` / `separatorColor` 更深，避免与面板底色对比不足。
    static var nsColor: NSColor {
        NSColor(name: colorName, dynamicProvider: { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            if isDark {
                return NSColor(calibratedWhite: 0.55, alpha: 1)
            }
            return NSColor(calibratedWhite: 0.38, alpha: 1)
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

/// 顶部工具栏下方等需要最细 1px 实线的场景。
struct PanelHairlineSeparatorView: NSViewRepresentable {
    func makeNSView(context: Context) -> PanelHairlineSeparatorNSView {
        PanelHairlineSeparatorNSView()
    }

    func updateNSView(_ nsView: PanelHairlineSeparatorNSView, context: Context) {}
}

final class PanelHairlineSeparatorNSView: NSView {
    override var isOpaque: Bool { false }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        let thickness = PanelSeparatorStyle.hairlineThickness(for: scale)
        let lineRect = NSRect(
            x: bounds.minX,
            y: bounds.maxY - thickness,
            width: bounds.width,
            height: thickness
        )
        PanelSeparatorStyle.fill(dirtyRect.intersection(lineRect), in: self)
    }
}
