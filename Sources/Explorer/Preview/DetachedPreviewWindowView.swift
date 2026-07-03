import AppKit
import Combine
import FileList
import SwiftUI

struct DetachedPreviewWindowView: View {
    let sessionID: PreviewSessionID
    var fitImageToScreen: Bool = false
    var initialWindowSize: CGSize? = nil

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
                    fitImageToScreen: fitImageToScreen,
                    initialWindowSize: initialWindowSize
                )
            } else {
                Text(L10n.Preview.sessionClosed)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: fitImageToScreen ? 0 : 320, minHeight: fitImageToScreen ? 0 : 240)
        .onDisappear {
            PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: sessionID)
        }
    }
}

private struct DetachedPreviewWindowContent: View {
    @ObservedObject var session: PreviewSession
    var fitImageToScreen: Bool
    var initialWindowSize: CGSize?
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
            browsePrevious: {
                session.browsePrevious()
                session.scheduleBrowseContentPrefetch(
                    settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
                )
            },
            browseNext: {
                session.browseNext()
                session.scheduleBrowseContentPrefetch(
                    settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
                )
            },
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
                    onRevealInFileList: {
                        PreviewDetachCoordinator.shared.revealFileInHostWindow(for: session)
                    },
                    onDock: session.allowsDockBack ? { dockAndDismiss() } : nil,
                    onClose: {
                        PreviewDetachCoordinator.shared.onDetachedWindowWillClose(sessionID: session.id)
                        dismiss()
                    }
                )
            )
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(2)

            Divider()

            FileContentView(session: session, appliesDetachedTextContentInsets: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)

            if let context = session.browseContext, context.canBrowse, session.isBrowserStripExpanded {
                Divider()
                PreviewBrowserStripView(context: context, session: session)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(2)
            }

            if let context = session.browseContext, context.canBrowse {
                Divider()
                PreviewBrowserNavBar(context: context, session: session)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(DetachedPreviewWindowTitleModifier(fitImageToScreen: fitImageToScreen, title: session.browseTarget.name))
        .previewSessionInteractions(session)
        .focusedValue(\.previewBrowseCommands, browseCommands)
        .background(
            PreviewDetachedKeyboardMonitor(session: session, onCloseWindow: closeDetachedWindow)
        )
        .background(DetachedPreviewWindowTracker(
            sessionID: session.id,
            fitImageToScreen: fitImageToScreen,
            initialWindowSize: initialWindowSize
        ))
        .background(
            DetachedPreviewWindowResizeMonitor(sessionID: session.id)
        )
        .background(
            DetachedPreviewWindowEdgeSnapMonitor(sessionID: session.id, fitImageToScreen: fitImageToScreen)
        )
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
            if fitImageToScreen {
                session.adaptImageToWindowOnResize = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    DetachedPreviewWindowFitApplier.applyIfNeeded(sessionID: session.id)
                }
            }
        }
        .onChange(of: previewBrowserSameTypeOnly) { newValue in
            session.browseContext?.setSameTypeOnly(newValue)
        }
        .onChange(of: session.browseContext?.currentIndex) { _ in
            session.scheduleBrowseContentPrefetch(
                settleDelayMilliseconds: PreviewBrowserStripMetrics.contentPrefetchImmediateDelay
            )
        }
        .onChange(of: session.isBrowserStripExpanded) { _ in
            guard fitImageToScreen || session.adaptImageToWindowOnResize else { return }
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

/// 外部打开时不使用系统 navigationTitle，避免与 PreviewChromeView 重叠遮挡。
private struct DetachedPreviewWindowTitleModifier: ViewModifier {
    let fitImageToScreen: Bool
    let title: String

    func body(content: Content) -> some View {
        if fitImageToScreen {
            content
        } else {
            content.navigationTitle(title)
        }
    }
}

private struct DetachedPreviewWindowTracker: NSViewRepresentable {
    let sessionID: PreviewSessionID
    var fitImageToScreen: Bool
    var initialWindowSize: CGSize?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
                ExternalPreviewOpenCenter.shared.clearSuppressExplorerWindows()
                context.coordinator.configureWindow(
                    window,
                    fitImageToScreen: fitImageToScreen,
                    initialWindowSize: initialWindowSize
                )
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                PreviewDetachCoordinator.shared.trackDetachedWindow(window)
                ExternalPreviewOpenCenter.shared.clearSuppressExplorerWindows()
                context.coordinator.configureWindow(
                    window,
                    fitImageToScreen: fitImageToScreen,
                    initialWindowSize: initialWindowSize
                )
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(sessionID: sessionID)
    }

    @MainActor
    final class Coordinator {
        let sessionID: PreviewSessionID
        private var didApplyInitialWindowSize = false
        private var didBeginInitialFit = false
        private var imageLoadCancellable: AnyCancellable?
        private var fitImageToScreen = false
        private var closeObserver: NSObjectProtocol?

        init(sessionID: PreviewSessionID) {
            self.sessionID = sessionID
        }

        deinit {
            if let closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }
        }

        func configureWindow(
            _ window: NSWindow,
            fitImageToScreen: Bool,
            initialWindowSize: CGSize?
        ) {
            self.fitImageToScreen = fitImageToScreen
            installCloseObserver(for: window)

            if fitImageToScreen {
                beginInitialFit(window: window)
            } else if let initialWindowSize, !didApplyInitialWindowSize {
                DetachedPreviewWindowSizer.applyInitialContentSize(to: window, contentSize: initialWindowSize)
                didApplyInitialWindowSize = true
            }
        }

        private func installCloseObserver(for window: NSWindow) {
            if let closeObserver {
                NotificationCenter.default.removeObserver(closeObserver)
            }
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor in
                    self?.persistWindowFrame(window)
                }
            }
        }

        private func persistWindowFrame(_ window: NSWindow) {
            guard !fitImageToScreen else { return }
            guard let session = PreviewSessionStore.shared.session(for: sessionID) else { return }
            let kind = PreviewDetachedWindowContentKind.from(file: session.file)
            PreviewDetachedWindowFrameStore.saveContentSize(window.contentLayoutRect.size, for: kind)
        }

        func beginInitialFit(window: NSWindow) {
            guard !didBeginInitialFit else { return }
            guard let session = PreviewSessionStore.shared.session(for: sessionID) else { return }

            if let pixelSize = ImageFileDimensionsReader.pixelSize(for: session.file.url) {
                applyInitialFit(window: window, session: session, pixelSize: pixelSize)
                didBeginInitialFit = true
            }

            imageLoadCancellable = session.image.$sourcePixelSize
                .filter { $0.width > 0 && $0.height > 0 }
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { [weak self, weak window] pixelSize in
                    guard let self, let window else { return }
                    self.applyInitialFit(window: window, session: session, pixelSize: pixelSize)
                    self.didBeginInitialFit = true
                }
        }

        private func applyInitialFit(window: NSWindow, session: PreviewSession, pixelSize: CGSize) {
            session.adaptImageToWindowOnResize = true
            session.image.zoomScale = 1.0
            DetachedPreviewWindowSizer.applyInitialFit(
                to: window,
                imagePixelSize: pixelSize,
                browserStripExpanded: session.isBrowserStripExpanded,
                canBrowse: session.browseContext?.canBrowse ?? false
            )
        }
    }
}
