import AppKit
import SwiftUI

/// 输出区：运行中与结束后均按 stderr 分段富文本渲染，避免内联控制符显示为乱码。
struct OutputPanelOutputTextView: NSViewRepresentable {
    let stdout: String
    let stderr: String
    let isRunning: Bool
    let findText: String
    let findNextToken: UInt
    @Binding var findMatchCount: Int
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
        scrollView.contentView.postsFrameChangedNotifications = true

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
        context.coordinator.installWidthObserver(on: scrollView.contentView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard context.coordinator.textView != nil else { return }

        let coordinator = context.coordinator
        let trimmedFindText = findText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasActiveFind = !trimmedFindText.isEmpty
        let shouldAutoScroll = coordinator.shouldAutoScrollBeforeUpdate(isRunning: isRunning)
        let statusTabLocation = coordinator.currentStatusTabLocation()
        var didRebuildContent = false

        if stdout.isEmpty, stderr.isEmpty {
            if !coordinator.lastRenderedStdout.isEmpty || !coordinator.lastRenderedStderr.isEmpty {
                coordinator.replaceAll(with: NSAttributedString())
                coordinator.lastRenderedStdout = ""
                coordinator.lastRenderedStderr = ""
                coordinator.resetScrollFollowing()
                didRebuildContent = true
            }
            coordinator.clearFindNavigation(findMatchCount: $findMatchCount)
            return
        }

        if isRunning {
            coordinator.renderStyledSnapshot = false
            if stdout != coordinator.lastRenderedStdout
                || stderr != coordinator.lastRenderedStderr
                || coordinator.shouldRefreshStatusTabLocation(statusTabLocation) {
                let attributed = OutputPanelAttributedText.makeNSAttributedString(
                    stdout: stdout,
                    stderr: stderr,
                    findText: hasActiveFind ? findText : "",
                    statusTabLocation: statusTabLocation
                )
                coordinator.replaceAll(with: attributed)
                coordinator.lastRenderedStdout = stdout
                coordinator.lastRenderedStderr = stderr
                coordinator.lastStatusTabLocation = statusTabLocation
                coordinator.renderedStdoutLength = stdout.count
                coordinator.renderedStderrLength = stderr.count
                didRebuildContent = true
            }
        } else {
            let snapshotKey = "\(stdout.count)|\(stderr.count)|\(stdout.hashValue)|\(stderr.hashValue)|\(findText)|\(Int(statusTabLocation))"
            if !coordinator.renderStyledSnapshot || coordinator.styledSnapshotKey != snapshotKey {
                let attributed = OutputPanelAttributedText.makeNSAttributedString(
                    stdout: stdout,
                    stderr: stderr,
                    findText: findText,
                    statusTabLocation: statusTabLocation
                )
                coordinator.replaceAll(with: attributed)
                coordinator.renderStyledSnapshot = true
                coordinator.styledSnapshotKey = snapshotKey
                coordinator.lastRenderedStdout = stdout
                coordinator.lastRenderedStderr = stderr
                coordinator.lastStatusTabLocation = statusTabLocation
                coordinator.renderedStdoutLength = stdout.count
                coordinator.renderedStderrLength = stderr.count
                didRebuildContent = true
            }
        }

        if hasActiveFind {
            coordinator.updateFindNavigation(
                findText: findText,
                findNextToken: findNextToken,
                findMatchCount: $findMatchCount,
                didRebuildContent: didRebuildContent
            )
        } else {
            coordinator.clearFindNavigation(findMatchCount: $findMatchCount)
        }

        if (shouldAutoScroll || coordinator.shouldForceScrollToBottomAfterRebuild()) && !hasActiveFind {
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
        var lastStatusTabLocation: CGFloat = 0
        var lastFindText = ""
        var lastFindNextToken: UInt = 0
        var findCurrentIndex = 0
        var findMatchRanges: [NSRange] = []
        private var forceScrollToBottomAfterRebuild = false
        /// 运行中默认跟随最新输出；用户主动上滚后暂停，滚回底部后恢复。
        private var followRunningOutput = true
        private var pendingScroll = false
        private var lastClipMaxY: CGFloat?
        private var widthObserver: NSObjectProtocol?

        deinit {
            if let widthObserver {
                NotificationCenter.default.removeObserver(widthObserver)
            }
        }

        func installWidthObserver(on clipView: NSClipView) {
            guard widthObserver == nil else { return }
            widthObserver = NotificationCenter.default.addObserver(
                forName: NSView.frameDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak self] _ in
                self?.refreshStatusTabAlignmentIfNeeded()
            }
        }

        func currentStatusTabLocation() -> CGFloat {
            guard let textView, let scrollView else {
                return OutputPanelAttributedText.defaultStatusTabLocation
            }

            let width = scrollView.contentView.bounds.width
            guard width > 40 else {
                return OutputPanelAttributedText.defaultStatusTabLocation
            }

            let inset = textView.textContainerInset
            return max(120, width - inset.width * 2)
        }

        func shouldRefreshStatusTabLocation(_ location: CGFloat) -> Bool {
            abs(location - lastStatusTabLocation) > 1
        }

        func refreshStatusTabAlignmentIfNeeded() {
            guard let textView, let storage = textView.textStorage, storage.length > 0 else { return }
            let location = currentStatusTabLocation()
            guard shouldRefreshStatusTabLocation(location) else { return }
            lastStatusTabLocation = location
            storage.beginEditing()
            OutputPanelAttributedText.refreshStatusTabLocations(in: storage, statusTabLocation: location)
            storage.endEditing()
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        }

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
            let oldLength = (textView.string as NSString).length
            textView.textStorage?.setAttributedString(attributed)
            let newLength = attributed.length
            if newLength < oldLength || oldLength == 0 {
                followRunningOutput = true
                forceScrollToBottomAfterRebuild = true
            }
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
                self.refreshStatusTabAlignmentIfNeeded()
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
            forceScrollToBottomAfterRebuild = false
        }

        func shouldForceScrollToBottomAfterRebuild() -> Bool {
            defer { forceScrollToBottomAfterRebuild = false }
            return forceScrollToBottomAfterRebuild
        }

        func clearFindNavigation(findMatchCount: Binding<Int>) {
            lastFindText = ""
            lastFindNextToken = 0
            findCurrentIndex = 0
            findMatchRanges = []
            if findMatchCount.wrappedValue != 0 {
                findMatchCount.wrappedValue = 0
            }
        }

        func updateFindNavigation(
            findText: String,
            findNextToken: UInt,
            findMatchCount: Binding<Int>,
            didRebuildContent: Bool
        ) {
            let trimmed = findText.trimmingCharacters(in: .whitespacesAndNewlines)
            let findTextChanged = lastFindText != findText
            let nextTriggered = !findTextChanged && lastFindNextToken != findNextToken

            if findTextChanged {
                lastFindText = findText
                findCurrentIndex = 0
                lastFindNextToken = findNextToken
            }

            guard !trimmed.isEmpty else {
                findMatchRanges = []
                if findMatchCount.wrappedValue != 0 {
                    findMatchCount.wrappedValue = 0
                }
                return
            }

            if findTextChanged || didRebuildContent {
                findMatchRanges = OutputPanelAttributedText.findMatchRanges(
                    of: trimmed,
                    in: textView?.string ?? ""
                )
                if findMatchCount.wrappedValue != findMatchRanges.count {
                    findMatchCount.wrappedValue = findMatchRanges.count
                }
                if findCurrentIndex >= findMatchRanges.count {
                    findCurrentIndex = 0
                }
            }

            if findTextChanged || (didRebuildContent && !findMatchRanges.isEmpty) {
                scrollToFindMatch(at: findCurrentIndex)
            } else if nextTriggered {
                lastFindNextToken = findNextToken
                guard !findMatchRanges.isEmpty else { return }
                findCurrentIndex = (findCurrentIndex + 1) % findMatchRanges.count
                scrollToFindMatch(at: findCurrentIndex)
            }
        }

        func scrollToFindMatch(at index: Int) {
            guard let textView, index < findMatchRanges.count else { return }
            let range = findMatchRanges[index]
            if let container = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: container)
            }
            textView.scrollRangeToVisible(range)
            lastClipMaxY = scrollView?.contentView.bounds.maxY
        }
    }
}
