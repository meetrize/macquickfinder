import AppKit
import FileList
import Foundation

@MainActor
final class ExternalPreviewOpenCenter: ObservableObject {
    static let shared = ExternalPreviewOpenCenter()

    private var openPreviewWindow: ((PreviewWindowValue) -> Void)?
    private var pendingPreviewWindows: [PreviewWindowValue] = []
    private(set) var shouldSuppressExplorerWindows = false

    private init() {}

    func clearSuppressExplorerWindows() {
        shouldSuppressExplorerWindows = false
    }

    func setOpenPreviewWindowHandler(_ handler: @escaping (PreviewWindowValue) -> Void) {
        openPreviewWindow = handler
        flushPendingPreviewWindows()
    }

    /// 若 URL 中含可独立预览文件，则打开独立预览窗并返回 `true`。
    @discardableResult
    func tryOpen(urls: [URL]) -> Bool {
        guard PreviewOpenPreferences.externalOpenAction == .standaloneOnly else {
            return false
        }

        let previewableURLs = ExternalPreviewFileClassifier.previewableURLs(from: urls)
        guard !previewableURLs.isEmpty else { return false }

        let app = NSApplication.shared
        app.unhide(nil)
        app.activate(ignoringOtherApps: true)

        let imageURLs = ExternalImageFileClassifier.imageURLs(from: previewableURLs)
        let openOneWindowPerImage = previewableURLs.count > 1
            && imageURLs.count == previewableURLs.count
            && PreviewOpenPreferences.externalMultiImageOpen == .oneWindowPerFile

        let opened: Bool
        if openOneWindowPerImage {
            var openedAny = false
            for url in previewableURLs {
                if openPreviewWindow(for: url) {
                    openedAny = true
                }
            }
            opened = openedAny
        } else if let firstURL = previewableURLs.first {
            let additionalURLs = Array(previewableURLs.dropFirst())
            opened = openPreviewWindow(for: firstURL, additionalURLs: additionalURLs)
        } else {
            opened = false
        }

        // 仅在真正打开预览后抑制浏览窗。失败时绝不可留下 suppress，
        // 否则后续 Reveal/requestOpen 新建的标签会被 ExplorerBrowserWindowSuppressor 立刻关掉
        // （微信「在访达中显示」可预览文件却无法 resolve 时表现为完全无响应）。
        if opened {
            shouldSuppressExplorerWindows = true
        } else {
            shouldSuppressExplorerWindows = false
        }
        return opened
    }

    @discardableResult
    private func openPreviewWindow(for url: URL, additionalURLs: [URL] = []) -> Bool {
        guard let item = FileItem.resolveSelection(ids: [url.path], from: []).first else {
            return false
        }

        if let existing = PreviewSessionStore.shared.detachedSession(forFileID: item.id) {
            PreviewDetachCoordinator.shared.focusDetachedSession(existing)
            return true
        }

        guard let previewValue = makePreviewWindowValue(
            for: url,
            file: item,
            additionalURLs: additionalURLs
        ) else {
            return false
        }

        if let openPreviewWindow {
            openPreviewWindow(previewValue)
        } else {
            pendingPreviewWindows.append(previewValue)
        }

        return true
    }

    private func makePreviewWindowValue(
        for url: URL,
        file: FileItem,
        additionalURLs: [URL] = []
    ) -> PreviewWindowValue? {
        let parent = url.deletingLastPathComponent().path
        let directoryItems = directoryItemsForPreview(
            primaryURL: url,
            file: file,
            additionalURLs: additionalURLs
        )
        let options = PreviewStandaloneOpenPreferences.options(for: file)
        let sessionID = PreviewDetachCoordinator.shared.openStandalonePreview(
            file: file,
            directoryPath: parent,
            directoryItems: directoryItems,
            options: options
        )
        return PreviewWindowValue(
            sessionID: sessionID,
            fitImageToScreen: options.fitImageToScreen,
            initialWindowSize: options.initialWindowSize
        )
    }

    /// 列举同级目录可预览项，并合并外部多选 URL（供胶片条浏览）。
    private func directoryItemsForPreview(
        primaryURL: URL,
        file: FileItem,
        additionalURLs: [URL]
    ) -> [FileItem] {
        let parent = primaryURL.deletingLastPathComponent().path
        let listingOptions = DirectoryListingOptions.forPath(parent)
        var items = (try? DirectoryListingLoader.loadFileItems(
            at: parent,
            showHiddenFiles: false,
            options: listingOptions
        )) ?? []

        if !items.contains(where: { $0.id == file.id }) {
            items.append(file)
        }

        for url in additionalURLs where url != primaryURL {
            guard let item = FileItem.resolveSelection(ids: [url.path], from: items).first else {
                continue
            }
            if !items.contains(where: { $0.id == item.id }) {
                items.append(item)
            }
        }

        return items
    }

    private func flushPendingPreviewWindows() {
        guard let openPreviewWindow, !pendingPreviewWindows.isEmpty else { return }
        let pending = pendingPreviewWindows
        pendingPreviewWindows.removeAll()
        pending.forEach(openPreviewWindow)
    }
}

typealias ExternalImagePreviewOpenCenter = ExternalPreviewOpenCenter
