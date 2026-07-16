import SwiftUI

/// 将粘贴进度观察隔离在子视图，避免 `PasteOperationCenter` 刷新整棵 ContentView。
struct PasteProgressBannerOverlay: View {
    @ObservedObject private var pasteOperationCenter = PasteOperationCenter.shared
    var transientNoticeMessage: String?

    var body: some View {
        VStack(spacing: 8) {
            if let pasteProgress = pasteOperationCenter.activeProgress {
                pasteProgressBanner(pasteProgress)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let transientNoticeMessage {
                Text(transientNoticeMessage)
                    .font(.callout)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.bottom, 12)
        .animation(.easeInOut(duration: 0.2), value: transientNoticeMessage)
        .animation(.easeInOut(duration: 0.2), value: pasteOperationCenter.activeProgress)
    }

    @ViewBuilder
    private func pasteProgressBanner(_ progress: PasteOperationCenter.ActiveProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(progress.message)
                .font(.callout)
                .lineLimit(2)
            if progress.showsDeterminateProgress, let fraction = progress.progressFraction {
                ProgressView(value: fraction)
                    .progressViewStyle(.linear)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
            }
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// 将连接服务器 Sheet 触发隔离在子视图，避免 `ConnectServerCenter` 刷新整棵 ContentView。
struct ConnectServerSheetPresenter: ViewModifier {
    @ObservedObject private var connectServerCenter = ConnectServerCenter.shared
    @Binding var isPresented: Bool
    let hostWindow: NSWindow?
    let onMounted: (URL) -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: connectServerCenter.presentSheetToken) { _ in
                guard hostWindow == NSApp.keyWindow else { return }
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                ConnectServerSheet(
                    initialAddress: RecentServersStore.shared.bookmarks.first?.urlString ?? ""
                ) { mountURL in
                    onMounted(mountURL)
                }
            }
    }
}

extension View {
    func connectServerSheet(
        isPresented: Binding<Bool>,
        hostWindow: NSWindow?,
        onMounted: @escaping (URL) -> Void
    ) -> some View {
        modifier(
            ConnectServerSheetPresenter(
                isPresented: isPresented,
                hostWindow: hostWindow,
                onMounted: onMounted
            )
        )
    }
}

/// 本地快捷键监视：自行观察输出面板编辑态与快捷键设置，避免抬升到 ContentView 根。
struct ContentViewLocalShortcutMonitors: View {
    @ObservedObject private var outputPanelTextEditing = OutputPanelTextEditingCenter.shared
    @ObservedObject private var shortcutSettings = ShortcutSettingsStore.shared

    let isBarOrRenameEditing: Bool
    let onNewWindow: () -> Void
    let onNewTab: () -> Void
    let onCopyPaths: () -> Void

    private var isAnyTextFieldEditing: Bool {
        isBarOrRenameEditing || outputPanelTextEditing.isActive
    }

    var body: some View {
        Group {
            LocalShortcutMonitor(
                binding: ShortcutBinding(keyCode: 45, modifiers: .command),
                isEnabled: !isAnyTextFieldEditing
            ) {
                onNewWindow()
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            LocalShortcutMonitor(
                binding: shortcutSettings.newTabBinding,
                isEnabled: !isAnyTextFieldEditing
            ) {
                onNewTab()
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)

            LocalShortcutMonitor(
                binding: shortcutSettings.copyPathBinding,
                isEnabled: !isAnyTextFieldEditing
            ) {
                onCopyPaths()
            }
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
}
