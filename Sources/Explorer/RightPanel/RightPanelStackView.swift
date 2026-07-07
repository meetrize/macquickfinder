import SwiftUI

struct RightPanelStackView: View {
    @ObservedObject var layout: ExplorerWindowLayoutState
    @ObservedObject var gitStatusStore: GitStatusStore

    let hostWindowID: UUID
    @Binding var selection: Set<FileItem.ID>
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
    let onRevealGitPath: (String) -> Void

    @State private var dragPreviewHeight: CGFloat?
    @State private var dragSnippetsHeight: CGFloat?

    private var previewMinHeight: CGFloat {
        layout.isPreviewContentCollapsed ? PanelTopBarMetrics.totalHeight : 80
    }

    private var snippetsMinHeight: CGFloat {
        layout.isSnippetsContentCollapsed ? PanelTopBarMetrics.totalHeight : 80
    }

    private var gitMinHeight: CGFloat {
        layout.isGitContentCollapsed ? PanelTopBarMetrics.totalHeight : GitPanelMetrics.minHeight
    }

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let layoutInput = heightInput(totalHeight: totalHeight)
            let stableLayoutInput = heightInput(totalHeight: totalHeight, dragPreviewHeight: nil)
            let dividerThickness = VerticalResizeDividerMetrics.visualHeight
            let showPreviewSnippetsDivider = RightPanelHeightCalculator.shouldShowResizeDivider(for: layoutInput)
            let showSnippetsGitDivider = RightPanelHeightCalculator.shouldShowSnippetsGitDivider(for: layoutInput)
            let showPreviewGitDivider = RightPanelHeightCalculator.shouldShowPreviewGitDivider(for: layoutInput)

            let calculatedPreviewHeight = RightPanelHeightCalculator.previewHeight(for: layoutInput)
            let calculatedSnippetsHeight = RightPanelHeightCalculator.snippetsHeight(for: layoutInput)
            let calculatedGitHeight = RightPanelHeightCalculator.gitHeight(for: layoutInput)

            let stablePreviewHeight = RightPanelHeightCalculator.previewHeight(for: stableLayoutInput)
            let stableLowerStackHeight = RightPanelHeightCalculator.lowerStackHeight(for: stableLayoutInput)
            let snippetsGitSplitRegionHeight = RightPanelHeightCalculator.snippetsGitSplitRegionHeight(for: stableLayoutInput)
            let previewGitRegionHeight = showPreviewGitDivider
                ? totalHeight
                : RightPanelHeightCalculator.previewGitRegionHeight(for: stableLayoutInput)

            let effectivePreviewHeight: CGFloat = {
                if let dragPreviewHeight { return dragPreviewHeight }
                if dragSnippetsHeight != nil { return stablePreviewHeight }
                return calculatedPreviewHeight
            }()

            let effectiveSnippetsHeight: CGFloat = {
                if let dragSnippetsHeight { return dragSnippetsHeight }
                return calculatedSnippetsHeight
            }()

            let effectiveGitHeight: CGFloat = {
                if let dragSnippetsHeight {
                    return max(
                        gitMinHeight,
                        stableLowerStackHeight - dragSnippetsHeight - dividerThickness
                    )
                }
                if dragPreviewHeight != nil, showPreviewGitDivider {
                    return max(
                        gitMinHeight,
                        previewGitRegionHeight - dragPreviewHeight! - dividerThickness
                    )
                }
                return calculatedGitHeight
            }()
            let shouldConstrainSnippetsHeight = layout.showGit || layout.showPreview

            VStack(spacing: 0) {
                if layout.showPreview {
                    FilePreviewView(
                        hostWindowID: hostWindowID,
                        showPreview: $layout.showPreview,
                        layout: layout,
                        selection: $selection,
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
                    .clipShape(Rectangle())
                }

                if showPreviewSnippetsDivider {
                    VerticalResizeDivider(
                        previewHeight: effectivePreviewHeight,
                        totalHeight: RightPanelHeightCalculator.upperSectionHeight(for: layoutInput),
                        minTopHeight: previewMinHeight,
                        minBottomHeight: snippetsMinHeight,
                        onHeightChange: { dragPreviewHeight = $0 },
                        onDragEnded: { finalHeight in
                            let upperHeight = RightPanelHeightCalculator.upperSectionHeight(for: layoutInput)
                            guard upperHeight > 0 else {
                                dragPreviewHeight = nil
                                return
                            }
                            layout.previewSnippetsSplitRatio = Double(finalHeight / upperHeight)
                            dragPreviewHeight = nil
                        }
                    )
                    .frame(height: VerticalResizeDividerMetrics.hitHeight)
                    .padding(.vertical, -(VerticalResizeDividerMetrics.hitHeight - VerticalResizeDividerMetrics.visualHeight) / 2)
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
                    .frame(height: shouldConstrainSnippetsHeight ? effectiveSnippetsHeight : nil)
                    .frame(maxHeight: shouldConstrainSnippetsHeight ? effectiveSnippetsHeight : .infinity)
                    .clipShape(Rectangle())
                }

                if showSnippetsGitDivider {
                    VerticalResizeDivider(
                        previewHeight: effectiveSnippetsHeight,
                        totalHeight: snippetsGitSplitRegionHeight,
                        minTopHeight: snippetsMinHeight,
                        minBottomHeight: gitMinHeight,
                        onHeightChange: { dragSnippetsHeight = $0 },
                        onDragEnded: { finalSnippetsHeight in
                            let newGitHeight = stableLowerStackHeight
                                - finalSnippetsHeight
                                - dividerThickness
                            layout.setGitPanelHeight(newGitHeight)
                            dragSnippetsHeight = nil
                        }
                    )
                    .frame(height: VerticalResizeDividerMetrics.hitHeight)
                    .padding(.vertical, -(VerticalResizeDividerMetrics.hitHeight - VerticalResizeDividerMetrics.visualHeight) / 2)
                    .zIndex(1)
                }

                if showPreviewGitDivider {
                    VerticalResizeDivider(
                        previewHeight: effectivePreviewHeight,
                        totalHeight: previewGitRegionHeight,
                        minTopHeight: previewMinHeight,
                        minBottomHeight: gitMinHeight,
                        onHeightChange: { dragPreviewHeight = $0 },
                        onDragEnded: { finalPreviewHeight in
                            let newGitHeight = previewGitRegionHeight
                                - finalPreviewHeight
                                - dividerThickness
                            layout.setGitPanelHeight(newGitHeight)
                            dragPreviewHeight = nil
                        }
                    )
                    .frame(height: VerticalResizeDividerMetrics.hitHeight)
                    .padding(.vertical, -(VerticalResizeDividerMetrics.hitHeight - VerticalResizeDividerMetrics.visualHeight) / 2)
                    .zIndex(1)
                }

                if layout.showGit {
                    GitPanelView(
                        showGit: $layout.showGit,
                        layout: layout,
                        gitStatusStore: gitStatusStore,
                        selection: selection,
                        items: items,
                        cwd: cwd,
                        showsTopSeparator: !showSnippetsGitDivider && !showPreviewGitDivider,
                        onRevealPath: onRevealGitPath
                    )
                    .frame(height: effectiveGitHeight)
                    .clipShape(Rectangle())
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .animation(nil, value: effectivePreviewHeight)
            .animation(nil, value: effectiveSnippetsHeight)
            .animation(nil, value: effectiveGitHeight)
            .onChange(of: layout.showPreview) { isVisible in
                if !isVisible {
                    PreviewSessionStore.shared.removeInlineSessions(forHostWindowID: hostWindowID)
                }
            }
        }
    }

    private func heightInput(
        totalHeight: CGFloat,
        dragPreviewHeight: CGFloat? = nil
    ) -> RightPanelHeightCalculator.Input {
        RightPanelHeightCalculator.Input(
            totalHeight: totalHeight,
            showPreview: layout.showPreview,
            showSnippets: layout.showSnippets,
            showGit: layout.showGit,
            isPreviewContentCollapsed: layout.isPreviewContentCollapsed,
            isSnippetsContentCollapsed: layout.isSnippetsContentCollapsed,
            isGitContentCollapsed: layout.isGitContentCollapsed,
            previewSnippetsSplitRatio: layout.previewSnippetsSplitRatio,
            gitPanelHeight: layout.gitPanelHeightValue,
            dragPreviewHeight: dragPreviewHeight ?? self.dragPreviewHeight,
            dividerHeight: VerticalResizeDividerMetrics.visualHeight,
            previewMinHeight: previewMinHeight,
            snippetsMinHeight: snippetsMinHeight,
            gitMinHeight: gitMinHeight,
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
