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
    @State private var dragGitPanelHeight: CGFloat?

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
            let showPreviewSnippetsDivider = RightPanelHeightCalculator.shouldShowResizeDivider(for: layoutInput)
            let showSnippetsGitDivider = RightPanelHeightCalculator.shouldShowSnippetsGitDivider(for: layoutInput)
            let showPreviewGitDivider = RightPanelHeightCalculator.shouldShowPreviewGitDivider(for: layoutInput)
            let effectivePreviewHeight = RightPanelHeightCalculator.previewHeight(for: layoutInput)
            let effectiveGitHeight = RightPanelHeightCalculator.gitHeight(for: layoutInput)
            let snippetsGitRegionHeight = RightPanelHeightCalculator.snippetsGitRegionHeight(for: layoutInput)
            let previewGitRegionHeight = RightPanelHeightCalculator.previewGitRegionHeight(for: layoutInput)
            let effectiveSnippetsHeight = RightPanelHeightCalculator.snippetsHeight(for: layoutInput)

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
                    .frame(height: layout.showGit ? effectiveSnippetsHeight : nil)
                    .frame(maxHeight: layout.showGit ? effectiveSnippetsHeight : .infinity)
                }

                if showSnippetsGitDivider {
                    VerticalResizeDivider(
                        previewHeight: effectiveSnippetsHeight,
                        totalHeight: snippetsGitRegionHeight,
                        minTopHeight: snippetsMinHeight,
                        minBottomHeight: gitMinHeight,
                        onHeightChange: { newSnippetsHeight in
                            let gitHeight = snippetsGitRegionHeight
                                - newSnippetsHeight
                                - VerticalResizeDividerMetrics.visualHeight
                            dragGitPanelHeight = gitHeight
                        },
                        onDragEnded: { finalSnippetsHeight in
                            let divider = VerticalResizeDividerMetrics.visualHeight
                            let newGitHeight = snippetsGitRegionHeight - finalSnippetsHeight - divider
                            layout.setGitPanelHeight(newGitHeight)
                            dragGitPanelHeight = nil
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
                        onHeightChange: { newPreviewHeight in
                            let gitHeight = previewGitRegionHeight
                                - newPreviewHeight
                                - VerticalResizeDividerMetrics.visualHeight
                            dragGitPanelHeight = gitHeight
                        },
                        onDragEnded: { finalPreviewHeight in
                            let divider = VerticalResizeDividerMetrics.visualHeight
                            let newGitHeight = previewGitRegionHeight - finalPreviewHeight - divider
                            layout.setGitPanelHeight(newGitHeight)
                            dragGitPanelHeight = nil
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
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(nil, value: effectivePreviewHeight)
            .animation(nil, value: effectiveGitHeight)
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
            showGit: layout.showGit,
            isPreviewContentCollapsed: layout.isPreviewContentCollapsed,
            isSnippetsContentCollapsed: layout.isSnippetsContentCollapsed,
            isGitContentCollapsed: layout.isGitContentCollapsed,
            previewSnippetsSplitRatio: layout.previewSnippetsSplitRatio,
            gitPanelHeight: dragGitPanelHeight ?? layout.gitPanelHeightValue,
            dragPreviewHeight: dragPreviewHeight,
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
