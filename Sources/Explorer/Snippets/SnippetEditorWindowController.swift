import AppKit
import SwiftUI

@MainActor
enum SnippetEditorWindowController {
    private static var editorWindow: NSWindow?

    static func present(
        snippet: Snippet?,
        draft: SnippetRecordingDraft? = nil,
        parentWindow: NSWindow? = nil,
        onSave: @escaping (Snippet) -> Void,
        onDelete: ((UUID) -> Void)? = nil,
        onExport: ((Snippet) -> Void)? = nil
    ) {
        if let editorWindow, editorWindow.isVisible {
            dismiss()
        }

        let resolvedParent = parentWindow ?? NSApp.keyWindow
        let rootView = SnippetEditorSheet(
            snippet: snippet,
            draft: draft,
            onSave: { saved in
                onSave(saved)
                dismiss()
            },
            onDelete: onDelete.map { delete in
                { id in
                    delete(id)
                    dismiss()
                }
            },
            onExport: onExport,
            onClose: dismiss
        )

        let hostingView = NSHostingView(rootView: rootView)
        let windowSize = NSSize(width: 820, height: 790)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = snippet == nil ? L10n.Snippets.Editor.newTitle : L10n.Snippets.Editor.editTitle
        window.minSize = NSSize(width: 480, height: 480)
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        SnippetEditorWindowPlacement.center(window, size: windowSize, relativeTo: resolvedParent)

        editorWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func dismiss() {
        editorWindow?.close()
        editorWindow = nil
    }
}

private enum SnippetEditorWindowPlacement {
    static func center(
        _ window: NSWindow,
        size: NSSize,
        relativeTo parentWindow: NSWindow?
    ) {
        guard let parentWindow else {
            window.center()
            return
        }
        let originX = parentWindow.frame.midX - size.width / 2
        let originY = parentWindow.frame.midY - size.height / 2
        window.setFrameOrigin(NSPoint(x: originX, y: originY))
    }
}
