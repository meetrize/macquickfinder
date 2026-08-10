import AppKit
import Combine
import Foundation
import FileList

/// 剪贴板粘贴可用性缓存：轮询 `changeCount` 并 debounce 刷新，避免 SwiftUI 每帧读盘。
@MainActor
final class PasteboardPasteAvailability: ObservableObject {
    static let shared = PasteboardPasteAvailability()

    private(set) var cachedState: FileOperations.PasteboardState?
    private(set) var hasCreatableContent = false
    /// 当前剪切态文件路径（含 standardized）；非剪切或剪贴板清空时为空。
    @Published private(set) var cutItemPaths: Set<String> = []

    private var debounceWorkItem: DispatchWorkItem?
    private var pollTimer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var observers: [NSObjectProtocol] = []

    private init() {}

    func install() {
        guard pollTimer == nil else { return }

        let center = NotificationCenter.default
        observers.append(
            center.addObserver(
                forName: NSApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshNow()
                    self?.startPolling()
                }
            }
        )
        observers.append(
            center.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.stopPolling()
                }
            }
        )

        refreshNow()
        startPolling()
    }

    func scheduleRefresh() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refreshNow()
        }
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    func refreshNow() {
        lastChangeCount = NSPasteboard.general.changeCount
        cachedState = FileOperations.pasteboardState()
        hasCreatableContent = ClipboardFileCreation.contentKind() != nil
        let nextCutPaths: Set<String>
        if let state = cachedState, state.isCut {
            nextCutPaths = FileListCutAppearance.pathSet(from: state.urls)
        } else {
            nextCutPaths = []
        }
        if nextCutPaths != cutItemPaths {
            cutItemPaths = nextCutPaths
        }
        objectWillChange.send()
    }

    func canPaste(to destinationDirectory: URL) -> Bool {
        guard let state = cachedState else { return false }
        return FileOperations.canPaste(with: state, to: destinationDirectory, hasCreatableContent: hasCreatableContent)
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollPasteboardIfNeeded()
            }
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollPasteboardIfNeeded() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        scheduleRefresh()
    }
}
