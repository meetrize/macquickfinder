import CoreServices
import Foundation
import UniformTypeIdentifiers

/// 统一路由外部打开请求：Reveal 走浏览窗口，文档打开优先独立预览。
@MainActor
enum ExternalOpenRouter {
    private static let revealDedupeWindow: TimeInterval = 0.5
    private static var recentlyHandledRevealPaths: [String: Date] = [:]

    static func handleOpen(urls: [URL], intent: ExternalOpenIntent? = nil) {
        if consumeRevealIfRecentlyHandled(urls: urls) {
            ExternalOpenDiagnostic.logRouter(urls: urls, intent: .revealInFileViewer, source: "deduped-reveal")
            return
        }

        let resolvedIntent = resolveIntent(for: urls, explicit: intent)
        ExternalOpenDiagnostic.logRouter(urls: urls, intent: resolvedIntent, source: "router")

        if resolvedIntent == .revealInFileViewer {
            markRevealHandled(urls: urls)
            ExternalFolderOpenCenter.shared.requestOpen(urls: urls)
            return
        }

        if ExternalPreviewOpenCenter.shared.tryOpen(urls: urls) {
            return
        }
        ExternalFolderOpenCenter.shared.requestOpen(urls: urls)
    }

    static func resolveIntent(for urls: [URL], explicit: ExternalOpenIntent?) -> ExternalOpenIntent {
        if let explicit {
            return explicit
        }
        if ExternalOpenIntentDetector.currentIntentFromCurrentEvent() == .revealInFileViewer {
            return .revealInFileViewer
        }
        if shouldTreatIncomingOpenAsRevealInFileViewer(urls: urls) {
            return .revealInFileViewer
        }
        return .openDocument
    }

    /// 作为 NSFileViewer 收到 `odoc`，且该文件类型的默认打开程序不是主应用时，视为 Reveal。
    static func shouldTreatIncomingOpenAsRevealInFileViewer(urls: [URL]) -> Bool {
        guard DefaultFileViewerManager.isDefaultFileViewer else { return false }
        guard PreviewOpenPreferences.externalOpenAction == .standaloneOnly else { return false }
        guard !urls.isEmpty else { return false }
        return urls.allSatisfy { !isMainApplicationDefaultHandler(for: $0) }
    }

    static func isMainApplicationDefaultHandler(for url: URL) -> Bool {
        let mainID = DefaultFileViewerManager.bundleIdentifier
        guard let defaultAppURL = LSCopyDefaultApplicationURLForURL(
            url as CFURL,
            .all,
            nil
        )?.takeRetainedValue() as URL? else {
            return false
        }
        return Bundle(url: defaultAppURL)?.bundleIdentifier == mainID
    }

    static func markRevealHandled(urls: [URL]) {
        let now = Date()
        for url in urls {
            recentlyHandledRevealPaths[url.standardizedFileURL.path] = now
        }
        pruneRevealDedupe(now: now)
    }

    private static func consumeRevealIfRecentlyHandled(urls: [URL]) -> Bool {
        let now = Date()
        pruneRevealDedupe(now: now)
        guard !urls.isEmpty else { return false }
        return urls.allSatisfy { url in
            guard let handledAt = recentlyHandledRevealPaths[url.standardizedFileURL.path] else {
                return false
            }
            return now.timeIntervalSince(handledAt) < revealDedupeWindow
        }
    }

    private static func pruneRevealDedupe(now: Date) {
        recentlyHandledRevealPaths = recentlyHandledRevealPaths.filter {
            now.timeIntervalSince($0.value) < revealDedupeWindow
        }
    }
}
