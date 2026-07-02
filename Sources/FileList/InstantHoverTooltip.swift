import AppKit
import SwiftUI

public enum RailTooltipPresenter {
    private static let panel = RailTooltipPanel()
    private static var suppression: TooltipDismissSuppression?

    public static func show(text: String, anchor: NSView) {
        panel.present(text: text, anchor: anchor)
        beginDismissSuppressionIfNeeded()
    }

    public static func hide() {
        endDismissSuppression()
        panel.dismiss()
    }

    private static func beginDismissSuppressionIfNeeded() {
        guard suppression == nil else { return }
        suppression = TooltipDismissSuppression {
            hide()
        }
    }

    private static func endDismissSuppression() {
        let current = suppression
        suppression = nil
        current?.teardown()
    }
}

/// Hides the active hover tooltip when a context menu opens or the user right-clicks.
private final class TooltipDismissSuppression {
    private var rightClickMonitor: Any?
    private var menuTrackingObserver: NSObjectProtocol?
    private let onDismiss: () -> Void

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            self?.onDismiss()
            return event
        }

        menuTrackingObserver = NotificationCenter.default.addObserver(
            forName: NSMenu.didBeginTrackingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.onDismiss()
        }
    }

    func teardown() {
        if let rightClickMonitor {
            NSEvent.removeMonitor(rightClickMonitor)
            self.rightClickMonitor = nil
        }
        if let menuTrackingObserver {
            NotificationCenter.default.removeObserver(menuTrackingObserver)
            self.menuTrackingObserver = nil
        }
    }

    deinit {
        teardown()
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
    private let screenInset: CGFloat = 8
    private let anchorGap: CGFloat = 8

    fileprivate init() {
        textLabel = NSTextField(wrappingLabelWithString: "")
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // Below .popUpMenu so context menus always render above tooltips.
        level = .floating
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

        // Tooltip positioning strategy:
        // 1) Prefer below the anchor (closer to cursor reading flow)
        // 2) If no space, place above
        // 3) If both are tight, pick the side with more free space and clamp to visible frame
        let clampedMinX = screen.minX + screenInset
        let clampedMaxX = screen.maxX - width - screenInset
        let preferredX = screenRect.midX - width / 2
        let originX = max(clampedMinX, min(preferredX, clampedMaxX))

        let requiredVerticalSpace = height + anchorGap
        let spaceBelow = screenRect.minY - screen.minY
        let spaceAbove = screen.maxY - screenRect.maxY
        let belowY = screenRect.minY - height - anchorGap
        let aboveY = screenRect.maxY + anchorGap
        let clampedMinY = screen.minY + screenInset
        let clampedMaxY = screen.maxY - height - screenInset

        let originY: CGFloat
        if spaceBelow >= requiredVerticalSpace {
            originY = max(clampedMinY, min(belowY, clampedMaxY))
        } else if spaceAbove >= requiredVerticalSpace {
            originY = max(clampedMinY, min(aboveY, clampedMaxY))
        } else if spaceAbove >= spaceBelow {
            originY = max(clampedMinY, min(aboveY, clampedMaxY))
        } else {
            originY = max(clampedMinY, min(belowY, clampedMaxY))
        }

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

    public override func rightMouseDown(with event: NSEvent) {
        RailTooltipPresenter.hide()
        super.rightMouseDown(with: event)
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
