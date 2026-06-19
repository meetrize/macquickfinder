import CoreGraphics

/// 右侧面板（预览 + Snippets）垂直高度分配。
enum RightPanelHeightCalculator {
    struct Input: Equatable {
        var totalHeight: CGFloat
        var showPreview: Bool
        var showSnippets: Bool
        var isPreviewContentCollapsed: Bool
        var isSnippetsContentCollapsed: Bool
        var previewSnippetsSplitRatio: Double
        var dragPreviewHeight: CGFloat?
        var dividerHeight: CGFloat
        var previewMinHeight: CGFloat
        var snippetsMinHeight: CGFloat
        var collapsedTitleBarHeight: CGFloat
    }

    /// 预览区应占用的高度；Snippets 在布局中通过 `maxHeight: .infinity` 占剩余空间。
    static func previewHeight(for input: Input) -> CGFloat {
        guard input.showPreview else { return 0 }

        if input.isPreviewContentCollapsed {
            return input.collapsedTitleBarHeight
        }

        let showBoth = input.showPreview && input.showSnippets
        guard showBoth else {
            return max(input.previewMinHeight, input.totalHeight)
        }

        if input.isSnippetsContentCollapsed {
            return max(input.previewMinHeight, input.totalHeight - input.snippetsMinHeight)
        }

        let stored = clampedSplitPreviewHeight(for: input)
        return input.dragPreviewHeight ?? stored
    }

    static func clampedSplitPreviewHeight(for input: Input) -> CGFloat {
        guard input.totalHeight > 0 else { return 80 }
        let showDivider = input.showPreview
            && input.showSnippets
            && !input.isSnippetsContentCollapsed
            && !input.isPreviewContentCollapsed
        let divider = showDivider ? input.dividerHeight : 0
        let maxTop = max(input.previewMinHeight, input.totalHeight - input.snippetsMinHeight - divider)
        let raw = input.totalHeight * CGFloat(input.previewSnippetsSplitRatio)
        return min(max(raw, input.previewMinHeight), maxTop)
    }

    static func shouldShowResizeDivider(for input: Input) -> Bool {
        input.showPreview
            && input.showSnippets
            && !input.isSnippetsContentCollapsed
            && !input.isPreviewContentCollapsed
    }
}
