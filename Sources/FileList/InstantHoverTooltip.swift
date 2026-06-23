import AppKit
import SwiftUI

public enum RailTooltipPresenter {
    private static let panel = RailTooltipPanel()

    public static func show(text: String, anchor: NSView) {
        panel.present(text: text, anchor: anchor)
    }

    public static func hide() {
        panel.dismiss()
    }
}

private final class RailTooltipPanel: NSPanel {
    private let chromeView = NSVisualEffectView()
    private let textLabel: NSTextField

    private let horizontalPadding: CGFloat = 8
    private let verticalPadding: CGFloat = 5
    private let maxLabelWidth: CGFloat = 360
    private let maxLabelHeight: CGFloat = 280
    private let backgroundOpacity: CGFloat = 0.9

    fileprivate init() {
        textLabel = NSTextField(wrappingLabelWithString: "")
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        backgroundColor = .clear
        hasShadow = true
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        textLabel.isEditable = false
        textLabel.isSelectable = false
        textLabel.isBezeled = false
        textLabel.drawsBackground = false
        textLabel.textColor = .labelColor
        textLabel.font = .systemFont(ofSize: 11)
        textLabel.lineBreakMode = .byWordWrapping
        textLabel.maximumNumberOfLines = 0
        textLabel.cell?.wraps = true
        textLabel.cell?.isScrollable = false

        chromeView.material = .popover
        chromeView.blendingMode = .behindWindow
        chromeView.state = .active
        chromeView.wantsLayer = true
        chromeView.alphaValue = backgroundOpacity
        chromeView.layer?.cornerRadius = 6

        chromeView.addSubview(textLabel)
        contentView = chromeView
    }

    private func applyChromeStyle() {
        chromeView.alphaValue = backgroundOpacity
        chromeView.layer?.borderWidth = 0
        chromeView.layer?.borderColor = nil
    }

    func present(text: String, anchor: NSView) {
        guard let window = anchor.window else { return }

        applyChromeStyle()

        textLabel.preferredMaxLayoutWidth = maxLabelWidth
        textLabel.stringValue = text

        let measured = textLabel.sizeThatFits(
            NSSize(width: maxLabelWidth, height: .greatestFiniteMagnitude)
        )
        let labelWidth = min(maxLabelWidth, max(1, measured.width))
        let labelHeight = min(maxLabelHeight, max(1, measured.height))
        let width = labelWidth + horizontalPadding * 2
        let height = labelHeight + verticalPadding * 2

        chromeView.setFrameSize(NSSize(width: width, height: height))
        textLabel.frame = NSRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: labelWidth,
            height: labelHeight
        )

        let anchorRect = anchor.convert(anchor.bounds, to: nil)
        let screenRect = window.convertToScreen(anchorRect)
        let screen = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        var originX = screenRect.maxX + 6
        if originX + width > screen.maxX {
            originX = screenRect.minX - width - 6
        }
        originX = max(screen.minX, min(originX, screen.maxX - width))

        var originY = screenRect.midY - height / 2
        originY = max(screen.minY, min(originY, screen.maxY - height))

        setFrame(NSRect(origin: NSPoint(x: originX, y: originY), size: NSSize(width: width, height: height)), display: true)
        orderFront(nil)
    }

    func dismiss() {
        orderOut(nil)
    }
}

public struct HoverTooltipAnchor: NSViewRepresentable {
    let text: String

    public init(text: String) {
        self.text = text
    }

    public func makeNSView(context: Context) -> HoverTooltipAnchorView {
        HoverTooltipAnchorView()
    }

    public func updateNSView(_ nsView: HoverTooltipAnchorView, context: Context) {
        nsView.tooltipText = text
    }
}

public final class HoverTooltipAnchorView: NSView {
    var tooltipText = ""
    private var trackingArea: NSTrackingArea?

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        let trimmed = tooltipText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        RailTooltipPresenter.show(text: tooltipText, anchor: self)
    }

    public override func mouseExited(with event: NSEvent) {
        RailTooltipPresenter.hide()
    }

    deinit {
        RailTooltipPresenter.hide()
    }
}

extension View {
    @ViewBuilder
    public func instantHoverTooltip(_ text: String) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self
        } else {
            background {
                HoverTooltipAnchor(text: trimmed)
            }
        }
    }
}
