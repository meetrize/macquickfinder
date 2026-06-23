import Foundation

enum SnippetDefaults {
    static let shellInterpreter = "/bin/zsh"
    static let bashInterpreter = "/bin/bash"
    static let hidesUnavailableSnippets = true
    static let schemaVersion = 1
    static let maxImportCount = 500
}

enum ExplorerAppSettings {
    static let showPreviewKey = "showPreview"
    static let showSnippetsKey = "showSnippets"
    static let previewSnippetsSplitRatioKey = "previewSnippetsSplitRatio"
    static let outputPanelVisibleKey = "snippets.outputPanelVisible"
    static let outputPanelHeightKey = "snippets.outputPanelHeight"
    static let pinRecentlyExecutedSnippetsKey = "snippets.pinRecentlyExecuted"
    static let maxConcurrentJobsKey = "snippets.maxConcurrentJobs"
    static let autoShowOutputPanelOnShellRunKey = "snippets.autoShowOutputPanel"
    static let confirmDestructiveSnippetsKey = "snippets.confirmDestructive"
    static let snippetsDisplayModeKey = "snippets.displayMode"
    static let snippetsContentCollapsedKey = "snippets.contentCollapsed"
    static let outputPanelContentCollapsedKey = "snippets.outputPanelContentCollapsed"
    static let previewContentCollapsedKey = "snippets.previewContentCollapsed"
    static let windowSnapEnabledKey = "windowSnapEnabled"
    static let customPreviewRulesKey = "preview.customRules"
    static let previewBrowserSameTypeOnlyKey = "previewBrowser.sameTypeOnly"
}
