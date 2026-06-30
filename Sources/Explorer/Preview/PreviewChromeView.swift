import SwiftUI
import FileList

enum PreviewChromePlacement {
    case inlinePanel
    case detachedWindow
}

struct PreviewChromeActions {
    var onToggleCollapse: (() -> Void)?
    var onBackFromFolderChild: () -> Void = {}
    var onDetach: (() -> Void)?
    var onDock: (() -> Void)?
    var onClose: () -> Void
}

/// 内联侧栏与独立窗口共用的预览顶栏（标题 + 溢出工具栏 + 窗口动作）。
struct PreviewChromeView: View {
    @ObservedObject var session: PreviewSession
    let title: String
    let titleMaxWidth: CGFloat
    let isContentCollapsed: Bool
    let placement: PreviewChromePlacement
    let actions: PreviewChromeActions

    private var showsToolbarItems: Bool {
        switch placement {
        case .inlinePanel:
            return !isContentCollapsed
        case .detachedWindow:
            return true
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if placement == .inlinePanel, let onToggleCollapse = actions.onToggleCollapse {
                Button(action: onToggleCollapse) {
                    Image(systemName: isContentCollapsed ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .focusable(false)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(isContentCollapsed ? L10n.Preview.Chrome.expand : L10n.Preview.Chrome.collapse)
            }

            if session.isShowingFolderChildPreview {
                PreviewFocuslessIconButton(
                    systemImageName: "arrow.uturn.backward",
                    accessibilityLabel: L10n.Preview.Chrome.backToFolder,
                    action: actions.onBackFromFolderChild
                )
                .instantHoverTooltip(L10n.Preview.Chrome.backToFolder)
            }

            Text(title)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: titleMaxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(-1)

            if let archiveSelectionCaption = session.archiveSelectionCaption {
                Text(archiveSelectionCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(0)
            }

            if showsToolbarItems,
               let item = session.toolbarFileItem,
               session.showsPreviewTextSearch(for: item) {
                PreviewTextSearchToolbarControls(session: session)
                    .layoutPriority(3)
            }

            if showsToolbarItems, let item = session.toolbarFileItem {
                PreviewToolbarOverflowLayout(
                    spacing: 4,
                    items: session.previewToolbarItems(for: item)
                )
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                .layoutPriority(1)
            } else {
                Spacer(minLength: 0)
            }

            if placement == .inlinePanel, let onDetach = actions.onDetach {
                PreviewFocuslessIconButton(
                    systemImageName: "macwindow.badge.plus",
                    accessibilityLabel: L10n.Preview.Chrome.detach,
                    action: onDetach
                )
                .instantHoverTooltip(L10n.Preview.Chrome.detach)
                .fixedSize()
                .layoutPriority(2)
            }

            if placement == .detachedWindow, let onDock = actions.onDock {
                PreviewFocuslessIconButton(
                    systemImageName: "sidebar.right",
                    accessibilityLabel: L10n.Preview.Chrome.dockBack,
                    action: onDock
                )
                .instantHoverTooltip(L10n.Preview.Chrome.dockBack)
                .fixedSize()
                .layoutPriority(2)
            }

            if placement == .detachedWindow {
                PreviewFocuslessIconButton(
                    systemImageName: "xmark",
                    accessibilityLabel: L10n.Preview.Chrome.closeWindow,
                    action: actions.onClose
                )
                .instantHoverTooltip(L10n.Preview.Chrome.closeWindow)
                .fixedSize()
                .layoutPriority(2)
            } else {
                PreviewFocuslessIconButton(
                    systemImageName: "xmark",
                    accessibilityLabel: L10n.Preview.Chrome.closePreview,
                    action: actions.onClose
                )
                .instantHoverTooltip(L10n.Preview.Chrome.closePreview)
                .fixedSize()
                .layoutPriority(2)
            }
        }
        .frame(height: PanelTopBarMetrics.contentHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .padding(.horizontal, 10)
        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
    }
}
