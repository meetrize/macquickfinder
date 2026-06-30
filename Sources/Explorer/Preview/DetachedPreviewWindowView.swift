import AppKit
import Combine
import FileList
import SwiftUI

struct DetachedPreviewWindowView: View {
    let sessionID: PreviewSessionID
    var fitImageToScreen: Bool = false

    @ObservedObject private var store = PreviewSessionStore.shared
    @Environment(\.dismiss) private var dismiss

    private var session: PreviewSession? {
        store.session(for: sessionID)
    }

    var body: some View {
        Group {
            if let session {
                DetachedPreviewWindowContent(
                    session: session,
                    fitImageToScreen: fitImageToScreen
                )
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
    var fitImageToScreen: Bool
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
                    onDock: session.allowsDockBack ? { dockAndDismiss() } : nil,
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
        .background(
            PreviewDetachedKeyboardMonitor(session: session, onCloseWindow: closeDetachedWindow)
        )
        .background(DetachedPreviewWindowTracker(sessionID: session.id, fitImageToScreen: fitImageToScreen))
        .background(
            Button(action: closeDetachedWindow) {
                EmptyView()
            }
            .keyboardShortcut(.cancelAction)
            .hidden()
            .accessibilityHidden(true)
        )
        .onAppear {
            session.browseContext?.setSameTypeOnly(previewBrowserSameTypeOnly)
        }
        .onChange(of: previewBrowserSameTypeOnly) { newValue in
            session.browseContext?.setSameTypeOnly(newValue)
        }
        .onChange(of: session.browseContext?.currentIndex) { _ in
            session.scheduleBrowseContentPrefetch()
        }
        .onChange(of: session.isBrowserStripExpanded) { _ in
            guard fitImageToScreen else { return }
            DetachedPreviewWindowFitApplier.applyIfNeeded(sessionID: session.id)
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

    private func closeDetachedWindow() {
        PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: session.id)
        dismiss()
    }
}

private struct DetachedPreviewWindowTracker: NSViewRepresentable {
    let sessionID: PreviewSessionID
    var fitImageToScreen: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
                ExternalImagePreviewOpenCenter.shared.clearSuppressExplorerWindows()
                if fitImageToScreen {
                    Task { @MainActor in
                        context.coordinator.applyInitialFitIfNeeded(window: window)
                    }
                }
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
                ExternalImagePreviewOpenCenter.shared.clearSuppressExplorerWindows()
                if fitImageToScreen {
                    Task { @MainActor in
                        context.coordinator.applyInitialFitIfNeeded(window: window)
                    }
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionID: sessionID, fitImageToScreen: fitImageToScreen)
    }

    @MainActor
    final class Coordinator {
        let sessionID: PreviewSessionID
        let fitImageToScreen: Bool
        private var didApplyInitialFit = false
        private var imageLoadCancellable: AnyCancellable?

        init(sessionID: PreviewSessionID, fitImageToScreen: Bool) {
            self.sessionID = sessionID
            self.fitImageToScreen = fitImageToScreen
        }

        @MainActor
        func applyInitialFitIfNeeded(window: NSWindow) {
            guard fitImageToScreen else { return }
            guard let session = PreviewSessionStore.shared.session(for: sessionID) else { return }

            if let pixelSize = ImageFileDimensionsReader.pixelSize(for: session.file.url) {
                applyFit(window: window, session: session, pixelSize: pixelSize)
                didApplyInitialFit = true
            }

            imageLoadCancellable = session.image.$sourcePixelSize
                .filter { $0.width > 0 && $0.height > 0 }
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak window] pixelSize in
                    guard let self, let window else { return }
                    self.applyFit(window: window, session: session, pixelSize: pixelSize)
                    self.didApplyInitialFit = true
                }
        }

        @MainActor
        private func applyFit(window: NSWindow, session: PreviewSession, pixelSize: CGSize) {
            session.image.zoomScale = 1.0
            DetachedPreviewWindowSizer.apply(
                to: window,
                imagePixelSize: pixelSize,
                browserStripExpanded: session.isBrowserStripExpanded,
                canBrowse: session.browseContext?.canBrowse ?? false
            )
        }
    }
}
