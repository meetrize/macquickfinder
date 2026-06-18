import AppKit
import Foundation

public struct FileListBlankMenuActions {
    public var isEnabled = true
    public var canGoBack = false
    public var goBack: () -> Void = {}
    public var canGoUp = false
    public var goUp: () -> Void = {}
    public var canPaste = false
    public var paste: () -> Void = {}
    public var newFolder: () -> Void = {}
    public var newFile: () -> Void = {}
    public var openTerminal: () -> Void = {}
    public var isInTrash = false
    public var emptyTrash: () -> Void = {}
    public var appendToMenu: ((NSMenu) -> Void)?
    
    public init(
        isEnabled: Bool = true,
        canGoBack: Bool = false,
        goBack: @escaping () -> Void = {},
        canGoUp: Bool = false,
        goUp: @escaping () -> Void = {},
        canPaste: Bool = false,
        paste: @escaping () -> Void = {},
        newFolder: @escaping () -> Void = {},
        newFile: @escaping () -> Void = {},
        openTerminal: @escaping () -> Void = {},
        isInTrash: Bool = false,
        emptyTrash: @escaping () -> Void = {},
        appendToMenu: ((NSMenu) -> Void)? = nil
    ) {
        self.isEnabled = isEnabled
        self.canGoBack = canGoBack
        self.goBack = goBack
        self.canGoUp = canGoUp
        self.goUp = goUp
        self.canPaste = canPaste
        self.paste = paste
        self.newFolder = newFolder
        self.newFile = newFile
        self.openTerminal = openTerminal
        self.isInTrash = isInTrash
        self.emptyTrash = emptyTrash
        self.appendToMenu = appendToMenu
    }
}
