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

struct PreviewBrowserKeyboardMonitor: NSViewRepresentable {
    @ObservedObject var session: PreviewSession

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.install(on: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.session = session
        context.coordinator.isEnabled = session.browseContext?.canBrowse == true
    }

    @MainActor
    final class Coordinator {
        var session: PreviewSession?
        var isEnabled = false
        private var monitor: Any?

        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled, let session = self.session else { return event }
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
