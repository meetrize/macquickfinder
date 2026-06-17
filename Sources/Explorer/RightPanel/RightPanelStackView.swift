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

    @State private var dragPreviewHeight: CGFloat?

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let showBoth = showPreview && showSnippets
            let storedPreviewHeight = clampedPreviewHeight(
                totalHeight * CGFloat(splitRatio),
                totalHeight: totalHeight
            )
            let previewHeight = dragPreviewHeight ?? storedPreviewHeight

            VStack(spacing: 0) {
                if showPreview {
                    FilePreviewView(
                        showPreview: $showPreview,
                        selection: selection,
                        items: items
                    )
                    .frame(height: previewHeight)
                }

                if showBoth {
                    VerticalResizeDivider(
                        previewHeight: previewHeight,
                        totalHeight: totalHeight,
                        minTopHeight: 80,
                        minBottomHeight: 80,
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
            .animation(nil, value: previewHeight)
        }
    }

    private func clampedPreviewHeight(_ height: CGFloat, totalHeight: CGFloat) -> CGFloat {
        guard totalHeight > 0 else { return 80 }
        let divider = showPreview && showSnippets ? VerticalResizeDividerMetrics.hitHeight : 0
        let maxTop = max(80, totalHeight - 80 - divider)
        return min(max(height, 80), maxTop)
    }
}

enum PanelTopBarMetrics {
    static let contentHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 6
}
