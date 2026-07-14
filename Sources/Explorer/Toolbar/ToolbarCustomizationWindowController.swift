import AppKit
import SwiftUI

@MainActor
enum ToolbarCustomizationWindowController {
    private static var customizationWindow: NSWindow?
    private static var delegateHolder: WindowDelegate?
    private static var pendingFinishAction: FinishAction = .cancel
    /// 关闭后延迟执行的 commit/cancel；再次 present 前必须先冲刷，避免与 begin 竞态。
    private static var deferredFinishWork: (() -> Void)?

    private enum FinishAction {
        case commit
        case cancel
    }

    static var activeWindow: NSWindow? { customizationWindow }

    static func present(
        store: ToolbarCustomizationStore,
        environment: ExplorerToolbarEnvironment,
        parentWindow: NSWindow?
    ) {
        flushDeferredFinishWork()

        if let customizationWindow, customizationWindow.isVisible {
            ToolbarWindowPlacement.attachAsChild(customizationWindow, to: parentWindow)
            customizationWindow.makeKeyAndOrderFront(nil)
            customizationWindow.makeFirstResponder(nil)
            if !store.isCustomizing {
                store.beginCustomization()
            }
            return
        }

        pendingFinishAction = .cancel

        let rootView = ToolbarCustomizationPanelView(
            store: store,
            environment: environment
        )

        let hostingView = NSHostingView(rootView: rootView)
        let windowSize = NSSize(width: 600, height: 168)

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = L10n.Toolbar.customizeTitle
        window.isReleasedWhenClosed = false
        window.contentView = hostingView
        hostingView.frame = window.contentView?.bounds ?? .zero
        hostingView.autoresizingMask = [.width, .height]

        let delegate = WindowDelegate(store: store, parentWindow: parentWindow) {
            customizationWindow = nil
            delegateHolder = nil
        }
        window.delegate = delegate
        delegateHolder = delegate

        ToolbarWindowPlacement.center(window, size: windowSize, relativeTo: parentWindow)
        ToolbarWindowPlacement.attachAsChild(window, to: parentWindow)

        customizationWindow = window
        // 先亮出自定义窗，再在下一帧切换工具栏编辑态，避免菜单点击被主窗口整栏重建卡住。
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(nil)

        DispatchQueue.main.async {
            guard customizationWindow === window, window.isVisible else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                store.beginCustomization()
            }
        }
    }

    static func finish(committing: Bool) {
        pendingFinishAction = committing ? .commit : .cancel
        dismiss()
    }

    static func dismiss() {
        ToolbarOpenAppEditorWindowController.dismiss()
        guard let window = customizationWindow else {
            flushDeferredFinishWork()
            return
        }
        if let parent = window.parent {
            parent.removeChildWindow(window)
        }
        window.close()
    }

    private static func flushDeferredFinishWork() {
        let work = deferredFinishWork
        deferredFinishWork = nil
        work?()
    }

    private static func scheduleDeferredFinish(store: ToolbarCustomizationStore, action: FinishAction) {
        deferredFinishWork = {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                switch action {
                case .commit:
                    store.commitCustomization()
                case .cancel:
                    store.cancelCustomization()
                }
            }
        }
        DispatchQueue.main.async {
            flushDeferredFinishWork()
        }
    }

    private final class WindowDelegate: NSObject, NSWindowDelegate {
        private let store: ToolbarCustomizationStore
        private let onClosed: () -> Void
        private var parentCloseObserver: NSObjectProtocol?
        private var didHandleClose = false

        init(
            store: ToolbarCustomizationStore,
            parentWindow: NSWindow?,
            onClosed: @escaping () -> Void
        ) {
            self.store = store
            self.onClosed = onClosed
            super.init()

            guard let parentWindow else { return }
            parentCloseObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: parentWindow,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    ToolbarCustomizationWindowController.dismiss()
                }
            }
        }

        func windowWillClose(_ notification: Notification) {
            guard !didHandleClose else { return }
            didHandleClose = true

            ToolbarOpenAppEditorWindowController.dismiss()
            let action = ToolbarCustomizationWindowController.pendingFinishAction
            ToolbarCustomizationWindowController.pendingFinishAction = .cancel
            onClosed()

            // 先让关闭返回，再改工具栏模式，取消按钮手感会更轻。
            ToolbarCustomizationWindowController.scheduleDeferredFinish(store: store, action: action)
        }

        deinit {
            if let parentCloseObserver {
                NotificationCenter.default.removeObserver(parentCloseObserver)
            }
        }
    }
}
