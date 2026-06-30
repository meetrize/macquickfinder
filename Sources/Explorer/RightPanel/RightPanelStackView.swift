import SwiftUI

struct RightPanelStackView: View {
    @ObservedObject var layout: ExplorerWindowLayoutState

    let hostWindowID: UUID
    let selection: Set<FileItem.ID>
    let items: [FileItem]
    let cwd: String
    let sortOrder: SortOrder
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    let directoryMetadataOverlay: DirectoryMetadataOverlay
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
            let layoutInput = heightInput(totalHeight: totalHeight)
            let showResizeDivider = RightPanelHeightCalculator.shouldShowResizeDivider(for: layoutInput)
            let effectivePreviewHeight = RightPanelHeightCalculator.previewHeight(for: layoutInput)

            VStack(spacing: 0) {
                if layout.showPreview {
                    FilePreviewView(
                        hostWindowID: hostWindowID,
                        showPreview: $layout.showPreview,
                        layout: layout,
                        selection: selection,
                        items: items,
                        directoryPath: cwd,
                        sortOrder: sortOrder,
                        showHiddenFiles: showHiddenFiles,
                        autoCalculateDirectorySizes: autoCalculateDirectorySizes,
                        metadataOverlay: directoryMetadataOverlay,
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(nil, value: effectivePreviewHeight)
            .onChange(of: layout.showPreview) { isVisible in
                if !isVisible {
                    PreviewSessionStore.shared.removeInlineSessions(forHostWindowID: hostWindowID)
                }
            }
        }
    }

    private func heightInput(totalHeight: CGFloat) -> RightPanelHeightCalculator.Input {
        RightPanelHeightCalculator.Input(
            totalHeight: totalHeight,
            showPreview: layout.showPreview,
            showSnippets: layout.showSnippets,
            isPreviewContentCollapsed: layout.isPreviewContentCollapsed,
            isSnippetsContentCollapsed: layout.isSnippetsContentCollapsed,
            previewSnippetsSplitRatio: layout.previewSnippetsSplitRatio,
            dragPreviewHeight: dragPreviewHeight,
            dividerHeight: VerticalResizeDividerMetrics.hitHeight,
            previewMinHeight: previewMinHeight,
            snippetsMinHeight: snippetsMinHeight,
            collapsedTitleBarHeight: PanelTopBarMetrics.totalHeight
        )
    }
}

enum PanelTopBarMetrics {
    static let contentHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 6
    static var totalHeight: CGFloat { contentHeight + verticalPadding * 2 }
}

enum OutputPanelMetrics {
    static let titleBarHeight: CGFloat = 26
    static let titleBarChipHeight: CGFloat = 18
    static let titleBarIconWidth: CGFloat = 22
}
