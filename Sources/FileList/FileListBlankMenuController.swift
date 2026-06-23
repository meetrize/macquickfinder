import AppKit
import Foundation

/// 文件列表空白处右键菜单（返回、向上、粘贴、新建等）。
public final class FileListBlankMenuController: NSObject {
    public var actions: FileListBlankMenuActions
    
    private enum MenuAction: Int {
        case goBack = 1
        case goUp
        case paste
        case newFolder
        case newFile
        case openTerminal
        case emptyTrash
    }
    
    public init(actions: FileListBlankMenuActions) {
        self.actions = actions
    }
    
    public func makeMenu() -> NSMenu {
        let menu = NSMenu()
        
        menu.addItem(makeItem(title: "返回", action: .goBack, enabled: actions.canGoBack))
        menu.addItem(makeItem(title: "向上", action: .goUp, enabled: actions.canGoUp))
        
        if actions.isInTrash {
            menu.addItem(.separator())
            menu.addItem(makeItem(title: "清倒废纸篓", action: .emptyTrash, enabled: true))
            return menu
        }
        
        if actions.canPaste {
            menu.addItem(.separator())
            menu.addItem(makeItem(title: "粘贴", action: .paste, enabled: true))
        }
        
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "新建文件夹", action: .newFolder, enabled: true))
        menu.addItem(makeItem(title: "新建文件", action: .newFile, enabled: true))
        menu.addItem(.separator())
        menu.addItem(makeItem(title: "在此处打开终端", action: .openTerminal, enabled: true))
        actions.appendToMenu?(menu)
        
        return menu
    }
    
    public func popUp(with event: NSEvent, for view: NSView) {
        guard actions.isEnabled else { return }
        let menu = makeMenu()
        guard !menu.items.isEmpty else { return }
        let fileURLs = actions.serviceFileURLs()
        actions.popUpContextMenu(menu, event, view, fileURLs)
    }
    
    private func makeItem(title: String, action: MenuAction, enabled: Bool) -> NSMenuItem {
        let item = NSMenuItem(
            title: title,
            action: #selector(handleMenuAction(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.tag = action.rawValue
        item.isEnabled = enabled
        return item
    }
    
    @objc private func handleMenuAction(_ sender: NSMenuItem) {
        guard let action = MenuAction(rawValue: sender.tag) else { return }
        switch action {
        case .goBack:
            actions.goBack()
        case .goUp:
            actions.goUp()
        case .paste:
            actions.paste()
        case .newFolder:
            actions.newFolder()
        case .newFile:
            actions.newFile()
        case .openTerminal:
            actions.openTerminal()
        case .emptyTrash:
            actions.emptyTrash()
        }
    }
}
