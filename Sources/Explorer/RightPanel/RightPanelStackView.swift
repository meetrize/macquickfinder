import SwiftUI

struct RightPanelStackView: View {
    @Binding var showPreview: Bool
    @Binding var showSnippets: Bool
    @Binding var splitRatio: Double

    let selection: Set<FileItem.ID>
    let items: [FileItem]
    let cwd: String
    let showHiddenFiles: Bool
    let panelWidth: CGFloat

    @ObservedObject private var settings = SnippetsSettings.shared
    @State private var dragPreviewHeight: CGFloat?

    private var previewMinHeight: CGFloat {
        settings.isPreviewContentCollapsed ? PanelTopBarMetrics.totalHeight : 80
    }

    private var snippetsMinHeight: CGFloat {
        settings.isSnippetsContentCollapsed ? PanelTopBarMetrics.totalHeight : 80
    }

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let showBoth = showPreview && showSnippets
            let showResizeDivider = showBoth && !settings.isSnippetsContentCollapsed && !settings.isPreviewContentCollapsed
            let storedPreviewHeight = clampedPreviewHeight(
                totalHeight * CGFloat(splitRatio),
                totalHeight: totalHeight
            )
            let previewHeight = dragPreviewHeight ?? storedPreviewHeight
            let expandedPreviewHeight: CGFloat = {
                // Snippets 折叠后只占一个标题栏：预览应自动撑满剩余空间
                if showBoth, settings.isSnippetsContentCollapsed, !settings.isPreviewContentCollapsed {
                    return max(previewMinHeight, totalHeight - snippetsMinHeight)
                }
                return previewHeight
            }()
            let effectivePreviewHeight = settings.isPreviewContentCollapsed
                ? PanelTopBarMetrics.totalHeight
                : expandedPreviewHeight

            VStack(spacing: 0) {
                if showPreview {
                    FilePreviewView(
                        showPreview: $showPreview,
                        selection: selection,
                        items: items
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
                            splitRatio = Double(finalHeight / totalHeight)
                            dragPreviewHeight = nil
                        }
                    )
                    .frame(height: VerticalResizeDividerMetrics.hitHeight)
                }

                if showSnippets {
                    SnippetsPanelView(
                        showSnippets: $showSnippets,
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
        let divider = showPreview && showSnippets && !settings.isSnippetsContentCollapsed && !settings.isPreviewContentCollapsed
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
