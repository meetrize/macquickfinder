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

    var body: some View {
        GeometryReader { geo in
            let totalHeight = geo.size.height
            let showBoth = showPreview && showSnippets
            let previewHeight: CGFloat = {
                if showBoth {
                    return max(80, min(totalHeight - 80, totalHeight * CGFloat(splitRatio)))
                }
                if showPreview { return totalHeight }
                return 0
            }()

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
                    VerticalResizeDivider(topRatio: $splitRatio)
                        .frame(height: 6)
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
        }
    }
}

enum PanelTopBarMetrics {
    static let contentHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 6
}
