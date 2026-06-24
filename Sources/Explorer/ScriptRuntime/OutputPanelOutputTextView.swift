import AppKit
import SwiftUI

/// 输出区：运行中用 NSTextView 增量追加；结束后一次性套用富文本样式。
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
            if coordinator.renderedStdoutLength > 0 || coordinator.renderedStderrLength > 0 {
                coordinator.replaceAll(with: NSAttributedString())
            }
            return
        }

        if isRunning {
            coordinator.renderStyledSnapshot = false
            if stdout.count < coordinator.renderedStdoutLength {
                coordinator.replaceAll(with: plainAttributed(stdout))
                coordinator.renderedStdoutLength = stdout.count
            } else if stdout.count > coordinator.renderedStdoutLength {
                let deltaStart = stdout.index(stdout.startIndex, offsetBy: coordinator.renderedStdoutLength)
                coordinator.appendPlain(String(stdout[deltaStart...]))
                coordinator.renderedStdoutLength = stdout.count
            }

            if stderr.count < coordinator.renderedStderrLength {
                coordinator.replaceAll(with: plainAttributed(stdout, stderr: stderr))
                coordinator.renderedStdoutLength = stdout.count
                coordinator.renderedStderrLength = stderr.count
            } else if stderr.count > coordinator.renderedStderrLength {
                let deltaStart = stderr.index(stderr.startIndex, offsetBy: coordinator.renderedStderrLength)
                coordinator.appendStyled(String(stderr[deltaStart...]), color: OutputPanelStyle.stderrNSColor)
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
                coordinator.renderedStdoutLength = stdout.count
                coordinator.renderedStderrLength = stderr.count
            }
        }

        if wasNearBottom {
            coordinator.scrollToBottom()
        }
    }

    private func plainAttributed(_ stdout: String, stderr: String = "") -> NSAttributedString {
        let combined = NSMutableAttributedString()
        if !stdout.isEmpty {
            combined.append(NSAttributedString(
                string: stdout,
                attributes: [.foregroundColor: OutputPanelStyle.stdoutNSColor]
            ))
        }
        if !stderr.isEmpty {
            if combined.length > 0 {
                combined.append(NSAttributedString(string: "\n"))
            }
            combined.append(NSAttributedString(
                string: stderr,
                attributes: [.foregroundColor: OutputPanelStyle.stderrNSColor]
            ))
        }
        return combined
    }

    final class Coordinator {
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        var renderedStdoutLength = 0
        var renderedStderrLength = 0
        var renderStyledSnapshot = false
        var styledSnapshotKey = ""

        func replaceAll(with attributed: NSAttributedString) {
            guard let textView else { return }
            textView.textStorage?.setAttributedString(attributed)
            renderedStdoutLength = 0
            renderedStderrLength = 0
        }

        func appendPlain(_ text: String) {
            guard let textView, !text.isEmpty else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: OutputPanelStyle.stdoutNSColor,
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            textView.textStorage?.append(NSAttributedString(string: text, attributes: attrs))
        }

        func appendStyled(_ text: String, color: NSColor) {
            guard let textView, !text.isEmpty else { return }
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: color,
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            ]
            textView.textStorage?.append(NSAttributedString(string: text, attributes: attrs))
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
