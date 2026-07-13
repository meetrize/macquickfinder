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

    /// 构建 Finder 同款文件拖放剪贴板。
    static func preparePasteboard(urls: [URL]) -> NSPasteboard {
        let pasteboard = NSPasteboard(name: .drag)
        write(to: pasteboard, urls: urls)
        return pasteboard
    }

    static func write(to pasteboard: NSPasteboard, urls: [URL]) {
        let standardized = urls.map(\.standardizedFileURL)
        guard !standardized.isEmpty else { return }
        pasteboard.clearContents()
        // 仅写入 file URL 对象；勿再附带 NSFilenamesPboardType，否则浏览器/聊天窗口会各读一份同文件。
        _ = pasteboard.writeObjects(standardized as [NSURL])
    }

    /// 优先使用 Finder 同款 `dragImage:`。
    @discardableResult
    static func start(
        on view: NSView,
        image: NSImage,
        draggingFrame: NSRect,
        mouseLocation: NSPoint,
        startEvent: NSEvent,
        urls: [URL],
        source: NSDraggingSource
    ) -> Bool {
        let pasteboard = preparePasteboard(urls: urls)
        // dragImage 的 viewLocation 为图像左上角；draggingFrame 为 AppKit 左下角坐标系下的几何包围框。
        let dragImageLocation = NSPoint(
            x: draggingFrame.origin.x,
            y: draggingFrame.origin.y + draggingFrame.height
        )
        let dragImageOffset = NSSize(
            width: mouseLocation.x - dragImageLocation.x,
            height: mouseLocation.y - dragImageLocation.y
        )
        if performLegacyDragImage(
            on: view,
            image: image,
            at: dragImageLocation,
            offset: dragImageOffset,
            event: startEvent,
            pasteboard: pasteboard,
            source: source
        ) {
            return true
        }
        return startWithDraggingSession(
            on: view,
            image: image,
            frame: draggingFrame,
            startEvent: startEvent,
            urls: urls,
            source: source
        )
    }

    private static func performLegacyDragImage(
        on view: NSView,
        image: NSImage,
        at location: NSPoint,
        offset: NSSize,
        event: NSEvent,
        pasteboard: NSPasteboard,
        source: NSDraggingSource
    ) -> Bool {
        let selector = NSSelectorFromString("dragImage:at:offset:event:pasteboard:source:slideBack:")
        guard view.responds(to: selector) else { return false }
        typealias IMP = @convention(c) (
            AnyObject, Selector, NSImage, NSPoint, NSSize, NSEvent, NSPasteboard, Any, Bool
        ) -> Bool
        let imp = unsafeBitCast(view.method(for: selector), to: IMP.self)
        return imp(view, selector, image, location, offset, event, pasteboard, source, true)
    }

    private static func startWithDraggingSession(
        on view: NSView,
        image: NSImage,
        frame: NSRect,
        startEvent: NSEvent,
        urls: [URL],
        source: NSDraggingSource
    ) -> Bool {
        let standardized = urls.map(\.standardizedFileURL)
        guard !standardized.isEmpty else { return false }

        let items = standardized.enumerated().map { index, url in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let stackOffset = CGFloat(index * 6)
            let itemFrame = NSRect(
                x: frame.origin.x + stackOffset,
                y: frame.origin.y - stackOffset,
                width: frame.width,
                height: frame.height
            )
            item.setDraggingFrame(itemFrame, contents: index == 0 ? image : nil)
            return item
        }
        let session = view.beginDraggingSession(with: items, event: startEvent, source: source)
        session.animatesToStartingPositionsOnCancelOrFail = true
        return true
    }
}
