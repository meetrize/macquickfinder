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
    // AERegistry `keyAESelection` / 部分环境未桥接为 Swift 符号，使用四字符码。
    private static let keySelection = AEKeyword(FourCharCode(0x7365_6C65)) // 'sele'
    private static let keyFile = AEKeyword(FourCharCode(0x6B66_696C)) // 'kfil' == keyAEFile

    static func fileURLs(from event: NSAppleEventDescriptor) -> [URL] {
        let keywords: [AEKeyword] = [
            AEKeyword(keyDirectObject),
            keySelection,
            keyFile,
        ]
        for keyword in keywords {
            guard let list = event.paramDescriptor(forKeyword: keyword) else { continue }
            let urls = fileURLs(fromList: list)
            if !urls.isEmpty {
                return urls
            }
        }
        return []
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
        // 微信等可能传入 typeAlias / bookmark，需 coerce 到 file URL。
        if let coerced = descriptor.coerce(toDescriptorType: typeFileURL) {
            return coerced.fileURLValue
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
    // 先记一笔：URL coerce 若卡住/失败，以前会完全无日志，微信侧看起来像「点了没反应」。
    ExternalOpenDiagnostic.logRaw("reveal-handler enter")
    let urls = ExternalAppleEventFileURLExtractor.fileURLs(from: event)
    ExternalOpenDiagnostic.logRevealHandler(event: event, urls: urls)
    guard !urls.isEmpty else {
      ExternalOpenDiagnostic.logRaw("reveal-handler empty urls — ignored")
      return
    }
    // srev 不走 AppDelegate application(open:)，须在此同步开抑制，挡住系统「+」抢 pending。
    ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)
    // 尽快返回，避免发送方（微信）阻塞在 AE reply 上。
    ExternalOpenRouter.handleOpen(urls: urls, intent: .revealInFileViewer)
  }
}
