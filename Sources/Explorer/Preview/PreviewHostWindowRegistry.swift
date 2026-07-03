import AppKit

/// 将 `PreviewSession.hostWindowID` 映射到对应的 Explorer 窗口，供独立预览窗定位回文件列表。
@MainActor
final class PreviewHostWindowRegistry {
    static let shared = PreviewHostWindowRegistry()

    private struct WeakWindow {
        weak var window: NSWindow?
    }

    private var windows: [UUID: WeakWindow] = [:]

    private init() {}

    func register(hostWindowID: UUID, window: NSWindow) {
        windows[hostWindowID] = WeakWindow(window: window)
    }

    func unregister(hostWindowID: UUID) {
        windows.removeValue(forKey: hostWindowID)
    }

    func window(for hostWindowID: UUID) -> NSWindow? {
        windows[hostWindowID]?.window
    }
}
