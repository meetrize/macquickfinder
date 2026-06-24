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
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(isContentCollapsed ? "展开预览" : "折叠预览")
            }

            if session.isShowingFolderChildPreview {
                Button(action: actions.onBackFromFolderChild) {
                    Image(systemName: "arrow.uturn.backward")
                }
                .buttonStyle(.borderless)
                .instantHoverTooltip("返回文件夹")
            }

            Text(title)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(minWidth: 0, maxWidth: titleMaxWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(-1)

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
                Button(action: onDetach) {
                    Image(systemName: "macwindow.badge.plus")
                }
                .buttonStyle(.borderless)
                .instantHoverTooltip("在独立窗口中打开")
                .fixedSize()
                .layoutPriority(2)
            }

            if placement == .detachedWindow, let onDock = actions.onDock {
                Button(action: onDock) {
                    Image(systemName: "sidebar.right")
                }
                .buttonStyle(.borderless)
                .instantHoverTooltip("收回侧栏")
                .fixedSize()
                .layoutPriority(2)
            }

            Button(action: actions.onClose) {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .instantHoverTooltip(placement == .detachedWindow ? "关闭窗口" : "关闭预览")
            .fixedSize()
            .layoutPriority(2)
        }
        .frame(height: PanelTopBarMetrics.contentHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .padding(.horizontal, 10)
        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
    }
}
