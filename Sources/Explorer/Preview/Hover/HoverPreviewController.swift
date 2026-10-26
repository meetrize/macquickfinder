import AppKit
import Combine
import Foundation
import FileList

/// 每窗悬停预览控制器：debounce、cancel、资格判定、单面板。
@MainActor
final class HoverPreviewController: ObservableObject {
    private let panel = HoverPreviewPanel()
    private var loadGeneration: UInt = 0
    private var debounceWorkItem: DispatchWorkItem?
    private var loadTask: Task<Void, Never>?
    private var enabled = false
    private var rightPanelVisible = false
    private var rightPanelURL: URL?
    private weak var lastAnchorWindow: NSWindow?
    private var lastRowID: String?

    func setEnabled(_ enabled: Bool) {
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        if !enabled {
            shutdown()
        }
    }

    func updateRightPanelContext(visible: Bool, previewURL: URL?) {
        rightPanelVisible = visible
        rightPanelURL = previewURL
    }

    func handleHoverRowChange(
        _ row: FileListRow?,
        anchor: NSView?,
        resolve: @escaping (FileListRow) -> FileItem?
    ) {
        guard enabled else {
            dismissNow()
            return
        }

        debounceWorkItem?.cancel()
        debounceWorkItem = nil

        guard let row, HoverPreviewEligibility.isCandidateRow(row), let anchor else {
            dismissNow()
            return
        }

        guard let item = resolve(row) else {
            dismissNow()
            return
        }

        lastAnchorWindow = anchor.window

        if row.id == lastRowID, panel.isVisible {
            panel.repositionNearMouse(window: anchor.window)
            return
        }

        lastRowID = row.id

        let work = DispatchWorkItem { [weak self] in
            self?.beginLoad(item: item, window: anchor.window)
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(
            deadline: .now() + HoverPreviewMetrics.showDelay,
            execute: work
        )
    }

    func notifyDragOrScrollBegan() {
        dismissNow()
    }

    func shutdown() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        lastRowID = nil
        lastAnchorWindow = nil
        panel.dismiss()
    }

    private func dismissNow() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        loadTask?.cancel()
        loadTask = nil
        loadGeneration += 1
        lastRowID = nil
        lastAnchorWindow = nil
        panel.dismiss()
    }

    private func beginLoad(item: FileItem, window: NSWindow?) {
        guard enabled else {
            dismissNow()
            return
        }
        guard HoverPreviewEligibility.shouldShow(
            for: item,
            rightPanelVisible: rightPanelVisible,
            rightPanelURL: rightPanelURL
        ) else {
            dismissNow()
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        lastAnchorWindow = window

        panel.present(fileName: item.name, payload: .placeholder, nearMouseIn: window)

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let payload = await HoverPreviewLoader.load(
                item: item,
                generation: generation,
                isCurrent: { [weak self] gen in
                    self?.loadGeneration == gen
                }
            )
            guard !Task.isCancelled else { return }
            guard self.loadGeneration == generation else { return }
            guard let payload else {
                self.panel.dismiss()
                return
            }
            self.panel.present(
                fileName: item.name,
                payload: payload,
                nearMouseIn: self.lastAnchorWindow
            )
        }
    }
}
