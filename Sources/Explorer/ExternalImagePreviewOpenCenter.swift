import AppKit
import Foundation

@MainActor
final class ExternalImagePreviewOpenCenter: ObservableObject {
    static let shared = ExternalImagePreviewOpenCenter()

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

    /// 若 URL 中含可预览图片，则打开独立预览窗并返回 `true`。
    @discardableResult
    func tryOpen(urls: [URL]) -> Bool {
        let imageURLs = ExternalImageFileClassifier.imageURLs(from: urls)
        guard imageURLs.first != nil else { return false }

        shouldSuppressExplorerWindows = true

        let app = NSApplication.shared
        app.unhide(nil)
        app.activate(ignoringOtherApps: true)

        let previewValues = imageURLs.compactMap { url -> PreviewWindowValue? in
            guard let item = FileItem.resolveSelection(ids: [url.path], from: []).first else {
                return nil
            }
            let parent = url.deletingLastPathComponent().path
            let items = (try? DirectoryListingLoader.loadFileItems(
                at: parent,
                showHiddenFiles: false
            )) ?? [item]
            let sessionID = PreviewDetachCoordinator.shared.openStandaloneImagePreview(
                file: item,
                directoryPath: parent,
                directoryItems: items
            )
            return PreviewWindowValue(sessionID: sessionID, fitImageToScreen: true)
        }

        guard !previewValues.isEmpty else {
            shouldSuppressExplorerWindows = false
            return false
        }

        if let openPreviewWindow {
            previewValues.forEach(openPreviewWindow)
        } else {
            pendingPreviewWindows.append(contentsOf: previewValues)
        }

        return true
    }

    private func flushPendingPreviewWindows() {
        guard let openPreviewWindow, !pendingPreviewWindows.isEmpty else { return }
        let pending = pendingPreviewWindows
        pendingPreviewWindows.removeAll()
        pending.forEach(openPreviewWindow)
    }
}
