import Foundation

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

        // 必须在当前 AE 仍可读时解析意图；随后立刻让出，先回复发送方。
        let resolvedIntent = resolveIntent(for: urls, explicit: intent)
        ExternalOpenDiagnostic.logRouter(urls: urls, intent: resolvedIntent, source: "router")

        // 同步开抑制：async 投递前 odoc/`newWindowForTab` 可能已到，
        // 否则系统「+」会写成假 pending，把微信 Reveal 壳收成空标签。
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)

        if resolvedIntent == .revealInFileViewer {
            markRevealHandled(urls: urls)
        }

        // 微信 / activateFileViewerSelecting 会同步等待 Apple Event 回复。
        // 若在 handler 内同步开标签、抢前台，易与发送方互相等待 → 对方「点击无响应」。
        DispatchQueue.main.async {
            Self.performOpen(urls: urls, intent: resolvedIntent)
        }
    }

    private static func performOpen(urls: [URL], intent: ExternalOpenIntent) {
        if intent == .revealInFileViewer {
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

    /// 作为系统默认文件管理器（NSFileViewer）收到的外部 `odoc`，视为「在访达中显示」。
    ///
    /// `open -R` / 微信等「在访达中显示」在部分 macOS 上以普通 `aevt/odoc` 送达（无 `keyAEPropData=srev`）。
    /// 真正的「用 MeoFind 打开文档」走 DocumentOpener → DistributedNotification → `tryOpen`，
    /// 不经过 AppDelegate `application(open:)` 的此启发式。
    ///
    /// 旧逻辑要求「默认打开程序不是主应用」才会 Reveal，导致 MeoFind 同时是某类型默认打开器时
    /// （图片/PDF 等）误走预览；预览失败再叠 suppress 泄漏 → 浏览标签被关掉 → 完全无响应。
    static func shouldTreatIncomingOpenAsRevealInFileViewer(urls: [URL]) -> Bool {
        guard DefaultFileViewerManager.isDefaultFileViewer else { return false }
        guard !urls.isEmpty else { return false }
        return true
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
