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
        let shouldAutoScroll = coordinator.shouldAutoScrollBeforeUpdate(isRunning: isRunning)

        if stdout.isEmpty, stderr.isEmpty {
            if !coordinator.lastRenderedStdout.isEmpty || !coordinator.lastRenderedStderr.isEmpty {
                coordinator.replaceAll(with: NSAttributedString())
                coordinator.lastRenderedStdout = ""
                coordinator.lastRenderedStderr = ""
                coordinator.resetScrollFollowing()
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

        if shouldAutoScroll {
            coordinator.scrollToBottom()
            coordinator.scheduleScrollToBottom()
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
        /// 运行中默认跟随最新输出；用户主动上滚后暂停，滚回底部后恢复。
        private var followRunningOutput = true
        private var pendingScroll = false
        private var lastClipMaxY: CGFloat?

        func shouldAutoScrollBeforeUpdate(isRunning: Bool) -> Bool {
            guard let scrollView else {
                followRunningOutput = true
                return true
            }

            let clipMaxY = scrollView.contentView.bounds.maxY
            if isRunning {
                if let lastClipMaxY, clipMaxY < lastClipMaxY - 8 {
                    followRunningOutput = false
                }
                if isScrolledNearBottom() {
                    followRunningOutput = true
                }
                lastClipMaxY = clipMaxY
                return followRunningOutput
            }

            followRunningOutput = isScrolledNearBottom()
            lastClipMaxY = clipMaxY
            return followRunningOutput
        }

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
            guard docHeight > 0 else { return true }
            return visible.maxY >= docHeight - threshold
        }

        /// 布局完成后再滚一次，避免 `replaceAll` 后第一次同步滚动够不到新文档尾部。
        func scheduleScrollToBottom() {
            guard !pendingScroll else { return }
            pendingScroll = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.pendingScroll = false
                if self.followRunningOutput || self.isScrolledNearBottom() {
                    self.scrollToBottom()
                }
            }
        }

        func scrollToBottom() {
            guard let textView else { return }
            if let container = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: container)
            }
            let length = (textView.string as NSString).length
            if length > 0 {
                textView.scrollRangeToVisible(NSRange(location: length - 1, length: 1))
            } else {
                textView.scrollToEndOfDocument(nil)
            }
            lastClipMaxY = scrollView?.contentView.bounds.maxY
        }

        func resetScrollFollowing() {
            followRunningOutput = true
            lastClipMaxY = nil
        }
    }
}
