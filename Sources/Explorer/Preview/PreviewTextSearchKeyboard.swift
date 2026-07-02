import AppKit
import SwiftUI

enum PreviewTextSearchKeyboardAction: Equatable {
    case findNext
    case findPrevious
    case clear
}

enum PreviewTextSearchKeyboard {
    /// 预览搜索框内快捷键：Esc、⌘G、⇧⌘G。
    static func action(for event: NSEvent) -> PreviewTextSearchKeyboardAction? {
        if event.keyCode == 53 {
            return .clear
        }
        guard event.modifierFlags.contains(.command) else { return nil }
        guard event.charactersIgnoringModifiers?.lowercased() == "g" else { return nil }
        return event.modifierFlags.contains(.shift) ? .findPrevious : .findNext
    }
}

/// 搜索框聚焦时拦截 ⌘G / ⇧⌘G / Esc（field editor 场景下 performKeyEquivalent 可能收不到）。
struct PreviewTextSearchFieldKeyMonitor: NSViewRepresentable {
    let isActive: Bool
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onClear: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFindNext: onFindNext, onFindPrevious: onFindPrevious, onClear: onClear)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onFindNext = onFindNext
        context.coordinator.onFindPrevious = onFindPrevious
        context.coordinator.onClear = onClear
    }

    final class Coordinator {
        var isActive: Bool
        var onFindNext: () -> Void
        var onFindPrevious: () -> Void
        var onClear: () -> Void
        private var monitor: Any?

        init(onFindNext: @escaping () -> Void, onFindPrevious: @escaping () -> Void, onClear: @escaping () -> Void) {
            self.isActive = false
            self.onFindNext = onFindNext
            self.onFindPrevious = onFindPrevious
            self.onClear = onClear
        }

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }

        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            guard isActive else { return event }
            switch PreviewTextSearchKeyboard.action(for: event) {
            case .findNext:
                onFindNext()
                return nil
            case .findPrevious:
                onFindPrevious()
                return nil
            case .clear:
                onClear()
                return nil
            case nil:
                return event
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
