import AppKit
import FileList

private let fileSendTypes: [NSPasteboard.PasteboardType] = [
    .fileURL,
    .init("public.file-url"),
    .init("NSFilenamesPboardType"),
]

final class FileServicesMenuRequestor: NSObject, FileListServicesMenuRequestor, NSServicesMenuRequestor {
    static let shared = FileServicesMenuRequestor()

    private let stateLock = NSLock()
    private var activeURLs: [URL] = []
    private weak var savedFirstResponder: NSResponder?

    var restorableFirstResponder: NSResponder? {
        savedFirstResponder
    }

    func setContext(urls: [URL], previousFirstResponder: NSResponder?) {
        stateLock.lock()
        activeURLs = urls
        stateLock.unlock()
        savedFirstResponder = previousFirstResponder
    }

    func clearContext() {
        stateLock.lock()
        activeURLs = []
        stateLock.unlock()
        savedFirstResponder = nil
    }

    func validRequestor(
        forSendType sendType: NSPasteboard.PasteboardType?,
        returnType: NSPasteboard.PasteboardType?
    ) -> Any? {
        guard let sendType, fileSendTypes.contains(sendType) else { return nil }
        guard !readActiveURLs().isEmpty else { return nil }
        return self
    }

    func writeSelection(to pboard: NSPasteboard, types: [NSPasteboard.PasteboardType]) -> Bool {
        let urls = readActiveURLs()
        guard !urls.isEmpty else { return false }

        var wrote = false
        let publicFileURL = NSPasteboard.PasteboardType("public.file-url")

        if types.contains(where: { $0 == .fileURL || $0 == publicFileURL }) {
            pboard.writeObjects(urls as [NSURL])
            wrote = true
        }

        let filenamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        if types.contains(filenamesType) {
            pboard.setPropertyList(urls.map(\.path), forType: filenamesType)
            wrote = true
        }

        return wrote
    }

    private func readActiveURLs() -> [URL] {
        stateLock.lock()
        defer { stateLock.unlock() }
        return activeURLs
    }
}

@MainActor
enum FileServicesMenuSupport {
    private static var isRegistered = false
    private static var menuCleanupDelegate: MenuCleanupDelegate?

    static func registerIfNeeded() {
        guard !isRegistered else { return }
        isRegistered = true
        NSApplication.shared.registerServicesMenuSendTypes(
            fileSendTypes,
            returnTypes: []
        )
    }

    @discardableResult
    static func appendToMenu(_ menu: NSMenu, fileURLs: [URL]) -> Bool {
        guard !fileURLs.isEmpty else { return false }
        // 已有自定义「服务」子菜单时，禁止系统再注入英文 Services 项。
        menu.allowsContextMenuPlugIns = false
        menu.addItem(.separator())
        let servicesItem = NSMenuItem(title: "服务", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        servicesItem.submenu = submenu
        menu.addItem(servicesItem)
        NSApplication.shared.servicesMenu = submenu
        return true
    }

    static func prepareForContextMenu(fileURLs: [URL], in view: NSView) {
        let previous = view.window?.firstResponder
        FileServicesMenuRequestor.shared.setContext(urls: fileURLs, previousFirstResponder: previous)
        view.window?.makeFirstResponder(view)
    }

    static func cleanupAfterContextMenu(in view: NSView?) {
        let requestor = FileServicesMenuRequestor.shared
        if let previous = requestor.restorableFirstResponder {
            view?.window?.makeFirstResponder(previous)
        }
        requestor.clearContext()
    }

    static func popUpContextMenu(
        _ menu: NSMenu,
        with event: NSEvent,
        for view: NSView,
        fileURLs: [URL]
    ) {
        guard !fileURLs.isEmpty else {
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            return
        }

        prepareForContextMenu(fileURLs: fileURLs, in: view)

        // 防止 popUpContextMenu 在自定义「服务」之外再追加系统 Services 插件项。
        menu.allowsContextMenuPlugIns = false

        let delegate = MenuCleanupDelegate(view: view)
        menuCleanupDelegate = delegate
        menu.delegate = delegate

        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }
}

private final class MenuCleanupDelegate: NSObject, NSMenuDelegate {
    private weak var view: NSView?

    init(view: NSView) {
        self.view = view
        super.init()
    }

    func menuDidClose(_ menu: NSMenu) {
        FileServicesMenuSupport.cleanupAfterContextMenu(in: view)
    }
}
