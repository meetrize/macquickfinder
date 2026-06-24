import AppKit
import FileList
import SwiftUI

struct DetachedPreviewWindowView: View {
    let sessionID: PreviewSessionID

    @ObservedObject private var store = PreviewSessionStore.shared
    @Environment(\.dismiss) private var dismiss

    private var session: PreviewSession? {
        store.session(for: sessionID)
    }

    var body: some View {
        Group {
            if let session {
                DetachedPreviewWindowContent(session: session)
            } else {
                Text(L10n.Preview.sessionClosed)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 320, minHeight: 240)
        .onDisappear {
            PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: sessionID)
        }
    }
}

private struct DetachedPreviewWindowContent: View {
    @ObservedObject var session: PreviewSession
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppPreferences.Preview.browserSameTypeOnly)
    private var previewBrowserSameTypeOnly = false

    private var browseCommands: PreviewBrowseCommands {
        guard let context = session.browseContext, context.canBrowse else {
            return PreviewBrowseCommands()
        }
        return PreviewBrowseCommands(
            canBrowsePrevious: context.currentIndex > 0,
            canBrowseNext: context.currentIndex + 1 < context.count,
            browsePrevious: { session.browsePrevious(); session.scheduleBrowseContentPrefetch() },
            browseNext: { session.browseNext(); session.scheduleBrowseContentPrefetch() },
            canToggleStrip: true,
            isStripExpanded: session.isBrowserStripExpanded,
            toggleStrip: { session.isBrowserStripExpanded.toggle() }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            PreviewChromeView(
                session: session,
                title: session.browseTarget.name,
                titleMaxWidth: 160,
                isContentCollapsed: false,
                placement: .detachedWindow,
                actions: PreviewChromeActions(
                    onBackFromFolderChild: { session.folderInlineChild = nil },
                    onDock: { dockAndDismiss() },
                    onClose: {
                        PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: session.id)
                        dismiss()
                    }
                )
            )

            Divider()

            FileContentView(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let context = session.browseContext, context.canBrowse, session.isBrowserStripExpanded {
                Divider()
                PreviewBrowserStripView(context: context, session: session)
            }

            if let context = session.browseContext, context.canBrowse {
                Divider()
                PreviewBrowserNavBar(context: context, session: session)
            }
        }
        .navigationTitle(session.browseTarget.name)
        .previewSessionInteractions(session)
        .focusedValue(\.previewBrowseCommands, browseCommands)
        .background(PreviewBrowserKeyboardMonitor(session: session))
        .background(DetachedPreviewWindowTracker(sessionID: session.id))
        .onAppear {
            session.browseContext?.setSameTypeOnly(previewBrowserSameTypeOnly)
        }
        .onChange(of: previewBrowserSameTypeOnly) { newValue in
            session.browseContext?.setSameTypeOnly(newValue)
        }
        .onChange(of: session.browseContext?.currentIndex) { _ in
            session.scheduleBrowseContentPrefetch()
        }
    }

    private func dockAndDismiss() {
        Task {
            let docked = await PreviewDetachCoordinator.shared.dockBack(
                sessionID: session.id,
                currentSelectedFileID: nil
            )
            if docked { dismiss() }
        }
    }
}

private struct DetachedPreviewWindowTracker: NSViewRepresentable {
    let sessionID: PreviewSessionID

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
            }
        }
    }
}
