import CoreGraphics

/// 右侧面板（预览 + Snippets + Git）垂直高度分配。
enum RightPanelHeightCalculator {
    struct Input: Equatable {
        var totalHeight: CGFloat
        var showPreview: Bool
        var showSnippets: Bool
        var showGit: Bool
        var isPreviewContentCollapsed: Bool
        var isSnippetsContentCollapsed: Bool
        var isGitContentCollapsed: Bool
        var previewSnippetsSplitRatio: Double
        var gitPanelHeight: CGFloat
        var dragPreviewHeight: CGFloat?
        var dividerHeight: CGFloat
        var previewMinHeight: CGFloat
        var snippetsMinHeight: CGFloat
        var gitMinHeight: CGFloat
        var collapsedTitleBarHeight: CGFloat
    }

    /// Git 段占用高度（底部固定段）。
    static func gitHeight(for input: Input) -> CGFloat {
        guard input.showGit else { return 0 }

        if input.isGitContentCollapsed {
            return input.collapsedTitleBarHeight
        }

        let onlyGit = !input.showPreview && !input.showSnippets
        if onlyGit {
            return max(input.gitMinHeight, input.totalHeight)
        }

        let desired = max(input.gitPanelHeight, input.gitMinHeight)
        let maxAllowed = max(input.gitMinHeight, input.totalHeight - minimumUpperSectionHeight(for: input))
        return min(desired, maxAllowed)
    }

    /// 预览 + Snippets 共享的可用高度。
    static func upperSectionHeight(for input: Input) -> CGFloat {
        max(
            0,
            input.totalHeight
                - gitHeight(for: input)
                - gitDividerHeight(for: input)
                - previewGitDividerHeight(for: input)
        )
    }

    /// 预览区应占用的高度；Snippets 在布局中通过 `maxHeight: .infinity` 占剩余空间。
    static func previewHeight(for input: Input) -> CGFloat {
        guard input.showPreview else { return 0 }

        if input.isPreviewContentCollapsed {
            return input.collapsedTitleBarHeight
        }

        var upperInput = input
        upperInput.totalHeight = upperSectionHeight(for: input)

        let showBoth = upperInput.showPreview && upperInput.showSnippets
        guard showBoth else {
            return max(upperInput.previewMinHeight, upperInput.totalHeight)
        }

        if upperInput.isSnippetsContentCollapsed {
            return max(upperInput.previewMinHeight, upperInput.totalHeight - upperInput.snippetsMinHeight)
        }

        let stored = clampedSplitPreviewHeight(for: upperInput)
        return upperInput.dragPreviewHeight ?? stored
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
            && upperSectionHeight(for: input) > input.previewMinHeight + input.snippetsMinHeight
    }

    /// Snippets 与 Git 之间的可拖拽分隔条。
    static func shouldShowSnippetsGitDivider(for input: Input) -> Bool {
        input.showSnippets
            && input.showGit
            && !input.isSnippetsContentCollapsed
            && !input.isGitContentCollapsed
    }

    /// 预览以下可用于 Snippets、分隔条与 Git 的垂直空间。
    static func lowerStackHeight(for input: Input) -> CGFloat {
        var height = input.totalHeight
        if input.showPreview {
            height -= previewHeight(for: input)
            if shouldShowPreviewSnippetsDivider(for: input) {
                height -= input.dividerHeight
            }
        }
        return max(0, height)
    }

    /// 预览与 Git 之间的可拖拽区域（无 Snippets 时，含 Git 与分隔条）。
    static func previewGitRegionHeight(for input: Input) -> CGFloat {
        guard shouldShowPreviewGitDivider(for: input) else { return 0 }
        return lowerStackHeight(for: input)
    }

    static func previewGitDividerHeight(for input: Input) -> CGFloat {
        shouldShowPreviewGitDivider(for: input) ? input.dividerHeight : 0
    }

    /// Snippets 与 Git 之间的可拖拽区域（含 Git 与分隔条）。
    static func snippetsGitSplitRegionHeight(for input: Input) -> CGFloat {
        guard shouldShowSnippetsGitDivider(for: input) else { return 0 }
        return lowerStackHeight(for: input)
    }

    /// 预览以下、Git 以上的 Snippets 占用高度。
    static func snippetsGitRegionHeight(for input: Input) -> CGFloat {
        snippetsHeight(for: input)
    }

    static func snippetsHeight(for input: Input) -> CGFloat {
        guard input.showSnippets else { return 0 }
        let lower = lowerStackHeight(for: input)
        guard input.showGit else { return lower }
        let gitSection = gitHeight(for: input)
        let divider = shouldShowSnippetsGitDivider(for: input) ? input.dividerHeight : 0
        return max(0, lower - gitSection - divider)
    }

    /// 预览与 Git 之间的可拖拽分隔条（无 Snippets 时）。
    static func shouldShowPreviewGitDivider(for input: Input) -> Bool {
        input.showPreview
            && input.showGit
            && !input.showSnippets
            && !input.isPreviewContentCollapsed
            && !input.isGitContentCollapsed
    }

    /// 右侧面板各可见段高度之和（用于校验不超出总高度）。
    static func allocatedStackHeight(for input: Input) -> CGFloat {
        var height = CGFloat(0)
        if input.showPreview {
            height += previewHeight(for: input)
            if shouldShowPreviewSnippetsDivider(for: input) {
                height += input.dividerHeight
            }
        }
        if input.showSnippets {
            height += snippetsHeight(for: input)
            if shouldShowSnippetsGitDivider(for: input) {
                height += input.dividerHeight
            }
        }
        if input.showGit {
            height += gitHeight(for: input)
            if shouldShowPreviewGitDivider(for: input) {
                height += input.dividerHeight
            }
        }
        return height
    }

    private static func shouldShowPreviewSnippetsDivider(for input: Input) -> Bool {
        input.showPreview
            && input.showSnippets
            && !input.isSnippetsContentCollapsed
            && !input.isPreviewContentCollapsed
    }

    static func gitDividerHeight(for input: Input) -> CGFloat {
        shouldShowSnippetsGitDivider(for: input) ? input.dividerHeight : 0
    }

    private static func minimumUpperSectionHeight(for input: Input) -> CGFloat {
        var minimum = CGFloat(0)

        if input.showPreview {
            minimum += input.isPreviewContentCollapsed
                ? input.collapsedTitleBarHeight
                : input.previewMinHeight
        }
        if input.showSnippets {
            minimum += input.isSnippetsContentCollapsed
                ? input.collapsedTitleBarHeight
                : input.snippetsMinHeight
        }
        if shouldShowPreviewSnippetsDivider(for: input) {
            minimum += input.dividerHeight
        }
        if shouldShowSnippetsGitDivider(for: input) {
            minimum += input.dividerHeight
        }
        if shouldShowPreviewGitDivider(for: input) {
            minimum += input.dividerHeight
        }
        return minimum
    }
}
