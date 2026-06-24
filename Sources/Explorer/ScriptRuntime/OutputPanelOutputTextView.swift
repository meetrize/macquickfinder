import AppKit
import SwiftUI

/// 输出区：运行中与结束后均按 stderr 分段富文本渲染，避免内联控制符显示为乱码。
struct OutputPanelOutputTextView: NSViewRepresentable {
    let stdout: String
    let stderr: String
    let isRunning: Bool
    let findText: String
    let emptyPlaceholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.contentView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isRichText = true
        textView.font = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = OutputPanelStyle.stdoutNSColor
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.lineFragmentPadding = 0
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.textView != nil else { return }

        let coordinator = context.coordinator
        let wasNearBottom = coordinator.isScrolledNearBottom()

        if stdout.isEmpty, stderr.isEmpty {
            if !coordinator.lastRenderedStdout.isEmpty || !coordinator.lastRenderedStderr.isEmpty {
                coordinator.replaceAll(with: NSAttributedString())
                coordinator.lastRenderedStdout = ""
                coordinator.lastRenderedStderr = ""
            }
            return
        }

        if isRunning {
            coordinator.renderStyledSnapshot = false
            if stdout != coordinator.lastRenderedStdout || stderr != coordinator.lastRenderedStderr {
                let attributed = OutputPanelAttributedText.makeNSAttributedString(
                    stdout: stdout,
                    stderr: stderr,
                    findText: ""
                )
                coordinator.replaceAll(with: attributed)
                coordinator.lastRenderedStdout = stdout
                coordinator.lastRenderedStderr = stderr
                coordinator.renderedStdoutLength = stdout.count
                coordinator.renderedStderrLength = stderr.count
            }
        } else {
            let snapshotKey = "\(stdout.count)|\(stderr.count)|\(stdout.hashValue)|\(stderr.hashValue)|\(findText)"
            if !coordinator.renderStyledSnapshot || coordinator.styledSnapshotKey != snapshotKey {
                let attributed = OutputPanelAttributedText.makeNSAttributedString(
                    stdout: stdout,
                    stderr: stderr,
                    findText: findText
                )
                coordinator.replaceAll(with: attributed)
                coordinator.renderStyledSnapshot = true
                coordinator.styledSnapshotKey = snapshotKey
                coordinator.lastRenderedStdout = stdout
                coordinator.lastRenderedStderr = stderr
                coordinator.renderedStdoutLength = stdout.count
                coordinator.renderedStderrLength = stderr.count
            }
        }

        if wasNearBottom {
            coordinator.scrollToBottom()
        }
    }

    final class Coordinator {
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var renderedStdoutLength = 0
        var renderedStderrLength = 0
        var lastRenderedStdout = ""
        var lastRenderedStderr = ""
        var renderStyledSnapshot = false
        var styledSnapshotKey = ""

        func replaceAll(with attributed: NSAttributedString) {
            guard let textView else { return }
            textView.textStorage?.setAttributedString(attributed)
            renderedStdoutLength = 0
            renderedStderrLength = 0
        }

        func isScrolledNearBottom(threshold: CGFloat = 24) -> Bool {
            guard let scrollView, let textView else { return true }
            let visible = scrollView.contentView.bounds
            let docHeight = textView.bounds.height
            return visible.maxY >= docHeight - threshold
        }

        func scrollToBottom() {
            textView?.scrollToEndOfDocument(nil)
        }
    }
}
