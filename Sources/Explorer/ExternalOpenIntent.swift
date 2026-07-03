import AppKit
import CoreServices
import Foundation

/// 外部打开请求的语义：在文件管理器中定位选中，或以默认查看器打开文档。
enum ExternalOpenIntent: Equatable {
    case revealInFileViewer
    case openDocument
}

enum ExternalOpenIntentDetector {
    /// 根据当前线程正在处理的 Apple Event 判断外部打开意图。
    static func currentIntent() -> ExternalOpenIntent {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return .openDocument
        }
        return intent(for: event)
    }

    static func currentIntentFromCurrentEvent() -> ExternalOpenIntent {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else {
            return .openDocument
        }
        if isRevealOpenDocumentsEvent(event) || intent(for: event) == .revealInFileViewer {
            return .revealInFileViewer
        }
        return .openDocument
    }

    static func intent(for event: NSAppleEventDescriptor) -> ExternalOpenIntent {
        // `open -R` / activateFileViewerSelecting → `aevt/srev`（少数环境为 `FNDR/srev`）
        // `open file` → `aevt/odoc` 或 `aevt/sope`
        if event.eventID == AEEventID(kAERevealSelection) {
            return .revealInFileViewer
        }
        return .openDocument
    }

    /// `open -R` 在部分 macOS 版本会以 `aevt/odoc` 送达，Reveal 语义编码在 `keyAEPropData`。
    static func isRevealOpenDocumentsEvent(_ event: NSAppleEventDescriptor) -> Bool {
        guard event.eventClass == AEEventClass(kCoreEventClass),
              event.eventID == AEEventID(kAEOpenDocuments) else {
            return false
        }
        guard let prop = event.paramDescriptor(forKeyword: AEKeyword(keyAEPropData)) else {
            return false
        }
        return prop.enumCodeValue == kAERevealSelection
    }

    static func isRevealAppleEvent(_ event: NSAppleEventDescriptor) -> Bool {
        if intent(for: event) == .revealInFileViewer {
            return true
        }
        return isRevealOpenDocumentsEvent(event)
    }
}

enum ExternalAppleEventFileURLExtractor {
    static func fileURLs(from event: NSAppleEventDescriptor) -> [URL] {
        guard let list = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject)) else {
            return []
        }
        return fileURLs(fromList: list)
    }

    private static func fileURLs(fromList list: NSAppleEventDescriptor) -> [URL] {
        guard list.descriptorType == typeAEList else {
            return fileURL(from: list).map { [$0] } ?? []
        }

        var urls: [URL] = []
        for index in 1...list.numberOfItems {
            guard let item = list.atIndex(index) else { continue }
            if let url = fileURL(from: item) {
                urls.append(url)
            }
        }
        return urls
    }

    private static func fileURL(from descriptor: NSAppleEventDescriptor) -> URL? {
        if let url = descriptor.fileURLValue {
            return url
        }
        if let path = descriptor.stringValue, !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}

/// 处理 Finder 文件查看器相关的 Reveal Apple Event（Safari「在访达中显示」、`open -R` 等）。
@MainActor
enum ExternalFileViewerRevealSupport {
    private static var isInstalled = false

    static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        let manager = NSAppleEventManager.shared()
        let handler = FileViewerRevealAppleEventHandler.shared
        for eventClass in [AEEventClass(kCoreEventClass), AEEventClass(kAEFinderEvents)] {
            manager.setEventHandler(
                handler,
                andSelector: #selector(FileViewerRevealAppleEventHandler.handle(event:replyEvent:)),
                forEventClass: eventClass,
                andEventID: AEEventID(kAERevealSelection)
            )
        }
    }
}

@MainActor
private final class FileViewerRevealAppleEventHandler: NSObject {
  static let shared = FileViewerRevealAppleEventHandler()

  @objc func handle(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
    let urls = ExternalAppleEventFileURLExtractor.fileURLs(from: event)
    guard !urls.isEmpty else { return }
    ExternalOpenDiagnostic.logRevealHandler(event: event, urls: urls)
    ExternalOpenRouter.handleOpen(urls: urls, intent: .revealInFileViewer)
  }
}
