import AppKit
import Combine
import Foundation

/// 剪贴板粘贴可用性缓存：轮询 `changeCount` 并 debounce 刷新，避免 SwiftUI 每帧读盘。
@MainActor
final class PasteboardPasteAvailability: ObservableObject {
    static let shared = PasteboardPasteAvailability()

    private(set) var cachedState: FileOperations.PasteboardState?
    private(set) var hasCreatableContent = false

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
