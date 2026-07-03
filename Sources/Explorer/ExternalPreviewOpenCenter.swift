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

        shouldSuppressExplorerWindows = true

        let app = NSApplication.shared
        app.unhide(nil)
        app.activate(ignoringOtherApps: true)

        let imageURLs = ExternalImageFileClassifier.imageURLs(from: previewableURLs)
        let openOneWindowPerImage = previewableURLs.count > 1
            && imageURLs.count == previewableURLs.count
            && PreviewOpenPreferences.externalMultiImageOpen == .oneWindowPerFile

        if openOneWindowPerImage {
            var openedAny = false
            for url in previewableURLs {
                if openPreviewWindow(for: url) {
                    openedAny = true
                }
            }
            if !openedAny {
                shouldSuppressExplorerWindows = false
            }
            return openedAny
        }

        guard let firstURL = previewableURLs.first else {
            shouldSuppressExplorerWindows = false
            return false
        }
        return openPreviewWindow(for: firstURL)
    }

    @discardableResult
    private func openPreviewWindow(for url: URL) -> Bool {
        guard let item = FileItem.resolveSelection(ids: [url.path], from: []).first else {
            return false
        }

        if let existing = PreviewSessionStore.shared.detachedSession(forFileID: item.id) {
            PreviewDetachCoordinator.shared.focusDetachedSession(existing)
            return true
        }

        guard let previewValue = makePreviewWindowValue(for: url, file: item) else {
            return false
        }

        if let openPreviewWindow {
            openPreviewWindow(previewValue)
        } else {
            pendingPreviewWindows.append(previewValue)
        }

        return true
    }

    private func makePreviewWindowValue(for url: URL, file: FileItem) -> PreviewWindowValue? {
        let parent = url.deletingLastPathComponent().path
        let options = PreviewStandaloneOpenPreferences.options(for: file)
        let sessionID = PreviewDetachCoordinator.shared.openStandalonePreview(
            file: file,
            directoryPath: parent,
            directoryItems: [file],
            options: options
        )
        return PreviewWindowValue(
            sessionID: sessionID,
            fitImageToScreen: options.fitImageToScreen,
            initialWindowSize: options.initialWindowSize
        )
    }

    private func flushPendingPreviewWindows() {
        guard let openPreviewWindow, !pendingPreviewWindows.isEmpty else { return }
        let pending = pendingPreviewWindows
        pendingPreviewWindows.removeAll()
        pending.forEach(openPreviewWindow)
    }
}

typealias ExternalImagePreviewOpenCenter = ExternalPreviewOpenCenter
