import SwiftUI

struct RightPanelStackView: View {
    @ObservedObject var layout: ExplorerWindowLayoutState

    let selection: Set<FileItem.ID>
    let items: [FileItem]
    let cwd: String
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    let directorySizeOverlay: DirectorySizeOverlay
    let directoryItemCountOverlay: DirectoryItemCountOverlay
    let panelWidth: CGFloat
    let onNavigate: (String) -> Void
    let onOpenItem: (FileItem) -> Void
    let onOpenTerminalAtPath: (String) -> Void

    @State private var dragPreviewHeight: CGFloat?

    private var previewMinHeight: CGFloat {
        layout.isPreviewContentCollapsed ? PanelTopBarMetrics.totalHeight : 80
    }

    private var snippetsMinHeight: CGFloat {
        layout.isSnippetsContentCollapsed ? PanelTopBarMetrics.totalHeight : 80
    }

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let showBoth = layout.showPreview && layout.showSnippets
            let showResizeDivider = showBoth && !layout.isSnippetsContentCollapsed && !layout.isPreviewContentCollapsed
            let storedPreviewHeight = clampedPreviewHeight(
                totalHeight * CGFloat(layout.previewSnippetsSplitRatio),
                totalHeight: totalHeight
            )
            let previewHeight = dragPreviewHeight ?? storedPreviewHeight
            let expandedPreviewHeight: CGFloat = {
                // Snippets 折叠后只占一个标题栏：预览应自动撑满剩余空间
                if showBoth, layout.isSnippetsContentCollapsed, !layout.isPreviewContentCollapsed {
                    return max(previewMinHeight, totalHeight - snippetsMinHeight)
                }
                return previewHeight
            }()
            let effectivePreviewHeight = layout.isPreviewContentCollapsed
                ? PanelTopBarMetrics.totalHeight
                : expandedPreviewHeight

            VStack(spacing: 0) {
                if layout.showPreview {
                    FilePreviewView(
                        showPreview: $layout.showPreview,
                        layout: layout,
                        selection: selection,
                        items: items,
                        showHiddenFiles: showHiddenFiles,
                        autoCalculateDirectorySizes: autoCalculateDirectorySizes,
                        directorySizeOverlay: directorySizeOverlay,
                        directoryItemCountOverlay: directoryItemCountOverlay,
                        onNavigate: onNavigate,
                        onOpenItem: onOpenItem,
                        onOpenTerminalAtPath: onOpenTerminalAtPath
                    )
                    .frame(height: effectivePreviewHeight)
                }

                if showResizeDivider {
                    VerticalResizeDivider(
                        previewHeight: effectivePreviewHeight,
                        totalHeight: totalHeight,
                        minTopHeight: previewMinHeight,
                        minBottomHeight: snippetsMinHeight,
                        onHeightChange: { dragPreviewHeight = $0 },
                        onDragEnded: { finalHeight in
                            guard totalHeight > 0 else {
                                dragPreviewHeight = nil
                                return
                            }
                            layout.previewSnippetsSplitRatio = Double(finalHeight / totalHeight)
                            dragPreviewHeight = nil
                        }
                    )
                    .frame(height: VerticalResizeDividerMetrics.hitHeight)
                }

                if layout.showSnippets {
                    SnippetsPanelView(
                        showSnippets: $layout.showSnippets,
                        layout: layout,
                        selection: selection,
                        items: items,
                        cwd: cwd,
                        showHiddenFiles: showHiddenFiles,
                        panelWidth: panelWidth
                    )
                    .frame(maxHeight: .infinity)
                }
            }
            .animation(nil, value: effectivePreviewHeight)
        }
    }

    private func clampedPreviewHeight(_ height: CGFloat, totalHeight: CGFloat) -> CGFloat {
        guard totalHeight > 0 else { return 80 }
        let divider = layout.showPreview && layout.showSnippets && !layout.isSnippetsContentCollapsed && !layout.isPreviewContentCollapsed
            ? VerticalResizeDividerMetrics.hitHeight
            : 0
        let maxTop = max(previewMinHeight, totalHeight - snippetsMinHeight - divider)
        return min(max(height, previewMinHeight), maxTop)
    }
}

enum PanelTopBarMetrics {
    static let contentHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 6
    static var totalHeight: CGFloat { contentHeight + verticalPadding * 2 }
}

enum OutputPanelMetrics {
    static let titleBarHeight: CGFloat = 32
}
