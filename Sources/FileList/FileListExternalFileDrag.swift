import AppKit
import Foundation
import UniformTypeIdentifiers

/// 拖到本应用外（浏览器上传、scrcpy 安装 APK 等）所需的 Finder 兼容拖放支持。
enum FileListExternalFileDrag {
    static let legacyFilenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")

    static let pasteboardTypes: [NSPasteboard.PasteboardType] = [
        .fileURL,
        NSPasteboard.PasteboardType(UTType.fileURL.identifier),
        NSPasteboard.PasteboardType("public.file-url"),
        legacyFilenamesType,
    ]

    /// 应用内：移动；应用外：与 Finder 一致提供全部操作（SDL/scrcpy 需要 generic/copy）。
    static func sourceOperationMask(for context: NSDraggingContext) -> NSDragOperation {
        if FileListDragSupport.shouldCopyFromCurrentEvent() {
            return .copy
        }
        switch context {
        case .withinApplication:
            return .move
        default:
            return .every
        }
    }

    /// 构建文件拖放剪贴板（仅 file URL，避免与 `NSFilenamesPboardType` 并存导致目标双计）。
    static func preparePasteboard(urls: [URL]) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .drag)
        write(to: pasteboard, urls: urls)
        return pasteboard
    }

    static func write(to pasteboard: NSPasteboard, urls: [URL]) {
        let standardized = urls.map(\.standardizedFileURL)
        guard !standardized.isEmpty else { return }
        pasteboard.clearContents()
        _ = pasteboard.writeObjects(standardized as [NSURL])
    }

    /// 启动文件拖放。每个 URL 对应一个 `NSDraggingItem`，多选时目标才能收到全部文件。
    /// 不走旧版 `dragImage:`（返回 void，误当成 Bool 会跳过会话）。
    @discardableResult
    static func start(
        on view: NSView,
        items: [NSDraggingItem],
        startEvent: NSEvent,
        source: NSDraggingSource
    ) -> NSDraggingSession? {
        guard !items.isEmpty else { return nil }
        let session = view.beginDraggingSession(with: items, event: startEvent, source: source)
        session.animatesToStartingPositionsOnCancelOrFail = true
        if items.count > 1 {
            session.draggingFormation = .pile
        }
        return session
    }

    /// 便捷入口：按 URL 列表生成拖放项（每项一个 file URL）。
    @discardableResult
    static func start(
        on view: NSView,
        image: NSImage,
        draggingFrame: NSRect,
        mouseLocation: NSPoint,
        startEvent: NSEvent,
        urls: [URL],
        source: NSDraggingSource
    ) -> NSDraggingSession? {
        _ = mouseLocation
        let standardized = urls.map(\.standardizedFileURL)
        guard !standardized.isEmpty else { return nil }

        let items = standardized.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let stackOffset = CGFloat(index * 6)
            let itemFrame = NSRect(
                x: draggingFrame.origin.x + stackOffset,
                y: draggingFrame.origin.y - stackOffset,
                width: draggingFrame.width,
                height: draggingFrame.height
            )
            item.setDraggingFrame(itemFrame, contents: index == 0 ? image : nil)
            return item
        }
        return start(on: view, items: items, startEvent: startEvent, source: source)
    }
}
