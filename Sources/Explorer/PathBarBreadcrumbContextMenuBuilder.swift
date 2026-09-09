import AppKit
import FileList
import Foundation

struct PathBarContextActions {
    var copyPath: (String) -> Void = { _ in }
    var copyDirectoryName: (String) -> Void = { _ in }
    var isFavorited: (String) -> Bool = { _ in false }
    var addFavorite: (String) -> Void = { _ in }
    var removeFavorite: (String) -> Void = { _ in }
    var openTerminal: (String) -> Void = { _ in }
    var revealInFinder: (String) -> Void = { _ in }
    var openInNewWindow: (String) -> Void = { _ in }
    var openClipboardPath: (ExternalFolderOpenRequestResolver.ResolvedRequest) -> Void = { _ in }

    static let empty = PathBarContextActions()
}

/// 路径栏面包屑段右键菜单（方案 A：打开优先；P1 含复制目录名 / 在 Finder 中显示）。
@MainActor
enum PathBarBreadcrumbContextMenuBuilder {
    enum ItemKind: Equatable {
        case openInNewWindow
        case separator
        case copyPath
        case copyDirectoryName
        case addFavorite
        case removeFavorite
        case openTerminalHere
        case revealInFinder
        case openClipboardPath
    }

    struct Snapshot: Equatable {
        var pathExists: Bool
        var pathExistsAsDirectory: Bool
        var canFavorite: Bool
        var isFavorited: Bool
        var hasClipboardPath: Bool
    }

    struct HiddenSegment: Equatable {
        let name: String
        let path: String
    }

    static func snapshot(
        for path: String,
        isFavorited: (String) -> Bool,
        clipboardHasPath: () -> Bool = { ClipboardPathResolver.hasResolvablePath() }
    ) -> Snapshot {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        let favorited = isFavorited(path)
        return Snapshot(
            pathExists: exists,
            pathExistsAsDirectory: exists && isDirectory.boolValue,
            canFavorite: FileListApplicationBundle.isFavoriteableDirectory(path: path),
            isFavorited: favorited,
            hasClipboardPath: clipboardHasPath()
        )
    }

    static func itemKinds(
        for snapshot: Snapshot,
        includeClipboard: Bool = true
    ) -> [ItemKind] {
        var items: [ItemKind] = [
            .openInNewWindow,
            .separator,
            .copyPath,
            .copyDirectoryName,
        ]
        if snapshot.isFavorited {
            items.append(.removeFavorite)
        } else if snapshot.canFavorite {
            items.append(.addFavorite)
        }
        items.append(.separator)
        items.append(.openTerminalHere)
        items.append(.revealInFinder)
        if includeClipboard, snapshot.hasClipboardPath {
            items.append(.separator)
            items.append(.openClipboardPath)
        }
        return items
    }

    static func makeMenu(
        path: String,
        actions: PathBarContextActions,
        clipboardHasPath: @escaping () -> Bool = { ClipboardPathResolver.hasResolvablePath() },
        resolveClipboard: @escaping () -> ExternalFolderOpenRequestResolver.ResolvedRequest? = {
            ClipboardPathResolver.resolve()
        }
    ) -> NSMenu {
        let snap = snapshot(
            for: path,
            isFavorited: actions.isFavorited,
            clipboardHasPath: clipboardHasPath
        )
        return makeActionsMenu(
            path: path,
            snapshot: snap,
            actions: actions,
            includeClipboard: true,
            resolveClipboard: resolveClipboard
        )
    }

    /// `…` 右键：每个隐藏段为子菜单；剪贴板项挂在根菜单底部一次。
    static func makeEllipsisMenu(
        segments: [HiddenSegment],
        actions: PathBarContextActions,
        onNavigate: @escaping (String) -> Void,
        clipboardHasPath: @escaping () -> Bool = { ClipboardPathResolver.hasResolvablePath() },
        resolveClipboard: @escaping () -> ExternalFolderOpenRequestResolver.ResolvedRequest? = {
            ClipboardPathResolver.resolve()
        }
    ) -> NSMenu {
        let menu = NSMenu()
        for segment in segments {
            let item = NSMenuItem(title: segment.name, action: nil, keyEquivalent: "")
            let snap = snapshot(
                for: segment.path,
                isFavorited: actions.isFavorited,
                clipboardHasPath: { false }
            )
            let submenu = makeActionsMenu(
                path: segment.path,
                snapshot: snap,
                actions: actions,
                includeClipboard: false,
                resolveClipboard: resolveClipboard,
                leadingNavigate: { onNavigate(segment.path) }
            )
            item.submenu = submenu
            menu.addItem(item)
        }
        if clipboardHasPath() {
            menu.addItem(.separator())
            menu.addItem(callbackItem(title: L10n.Action.openClipboardPath) {
                guard let resolved = resolveClipboard() else { return }
                actions.openClipboardPath(resolved)
            })
        }
        return menu
    }

    private static func makeActionsMenu(
        path: String,
        snapshot snap: Snapshot,
        actions: PathBarContextActions,
        includeClipboard: Bool,
        resolveClipboard: @escaping () -> ExternalFolderOpenRequestResolver.ResolvedRequest?,
        leadingNavigate: (() -> Void)? = nil
    ) -> NSMenu {
        let menu = NSMenu()
        if let leadingNavigate {
            menu.addItem(callbackItem(title: L10n.Action.open, action: leadingNavigate))
            menu.addItem(.separator())
        }
        for kind in itemKinds(for: snap, includeClipboard: includeClipboard) {
            switch kind {
            case .separator:
                menu.addItem(.separator())
            case .openInNewWindow:
                let item = callbackItem(title: L10n.Action.openInNewWindow) {
                    actions.openInNewWindow(path)
                }
                item.isEnabled = snap.pathExistsAsDirectory
                menu.addItem(item)
            case .copyPath:
                menu.addItem(callbackItem(title: L10n.Action.copyPaths) {
                    actions.copyPath(path)
                })
            case .copyDirectoryName:
                menu.addItem(callbackItem(title: L10n.Action.copyDirectoryName) {
                    actions.copyDirectoryName(path)
                })
            case .addFavorite:
                let item = callbackItem(title: L10n.Action.addFavorite) {
                    actions.addFavorite(path)
                }
                item.isEnabled = snap.canFavorite
                menu.addItem(item)
            case .removeFavorite:
                menu.addItem(callbackItem(title: L10n.Action.removeFavorite) {
                    actions.removeFavorite(path)
                })
            case .openTerminalHere:
                let item = callbackItem(title: L10n.Action.openTerminalHere) {
                    actions.openTerminal(path)
                }
                item.isEnabled = snap.pathExistsAsDirectory
                menu.addItem(item)
            case .revealInFinder:
                let item = callbackItem(title: L10n.Action.revealInFinder) {
                    actions.revealInFinder(path)
                }
                item.isEnabled = snap.pathExists
                menu.addItem(item)
            case .openClipboardPath:
                menu.addItem(callbackItem(title: L10n.Action.openClipboardPath) {
                    guard let resolved = resolveClipboard() else { return }
                    actions.openClipboardPath(resolved)
                })
            }
        }
        return menu
    }

    static func isExistingDirectory(_ path: String) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            && isDirectory.boolValue
    }

    private static func callbackItem(
        title: String,
        action: @escaping () -> Void
    ) -> NSMenuItem {
        PathBarCallbackMenuItem(title: title, action: action)
    }
}

private final class PathBarCallbackMenuItem: NSMenuItem {
    private let callback: () -> Void

    init(title: String, action: @escaping () -> Void) {
        callback = action
        super.init(title: title, action: #selector(performAction), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performAction() {
        callback()
    }
}
