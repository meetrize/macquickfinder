import AppKit
import SwiftUI

enum DirectoryContentSearchKeyboardAction: Equatable {
    case moveSelection(forward: Bool)
    case activateMatch
    case findNext
    case findPrevious
    case toggleGroupExpansion
    case showPreview
    case dismiss
}

enum DirectoryContentSearchKeyboard {
    static func action(for event: NSEvent) -> DirectoryContentSearchKeyboardAction? {
        if event.keyCode == 53 {
            return .dismiss
        }

        if event.modifierFlags.contains(.command),
           event.charactersIgnoringModifiers?.lowercased() == "g" {
            return event.modifierFlags.contains(.shift) ? .findPrevious : .findNext
        }

        guard !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.control),
              !event.modifierFlags.contains(.option) else {
            return nil
        }

        switch event.keyCode {
        case 125:
            return .moveSelection(forward: true)
        case 126:
            return .moveSelection(forward: false)
        case 123, 124:
            return .toggleGroupExpansion
        case 36, 76:
            return .activateMatch
        case 49:
            return .showPreview
        default:
            return nil
        }
    }
}

@MainActor
enum DirectoryContentSearchKeyboardPriority {
    private(set) static var isResultsNavigationActive = false
    private(set) static var isPreviewSearchFieldFocused = false

    static func setResultsNavigationActive(_ active: Bool) {
        isResultsNavigationActive = active
    }

    static func setPreviewSearchFieldFocused(_ active: Bool) {
        isPreviewSearchFieldFocused = active
    }
}

struct DirectoryContentSearchKeyboardMonitor: NSViewRepresentable {
    let isActive: Bool
    let onMoveSelection: (_ forward: Bool) -> Void
    let onActivateMatch: () -> Void
    let onFindNext: () -> Void
    let onFindPrevious: () -> Void
    let onToggleGroupExpansion: () -> Void
    let onShowPreview: () -> Void
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onMoveSelection: onMoveSelection,
            onActivateMatch: onActivateMatch,
            onFindNext: onFindNext,
            onFindPrevious: onFindPrevious,
            onToggleGroupExpansion: onToggleGroupExpansion,
            onShowPreview: onShowPreview,
            onDismiss: onDismiss
        )
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isActive = isActive
        context.coordinator.onMoveSelection = onMoveSelection
        context.coordinator.onActivateMatch = onActivateMatch
        context.coordinator.onFindNext = onFindNext
        context.coordinator.onFindPrevious = onFindPrevious
        context.coordinator.onToggleGroupExpansion = onToggleGroupExpansion
        context.coordinator.onShowPreview = onShowPreview
        context.coordinator.onDismiss = onDismiss
    }

    final class Coordinator {
        var isActive: Bool
        var onMoveSelection: (_ forward: Bool) -> Void
        var onActivateMatch: () -> Void
        var onFindNext: () -> Void
        var onFindPrevious: () -> Void
        var onToggleGroupExpansion: () -> Void
        var onShowPreview: () -> Void
        var onDismiss: () -> Void
        private var monitor: Any?

        init(
            onMoveSelection: @escaping (_ forward: Bool) -> Void,
            onActivateMatch: @escaping () -> Void,
            onFindNext: @escaping () -> Void,
            onFindPrevious: @escaping () -> Void,
            onToggleGroupExpansion: @escaping () -> Void,
            onShowPreview: @escaping () -> Void,
            onDismiss: @escaping () -> Void
        ) {
            self.isActive = false
            self.onMoveSelection = onMoveSelection
            self.onActivateMatch = onActivateMatch
            self.onFindNext = onFindNext
            self.onFindPrevious = onFindPrevious
            self.onToggleGroupExpansion = onToggleGroupExpansion
            self.onShowPreview = onShowPreview
            self.onDismiss = onDismiss
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
            guard let action = DirectoryContentSearchKeyboard.action(for: event) else { return event }
            let previewSearchFocused = MainActor.assumeIsolated {
                DirectoryContentSearchKeyboardPriority.isPreviewSearchFieldFocused
            }
            if (action == .findNext || action == .findPrevious), previewSearchFocused {
                return event
            }
            switch action {
            case .moveSelection(let forward):
                onMoveSelection(forward)
                return nil
            case .activateMatch:
                onActivateMatch()
                return nil
            case .findNext:
                onFindNext()
                return nil
            case .findPrevious:
                onFindPrevious()
                return nil
            case .toggleGroupExpansion:
                onToggleGroupExpansion()
                return nil
            case .showPreview:
                onShowPreview()
                return nil
            case .dismiss:
                onDismiss()
                return nil
            }
        }

        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
