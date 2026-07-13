import AppKit
import FileList
import SwiftUI

struct ToolbarAppIconView: View {
    let applicationPath: String
    var size: CGFloat = ExplorerToolbarMetrics.iconSize

    var body: some View {
        let image = NSWorkspace.shared.icon(forFile: applicationPath)
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
    }
}

struct ToolbarItemChipLabel: View {
    let entry: ToolbarVisibleEntry
    let layout: ToolbarLayoutConfig
    let environment: ExplorerToolbarEnvironment

    var body: some View {
        Group {
            switch entry.kind {
            case .builtin:
                if let builtin = ToolbarBuiltinID(rawValue: entry.id) {
                    builtin.toolbarChipIcon(environment: environment)
                }
            case .openApp:
                if let action = layout.customAction(for: entry.id) {
                    if action.useApplicationIcon {
                        ToolbarAppIconView(applicationPath: action.applicationPath)
                    } else {
                        LucideIcon.appWindow
                    }
                }
            }
        }
        .frame(width: ExplorerToolbarMetrics.iconHitSize, height: ExplorerToolbarMetrics.iconHitSize)
        .contentShape(Rectangle())
    }
}

struct ExplorerToolbarItemView: View {
    let entry: ToolbarVisibleEntry
    let layout: ToolbarLayoutConfig
    let environment: ExplorerToolbarEnvironment

    var body: some View {
        switch entry.kind {
        case .builtin:
            builtinView
        case .openApp:
            openAppView
        }
    }

    @ViewBuilder
    private var builtinView: some View {
        if let builtin = ToolbarBuiltinID(rawValue: entry.id) {
            switch builtin {
            case .thumbnailSizeSlider:
                if environment.fileListViewMode == .thumbnail || environment.isCustomizing {
                    ExplorerToolbarThumbnailSizeSlider(
                        cellSize: Binding(
                            get: { environment.layout.thumbnailCellSizeValue },
                            set: { environment.layout.thumbnailCellSizeValue = $0 }
                        )
                    )
                    .instantHoverTooltip(L10n.Toolbar.thumbnailSize)
                    .disabled(environment.isCustomizing)
                }
            case .sortMenu:
                ExplorerToolbarSFSymbolMenu(
                    systemSymbolName: "line.horizontal.3.decrease.circle",
                    tooltip: L10n.Toolbar.sort,
                    menuActions: SortOrder.allCases.map { order in
                        ExplorerToolbarMenuAction(
                            title: order.displayName,
                            isSelected: environment.sortOrder == order,
                            handler: { environment.setSortOrder(order) }
                        )
                    }
                )
                .disabled(environment.isCustomizing)
            case .browseSettingsMenu:
                ExplorerToolbarLucideMenu(
                    icon: LucideIcon.settings,
                    tooltip: L10n.Toolbar.browseSettings,
                    menuActions: browseSettingsMenuActions
                )
                .disabled(environment.isCustomizing)
            case .newWindow:
                let newWindowButton = Button {
                    ToolbarBuiltinDispatcher.perform(.newWindow, environment: environment)
                } label: {
                    SFSymbolToolbarIcon(systemName: "rectangle.on.rectangle")
                }
                .buttonStyle(ExplorerToolbarPlainButtonStyle())
                .disabled(isBuiltinDisabled(.newWindow))
                if let tooltip = tooltipForBuiltin(.newWindow) {
                    newWindowButton.instantHoverTooltip(tooltip)
                } else {
                    newWindowButton
                }
            case .newTab:
                let newTabButton = Button {
                    ToolbarBuiltinDispatcher.perform(.newTab, environment: environment)
                } label: {
                    SFSymbolToolbarIcon(systemName: "square.on.square")
                }
                .buttonStyle(ExplorerToolbarPlainButtonStyle())
                .disabled(isBuiltinDisabled(.newTab))
                if let tooltip = tooltipForBuiltin(.newTab) {
                    newTabButton.instantHoverTooltip(tooltip)
                } else {
                    newTabButton
                }
            case .showAllTabs:
                let showAllTabsButton = Button {
                    ToolbarBuiltinDispatcher.perform(.showAllTabs, environment: environment)
                } label: {
                    SFSymbolToolbarIcon(systemName: "square.stack.3d.down.right")
                }
                .buttonStyle(ExplorerToolbarPlainButtonStyle())
                .disabled(isBuiltinDisabled(.showAllTabs))
                if let tooltip = tooltipForBuiltin(.showAllTabs) {
                    showAllTabsButton.instantHoverTooltip(tooltip)
                } else {
                    showAllTabsButton
                }
            case .preview:
                let previewButton = Button {
                    ToolbarBuiltinDispatcher.perform(.preview, environment: environment)
                } label: {
                    PreviewToolbarIcon(isActive: environment.layout.showPreview)
                }
                .buttonStyle(ExplorerToolbarPlainButtonStyle())
                .disabled(isBuiltinDisabled(.preview))
                if let tooltip = tooltipForBuiltin(.preview) {
                    previewButton.instantHoverTooltip(tooltip)
                } else {
                    previewButton
                }
            case .recordOperations:
                let recordButton = Button {
                    ToolbarBuiltinDispatcher.perform(.recordOperations, environment: environment)
                } label: {
                    RecordOperationsToolbarIcon(isRecording: environment.isOperationRecording)
                }
                .buttonStyle(ExplorerToolbarPlainButtonStyle())
                .disabled(isBuiltinDisabled(.recordOperations))
                if let tooltip = tooltipForBuiltin(.recordOperations) {
                    recordButton.instantHoverTooltip(tooltip)
                } else {
                    recordButton
                }
            default:
                ExplorerToolbarIconButton(
                    icon: iconForBuiltin(builtin),
                    action: { ToolbarBuiltinDispatcher.perform(builtin, environment: environment) },
                    tooltip: tooltipForBuiltin(builtin),
                    isDisabled: isBuiltinDisabled(builtin)
                )
            }
        }
    }

    @ViewBuilder
    private var openAppView: some View {
        if let action = layout.customAction(for: entry.id) {
            Button {
                environment.performOpenApp(action)
            } label: {
                if action.useApplicationIcon {
                    ToolbarAppIconView(applicationPath: action.applicationPath)
                } else {
                    LucideIcon.appWindow
                }
            }
            .buttonStyle(ExplorerToolbarPlainButtonStyle())
            .disabled(environment.isCustomizing || isOpenAppDisabled(action))
            .instantHoverTooltip(openAppTooltip(action))
            .contextMenu {
                Button(L10n.Toolbar.openAppEdit) {
                    environment.editOpenApp(action)
                }
            }
        }
    }

    private func isOpenAppDisabled(_ action: CustomOpenAppAction) -> Bool {
        action.selectionPolicy == .requireSelection && environment.selectedItems.isEmpty
    }

    private func openAppTooltip(_ action: CustomOpenAppAction) -> String {
        if isOpenAppDisabled(action) {
            return L10n.Toolbar.Error.noSelection
        }
        return L10n.Toolbar.openAppTooltip(action.displayName)
    }

    private var browseSettingsMenuActions: [ExplorerToolbarMenuAction] {
        var actions: [ExplorerToolbarMenuAction] = [
            ExplorerToolbarMenuAction(
                title: L10n.Toolbar.autoFolderSize,
                isOn: environment.autoCalculateDirectorySizes,
                handler: environment.toggleAutoCalculateDirectorySizes
            ),
            ExplorerToolbarMenuAction(
                title: L10n.Toolbar.useIconPreview,
                isOn: environment.useIconPreview,
                handler: environment.toggleUseIconPreview
            ),
        ]

        guard environment.fileListViewMode == .thumbnail,
              environment.layout.thumbnailLayoutMode == .panorama else {
            return actions
        }

        actions.append(
            ExplorerToolbarMenuAction(
                title: L10n.Toolbar.panoramaExpandAll,
                handler: { PanoramaTreeControllerBridge.controller?.expandAll() }
            )
        )
        actions.append(
            ExplorerToolbarMenuAction(
                title: L10n.Toolbar.panoramaCollapseAll,
                handler: { PanoramaTreeControllerBridge.controller?.collapseAll() }
            )
        )

        for policy in PanoramaExpandDepthPolicy.allCases {
            actions.append(
                ExplorerToolbarMenuAction(
                    title: "\(L10n.Toolbar.panoramaExpandDepth): \(policy.displayName)",
                    isSelected: environment.layout.panoramaExpandDepthPolicy == policy,
                    handler: { environment.layout.setPanoramaExpandDepthPolicy(policy) }
                )
            )
        }

        return actions
    }

    private func iconForBuiltin(_ builtin: ToolbarBuiltinID) -> LucideIcon {
        builtin.lucideIcon(environment: environment)
    }

    private func tooltipForBuiltin(_ builtin: ToolbarBuiltinID) -> String? {
        switch builtin {
        case .leftPanel:
            return environment.leftPanelMode == .hidden
                ? L10n.Toolbar.showLeftPanel
                : L10n.Toolbar.hideLeftPanel
        case .newWindow:
            return L10n.Toolbar.newWindow
        case .newTab:
            return L10n.Toolbar.newTab
        case .showAllTabs:
            return L10n.Toolbar.showAllTabs
        case .toggleTabBar:
            if !environment.tabBarState.isTabbingAvailable {
                return L10n.Toolbar.tabBarUnavailable
            }
            if !environment.tabBarState.canToggle {
                return L10n.Toolbar.tabBarCannotHideMultiple
            }
            return environment.tabBarState.isVisible
                ? L10n.Toolbar.hideTabBar
                : L10n.Toolbar.showTabBar
        case .preview:
            return environment.layout.showPreview ? L10n.Menu.hidePreview : L10n.Menu.showPreview
        case .snippets:
            return environment.layout.showSnippets ? L10n.Menu.hideSnippets : L10n.Menu.showSnippets
        case .git:
            return environment.layout.showGit ? L10n.Menu.hideGit : L10n.Menu.showGit
        case .recordOperations:
            return environment.isOperationRecording
                ? L10n.Toolbar.recordOperationsActive
                : L10n.Toolbar.recordOperations
        case .outputPanel:
            return environment.layout.isOutputPanelVisible
                ? L10n.Menu.hideOutputPanel
                : L10n.Menu.showOutputPanel
        case .newFolder:
            return L10n.Toolbar.newFolder
        case .newFile:
            return L10n.Toolbar.newFile
        case .delete:
            return L10n.Toolbar.delete
        case .listView:
            return L10n.Toolbar.listView
        case .thumbnailView:
            return L10n.Toolbar.thumbnailView
        case .panoramaView:
            return L10n.Toolbar.panoramaMode
        default:
            return nil
        }
    }

    private func isBuiltinDisabled(_ builtin: ToolbarBuiltinID) -> Bool {
        if environment.isCustomizing { return true }
        if builtin == .delete {
            return environment.deletableSelectedItems.isEmpty
        }
        if builtin == .toggleTabBar {
            return !environment.tabBarState.canToggle
        }
        return false
    }
}

struct ToolbarDraggableChip<Label: View>: View {
    let itemID: String
    let kind: ToolbarItemKind
    let source: ToolbarDragSource
    @ViewBuilder let label: () -> Label

    var body: some View {
        label()
            .onDrag { dragProvider() }
    }

    private func dragProvider() -> NSItemProvider {
        let payload = ToolbarDragPayload(
            itemID: itemID,
            kind: kind,
            source: source
        )
        let provider = NSItemProvider()
        if let string = payload.pasteboardString {
            provider.registerObject(NSString(string: string), visibility: .all)
        }
        return provider
    }
}

extension ToolbarBuiltinID {
    @MainActor
    func lucideIcon(environment: ExplorerToolbarEnvironment) -> LucideIcon {
        switch self {
        case .leftPanel:
            return .panelLeft
        case .newWindow:
            return .appWindow
        case .newTab:
            return .squarePlus
        case .showAllTabs:
            return .galleryHorizontalEnd
        case .toggleTabBar:
            return .panelTop(isActive: environment.tabBarState.isVisible)
        case .preview:
            return .fileImage(isActive: environment.layout.showPreview)
        case .snippets:
            return .braces(isActive: environment.layout.showSnippets)
        case .git:
            return .gitBranch(isActive: environment.layout.showGit)
        case .recordOperations:
            return .record(isRecording: environment.isOperationRecording)
        case .outputPanel:
            return .terminal(isActive: environment.layout.isOutputPanelVisible)
        case .newFolder:
            return .folderPlus
        case .newFile:
            return .filePlus
        case .delete:
            return .trash2
        case .toggleHiddenFiles:
            return environment.showHiddenFiles ? .eye : .eyeOff
        case .listView:
            return .list(isActive: environment.fileListViewMode == .list)
        case .thumbnailView:
            return .layoutGrid(
                isActive: environment.fileListViewMode == .thumbnail
                    && environment.layout.thumbnailLayoutMode == .grid
            )
        case .panoramaView:
            return .folderTree(
                isActive: environment.fileListViewMode == .thumbnail
                    && environment.layout.thumbnailLayoutMode == .panorama
            )
        case .thumbnailSizeSlider, .sortMenu, .browseSettingsMenu:
            return .settings
        }
    }

    @MainActor
    @ViewBuilder
    func toolbarChipIcon(environment: ExplorerToolbarEnvironment) -> some View {
        switch self {
        case .thumbnailSizeSlider:
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 12, weight: .medium))
        case .newWindow:
            SFSymbolToolbarIcon(systemName: "rectangle.on.rectangle")
        case .newTab:
            SFSymbolToolbarIcon(systemName: "square.on.square")
        case .showAllTabs:
            SFSymbolToolbarIcon(systemName: "square.stack.3d.down.right")
        case .preview:
            PreviewToolbarIcon(isActive: environment.layout.showPreview)
        case .recordOperations:
            RecordOperationsToolbarIcon(isRecording: environment.isOperationRecording)
        case .sortMenu:
            SFSymbolToolbarIcon(systemName: "line.horizontal.3.decrease.circle")
        case .browseSettingsMenu:
            LucideIcon.settings
        default:
            lucideIcon(environment: environment)
        }
    }
}

private struct SFSymbolToolbarIcon: View {
    let systemName: String
    var isActive: Bool = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: ExplorerToolbarMetrics.iconSize, weight: .medium))
            .foregroundStyle(isActive ? Color.accentColor : Color.primary)
            .frame(width: ExplorerToolbarMetrics.iconSize, height: ExplorerToolbarMetrics.iconSize)
    }
}

private struct PreviewToolbarIcon: View {
    let isActive: Bool

    var body: some View {
        SFSymbolToolbarIcon(systemName: "photo", isActive: isActive)
    }
}

private struct RecordOperationsToolbarIcon: View {
    let isRecording: Bool

    var body: some View {
        Image(systemName: isRecording ? "stop.circle" : "smallcircle.fill.circle")
            .font(.system(size: ExplorerToolbarMetrics.iconSize, weight: .medium))
            .foregroundStyle(isRecording ? Color.red : Color.primary)
            .frame(width: ExplorerToolbarMetrics.iconSize, height: ExplorerToolbarMetrics.iconSize)
    }
}
