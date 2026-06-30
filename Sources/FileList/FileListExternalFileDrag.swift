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
        let paths = standardized.map(\.path)
        guard !paths.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.declareTypes(pasteboardTypes, owner: nil)
        pasteboard.setPropertyList(paths, forType: legacyFilenamesType)
        _ = pasteboard.writeObjects(standardized as [NSURL])
    }

    /// 将源剪贴板内容复制到拖放会话剪贴板（供 beginDraggingSession 回退路径使用）。
    static func copyPasteboard(_ source: NSPasteboard, to destination: NSPasteboard) {
        destination.clearContents()
        guard let types = source.types, !types.isEmpty else { return }
        destination.declareTypes(types, owner: nil)
        for type in types {
            if let data = source.data(forType: type) {
                destination.setData(data, forType: type)
            }
        }
    }

    /// 优先使用 Finder 同款 `dragImage:`（SDL/scrcpy 依赖 NSFilenamesPboardType）。
    @discardableResult
    static func start(
        on view: NSView,
        image: NSImage,
        draggingFrame: NSRect,
        mouseLocation: NSPoint,
        dragImageOffset: NSSize,
        startEvent: NSEvent,
        urls: [URL],
        source: NSDraggingSource
    ) -> Bool {
        let pasteboard = preparePasteboard(urls: urls)
        if performLegacyDragImage(
            on: view,
            image: image,
            at: mouseLocation,
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
            source: source,
            pasteboard: pasteboard
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
        source: NSDraggingSource,
        pasteboard: NSPasteboard
    ) -> Bool {
        let item = NSDraggingItem(pasteboardWriter: MultiFilePasteboardWriter(urls: urls))
        item.setDraggingFrame(frame, contents: image)
        let session = view.beginDraggingSession(with: [item], event: startEvent, source: source)
        session.animatesToStartingPositionsOnCancelOrFail = true
        copyPasteboard(pasteboard, to: session.draggingPasteboard)
        return true
    }
}

// MARK: - Multi-file pasteboard writer

private final class MultiFilePasteboardWriter: NSObject, NSPasteboardWriting {
    private let urls: [URL]

    init(urls: [URL]) {
        self.urls = urls.map(\.standardizedFileURL)
    }

    func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        FileListExternalFileDrag.pasteboardTypes
    }

    func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        switch type {
        case .fileURL,
             NSPasteboard.PasteboardType(UTType.fileURL.identifier),
             NSPasteboard.PasteboardType("public.file-url"):
            return urls.first?.absoluteString
        case FileListExternalFileDrag.legacyFilenamesType:
            return urls.map(\.path)
        default:
            return nil
        }
    }
}
