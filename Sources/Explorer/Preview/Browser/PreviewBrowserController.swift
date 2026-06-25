import AppKit
import SwiftUI

@MainActor
enum PreviewBrowserController {
    static func handleKeyNavigation(event: NSEvent, session: PreviewSession) -> Bool {
        guard session.browseContext?.canBrowse == true else { return false }
        guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else { return false }

        let handled: Bool
        switch event.keyCode {
        case 123:
            handled = session.browsePrevious()
        case 124:
            handled = session.browseNext()
        default:
            return false
        }

        if handled {
            session.scheduleBrowseContentPrefetch()
        }
        return handled
    }
}

struct PreviewDetachedKeyboardMonitor: NSViewRepresentable {
    @ObservedObject var session: PreviewSession
    let onCloseWindow: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCloseWindow: onCloseWindow)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.session = session
        context.coordinator.onCloseWindow = onCloseWindow
    }

    @MainActor
    final class Coordinator {
        var session: PreviewSession?
        var onCloseWindow: () -> Void
        private var monitor: Any?

        init(onCloseWindow: @escaping () -> Void) {
            self.onCloseWindow = onCloseWindow
        }

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, let session = self.session else { return event }

                if PreviewDetachedDeleteController.handleDeleteKey(
                    event: event,
                    session: session,
                    onNoItemsRemaining: self.onCloseWindow
                ) {
                    return nil
                }

                if PreviewBrowserController.handleKeyNavigation(event: event, session: session) {
                    return nil
                }

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

// 保留旧名，避免其他引用处需要同步改动。
typealias PreviewBrowserKeyboardMonitor = PreviewDetachedKeyboardMonitor
