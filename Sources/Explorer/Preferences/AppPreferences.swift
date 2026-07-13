import FileList
import Foundation

/// 应用偏好键注册表（单一命名空间；持久化键字符串仅在此与 `FileListStorageKeys` 定义）。
enum AppPreferences {
    /// FileList 模块键（字符串源：`FileListStorageKeys`）。
    enum FileList {
        static let preferences = FileListStorageKeys.preferences
        static let legacyColumns = FileListStorageKeys.legacyColumns
        static let viewMode = FileListStorageKeys.viewMode
        static let thumbnailLayoutMode = FileListStorageKeys.thumbnailLayoutMode
        static let thumbnailCellSize = FileListStorageKeys.thumbnailCellSize
        static let rowHoverHighlight = FileListStorageKeys.rowHoverHighlight
    }

    /// 子目录全景缩略图偏好。
    enum Panorama {
        static let expandDepthPolicy = "explorer.panorama.expandDepthPolicy"
    }

    /// 窗口与面板布局。
    enum Layout {
        static let showPreview = "showPreview"
        static let showSnippets = "showSnippets"
        static let showGit = "showGit"
        static let previewSnippetsSplitRatio = "previewSnippetsSplitRatio"
        static let previewPanelWidth = "previewPanelWidth"
        static let gitPanelHeight = "gitPanelHeight"
        static let leftPanelMode = "leftPanelMode"
        static let leftPanelLastVisibleMode = "leftPanelLastVisibleMode"
        static let leftPanelSidebarWidth = "leftPanelSidebarWidth"
        static let lastOpenedPath = "lastOpenedPath"
    }

    /// 输出/片段面板折叠与尺寸。
    enum Panels {
        static let outputVisible = "snippets.outputPanelVisible"
        static let outputHeight = "snippets.outputPanelHeight"
        static let snippetsContentCollapsed = "snippets.contentCollapsed"
        static let outputContentCollapsed = "snippets.outputPanelContentCollapsed"
        static let previewContentCollapsed = "snippets.previewContentCollapsed"
        static let gitContentCollapsed = "git.contentCollapsed"
    }

    /// Snippets 执行与展示偏好。
    enum Snippets {
        static let pinRecentlyExecuted = "snippets.pinRecentlyExecuted"
        static let maxConcurrentJobs = "snippets.maxConcurrentJobs"
        static let autoShowOutputPanelOnShellRun = "snippets.autoShowOutputPanel"
        static let confirmDestructive = "snippets.confirmDestructive"
        static let displayMode = "snippets.displayMode"
        static let outputColorScheme = "snippets.outputColorScheme"
    }

    /// 预览与 Quick Look 相关。
    enum Preview {
        static let customRules = "preview.customRules"
        static let browserSameTypeOnly = "previewBrowser.sameTypeOnly"
        static let codeShowLineNumbers = "preview.codeShowLineNumbers"
        static let doubleClickAction = "preview.doubleClickAction"
        static let externalOpenAction = "preview.externalOpenAction"
        static let archiveDoubleClickAction = "preview.archiveDoubleClickAction"
        static let externalMultiImageOpen = "preview.externalMultiImageOpen"
    }

    /// 目录元数据。
    enum Directory {
        static let autoCalculateDirectorySizes = "autoCalculateDirectorySizes"
        static let useIconPreview = "useIconPreview"
    }

    /// 通用 Explorer 行为。
    enum General {
        static let windowSnapEnabled = "windowSnapEnabled"
        static let blankDoubleClickAction = "blankDoubleClickAction"
        static let interfaceLanguage = ModuleLocalization.preferenceKey
    }

    /// JSON / Data 持久化 blob。
    enum Data {
        static let favorites = "favoriteLocations"
        static let trashRestoreRecords = "trashRestoreRecords"
    }

    /// 顶部工具栏自定义布局。
    enum Toolbar {
        static let layoutConfig = "toolbar.layoutConfig"
    }

    /// 快捷键偏好。
    enum Shortcuts {
        static let globalToggleEnabled = "shortcuts.globalToggleEnabled"
        static let globalToggleKeyCode = "shortcuts.globalToggleKeyCode"
        static let globalToggleModifiers = "shortcuts.globalToggleModifiers"
        static let newTabKeyCode = "shortcuts.newTabKeyCode"
        static let newTabModifiers = "shortcuts.newTabModifiers"
        static let copyPathKeyCode = "shortcuts.copyPathKeyCode"
        static let copyPathModifiers = "shortcuts.copyPathModifiers"
        static let previewTextEditKeyCode = "shortcuts.previewTextEditKeyCode"
        static let previewTextEditModifiers = "shortcuts.previewTextEditModifiers"
    }

    /// 快捷命令面板。
    enum CommandPalette {
        static let recents = "commandPalette.recents"
    }

    /// 远程服务器连接。
    enum RemoteServer {
        static let recentBookmarks = "remoteServer.recentBookmarks"
    }

    /// 操作录制偏好。
    enum OperationRecording {
        static let generalizePaths = "operationRecording.generalizePaths"
        static let showBanner = "operationRecording.showBanner"
    }

    /// Git 集成。
    enum Git {
        static let customExecutablePath = "git.customExecutablePath"
    }
}

/// 兼容旧调用方；新代码请使用 `AppPreferences`。
enum ExplorerAppSettings {
    static let showPreviewKey = AppPreferences.Layout.showPreview
    static let showSnippetsKey = AppPreferences.Layout.showSnippets
    static let previewSnippetsSplitRatioKey = AppPreferences.Layout.previewSnippetsSplitRatio
    static let outputPanelVisibleKey = AppPreferences.Panels.outputVisible
    static let outputPanelHeightKey = AppPreferences.Panels.outputHeight
    static let pinRecentlyExecutedSnippetsKey = AppPreferences.Snippets.pinRecentlyExecuted
    static let maxConcurrentJobsKey = AppPreferences.Snippets.maxConcurrentJobs
    static let autoShowOutputPanelOnShellRunKey = AppPreferences.Snippets.autoShowOutputPanelOnShellRun
    static let confirmDestructiveSnippetsKey = AppPreferences.Snippets.confirmDestructive
    static let snippetsDisplayModeKey = AppPreferences.Snippets.displayMode
    static let snippetsContentCollapsedKey = AppPreferences.Panels.snippetsContentCollapsed
    static let outputPanelContentCollapsedKey = AppPreferences.Panels.outputContentCollapsed
    static let previewContentCollapsedKey = AppPreferences.Panels.previewContentCollapsed
    static let windowSnapEnabledKey = AppPreferences.General.windowSnapEnabled
    static let customPreviewRulesKey = AppPreferences.Preview.customRules
    static let previewBrowserSameTypeOnlyKey = AppPreferences.Preview.browserSameTypeOnly
    static let codePreviewShowLineNumbersKey = AppPreferences.Preview.codeShowLineNumbers
    static let blankDoubleClickActionKey = AppPreferences.General.blankDoubleClickAction
    static let previewPanelWidthKey = AppPreferences.Layout.previewPanelWidth
    static let leftPanelModeKey = AppPreferences.Layout.leftPanelMode
    static let leftPanelLastVisibleModeKey = AppPreferences.Layout.leftPanelLastVisibleMode
    static let leftPanelSidebarWidthKey = AppPreferences.Layout.leftPanelSidebarWidth
    static let lastOpenedPathKey = AppPreferences.Layout.lastOpenedPath
    static let favoritesKey = AppPreferences.Data.favorites
    static let trashRestoreRecordsKey = AppPreferences.Data.trashRestoreRecords
}
