import AppKit
import SwiftUI

/// 横向滚动且垂直居中内容的 ScrollView（修正 macOS NSScrollView 默认顶对齐）。
struct CenteredHorizontalScrollView<Content: View>: NSViewRepresentable {
    var height: CGFloat
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(height: height, content: content)
    }

    func makeNSView(context: Context) -> OutputPanelTabScrollView {
        let scrollView = OutputPanelTabScrollView()
        scrollView.barHeight = height
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay

        let clipView = CenteredHorizontalClipView()
        clipView.drawsBackground = false
        clipView.barHeight = height
        scrollView.contentView = clipView

        let host = SafeAreaIgnoringHostingView(rootView: context.coordinator.rootView())
        let document = TabBarDocumentView(host: host, barHeight: height)
        clipView.documentView = document
        context.coordinator.documentView = document
        context.coordinator.clipView = clipView
        context.coordinator.relayout()
        return scrollView
    }

    func updateNSView(_ scrollView: OutputPanelTabScrollView, context: Context) {
        context.coordinator.height = height
        context.coordinator.content = content
        scrollView.barHeight = height
        context.coordinator.clipView?.barHeight = height
        context.coordinator.documentView?.barHeight = height
        context.coordinator.documentView?.host.rootView = context.coordinator.rootView()
        context.coordinator.relayout()
    }

    final class Coordinator {
        var height: CGFloat
        var content: () -> Content
        weak var documentView: TabBarDocumentView?
        weak var clipView: CenteredHorizontalClipView?

        init(height: CGFloat, content: @escaping () -> Content) {
            self.height = height
            self.content = content
        }

        func rootView() -> AnyView {
            AnyView(
                content()
                    .frame(height: height, alignment: .center)
            )
        }

        func relayout() {
            guard let documentView, let clipView else { return }
            documentView.host.layoutSubtreeIfNeeded()
            let fittingWidth = max(documentView.host.fittingSize.width, 1)
            documentView.layoutHost(width: fittingWidth)
            clipView.documentView = documentView
            clipView.layoutDocumentView()
        }
    }
}

/// 禁止继承窗口工具栏 safe area，避免 Tab 行在标题栏内被向下偏移。
final class SafeAreaIgnoringHostingView: NSHostingView<AnyView> {
    @MainActor
    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        if #available(macOS 13.0, *) {
            sizingOptions = [.intrinsicContentSize]
        }
        if #available(macOS 14.0, *) {
            safeAreaRegions = []
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var safeAreaInsets: NSEdgeInsets { .init() }

    override var additionalSafeAreaInsets: NSEdgeInsets {
        get { .init() }
        set {}
    }

    override var safeAreaRect: NSRect { bounds }
}

final class OutputPanelTabScrollView: NSScrollView {
    var barHeight: CGFloat = OutputPanelMetrics.titleBarHeight

    override var isFlipped: Bool { true }

    override var intrinsicContentSize: NSSize {
        NSSize(width: NSView.noIntrinsicMetric, height: barHeight)
    }
}

final class TabBarDocumentView: NSView {
    override var isFlipped: Bool { true }

    let host: SafeAreaIgnoringHostingView
    var barHeight: CGFloat

    init(host: SafeAreaIgnoringHostingView, barHeight: CGFloat) {
        self.host = host
        self.barHeight = barHeight
        super.init(frame: .zero)
        addSubview(host)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func layoutHost(width: CGFloat) {
        host.frame = NSRect(x: 0, y: 0, width: width, height: barHeight)
        frame = NSRect(x: 0, y: 0, width: width, height: barHeight)
    }
}

final class CenteredHorizontalClipView: NSClipView {
    var barHeight: CGFloat = OutputPanelMetrics.titleBarHeight

    override var isFlipped: Bool { true }

    func layoutDocumentView() {
        guard let documentView else { return }
        var frame = documentView.frame
        frame.origin = .zero
        frame.size.height = barHeight
        documentView.frame = frame
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        layoutDocumentView()
    }

    override func setBoundsSize(_ newSize: NSSize) {
        super.setBoundsSize(newSize)
        layoutDocumentView()
    }

    override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
        let result = super.constrainBoundsRect(proposedBounds)
        layoutDocumentView()
        return result
    }
}
