import SwiftUI
import AppKit
import Combine
import FileList

enum BlankDoubleClickAction: String, CaseIterable, Identifiable {
    case navigateToParent
    case openTerminal
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .navigateToParent:
            return L10n.Settings.General.blankActionParent
        case .openTerminal:
            return L10n.Settings.General.blankActionTerminal
        }
    }
}

struct FileCommandHandlers {
    var copy: (() -> Void)?
    var cut: (() -> Void)?
    var paste: (() -> Void)?
    var delete: (() -> Void)?
    var canCopy = false
    var canCut = false
    var canPaste = false
    var canDelete = false
}

struct FileCommandHandlersKey: FocusedValueKey {
    typealias Value = FileCommandHandlers
}

extension FocusedValues {
    var fileCommandHandlers: FileCommandHandlers? {
        get { self[FileCommandHandlersKey.self] }
        set { self[FileCommandHandlersKey.self] = newValue }
    }
}

struct TextFieldEditingKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var textFieldEditing: Bool? {
        get { self[TextFieldEditingKey.self] }
        set { self[TextFieldEditingKey.self] = newValue }
    }
}

struct FileCommands: Commands {
    @FocusedValue(\.fileCommandHandlers) private var handlers
    @FocusedValue(\.textFieldEditing) private var textFieldEditing
    @FocusedValue(\.previewTextSelectionActive) private var previewTextSelectionActive
    
    private var isTextFieldEditing: Bool { textFieldEditing == true }
    private var isPreviewTextSelectionActive: Bool { previewTextSelectionActive == true }
    
    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            if isTextFieldEditing {
                TextEditingCommands.pasteboardButtons()
            } else if isPreviewTextSelectionActive {
                TextEditingCommands.previewSelectionButtons()
            } else {
                Button(L10n.Action.cut) {
                    handlers?.cut?()
                }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(!(handlers?.canCut ?? false))
                
                Button(L10n.Action.copy) {
                    handlers?.copy?()
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(!(handlers?.canCopy ?? false))
                
                Button(L10n.Action.paste) {
                    handlers?.paste?()
                }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(!(handlers?.canPaste ?? false))
            }
        }
        
        CommandGroup(after: .pasteboard) {
            if !isTextFieldEditing {
                Button(L10n.Action.delete) {
                    handlers?.delete?()
                }
                .keyboardShortcut(.delete)
                .disabled(!(handlers?.canDelete ?? false))
            }
        }
    }
}

extension ToolbarContent {
    func hideSharedBackgroundIfAvailable() -> some ToolbarContent {
        self
    }
}

struct InlineToolbarTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.toolbarTitleDisplayMode(.inline)
        } else {
            content
        }
    }
}

// Lucide icons (ISC License) — https://lucide.dev
private enum LucideSVG {
    static func make(_ svg: String) -> Data {
        Data(svg.utf8)
    }

    static let folder = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>
""")
    static let file = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/></svg>
""")
    static let fileImage = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><circle cx="10" cy="12" r="2"/><path d="m20 17-1.296-1.296a2.41 2.41 0 0 0-3.408 0L9 22"/></svg>
""")
    static let fileVideo = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M15.033 13.44a.647.647 0 0 1 0 1.12l-4.065 2.352a.645.645 0 0 1-.968-.56v-4.704a.645.645 0 0 1 .967-.56z"/></svg>
""")
    static let fileAudio = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 6.835V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.706.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2h-.343"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M2 19a2 2 0 0 1 4 0v1a2 2 0 0 1-4 0v-4a6 6 0 0 1 12 0v4a2 2 0 0 1-4 0v-1a2 2 0 0 1 4 0"/></svg>
""")
    static let fileText = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M10 9H8"/><path d="M16 13H8"/><path d="M16 17H8"/></svg>
""")
    static let fileCode = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M10 12.5 8 15l2 2.5"/><path d="m14 12.5 2 2.5-2 2.5"/></svg>
""")
    static let fileArchive = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M13.659 22H18a2 2 0 0 0 2-2V8a2.4 2.4 0 0 0-.706-1.706l-3.588-3.588A2.4 2.4 0 0 0 14 2H6a2 2 0 0 0-2 2v11.5"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M8 12v-1"/><path d="M8 18v-2"/><path d="M8 7V6"/><circle cx="8" cy="20" r="2"/></svg>
""")
    static let fileSpreadsheet = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M8 13h2"/><path d="M14 13h2"/><path d="M8 17h2"/><path d="M14 17h2"/></svg>
""")
    static let presentation = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 3h20"/><path d="M21 3v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V3"/><path d="m7 21 5-5 5 5"/></svg>
""")
    static let fileJson = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M10 12a1 1 0 0 0-1 1v1a1 1 0 0 1-1 1 1 1 0 0 1 1 1v1a1 1 0 0 0 1 1"/><path d="M14 18a1 1 0 0 0 1-1v-1a1 1 0 0 1 1-1 1 1 0 0 1-1-1v-1a1 1 0 0 0-1-1"/></svg>
""")
    static let fileType = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M11 18h2"/><path d="M12 12v6"/><path d="M9 13v-.5a.5.5 0 0 1 .5-.5h5a.5.5 0 0 1 .5.5v.5"/></svg>
""")
    static let appWindow = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="4" width="20" height="16" rx="2"/><path d="M10 4v4"/><path d="M2 8h20"/><path d="M6 4v4"/></svg>
""")
    static let box = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16Z"/><path d="m3.3 7 8.7 5 8.7-5"/><path d="M12 22V12"/></svg>
""")
    static let terminal = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 19h8"/><path d="m4 17 6-6-6-6"/></svg>
""")
    static let database = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M3 5V19A9 3 0 0 0 21 19V5"/><path d="M3 12A9 3 0 0 0 21 12"/></svg>
""")
    static let settings = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9.671 4.136a2.34 2.34 0 0 1 4.659 0 2.34 2.34 0 0 0 3.319 1.915 2.34 2.34 0 0 1 2.33 4.033 2.34 2.34 0 0 0 0 3.831 2.34 2.34 0 0 1-2.33 4.033 2.34 2.34 0 0 0-3.319 1.915 2.34 2.34 0 0 1-4.659 0 2.34 2.34 0 0 0-3.32-1.915 2.34 2.34 0 0 1-2.33-4.033 2.34 2.34 0 0 0 0-3.831A2.34 2.34 0 0 1 6.35 6.051a2.34 2.34 0 0 0 3.319-1.915"/><circle cx="12" cy="12" r="3"/></svg>
""")
    static let folderPlus = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 10v6"/><path d="M9 13h6"/><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>
""")
    static let folderUp = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/><path d="M12 10v6"/><path d="m9 13 3-3 3 3"/></svg>
""")
}

struct LucideIcon: View {
    let svgData: Data
    var size: CGFloat = 16

    static let folderPlus = LucideIcon(svgData: LucideSVG.folderPlus)
    static let folderUp = LucideIcon(svgData: LucideSVG.folderUp)

    var body: some View {
        if let image = NSImage(data: svgData) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        }
    }
}

@main
struct ExplorerApp: App {
    @NSApplicationDelegateAdaptor(ExplorerAppDelegate.self) private var appDelegate
    @StateObject private var languageSettings = InterfaceLanguageSettings.shared
    @FocusedValue(\.windowLayoutCommands) private var windowLayoutCommands
    @FocusedValue(\.previewDetachCommands) private var previewDetachCommands
    @FocusedValue(\.previewBrowseCommands) private var previewBrowseCommands
    
    var body: some Scene {
        WindowGroup {
            FullDiskAccessGate {
                ContentView()
            }
            .frame(minWidth: 267, minHeight: 200)
            .applyInterfaceLanguageEnvironment()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            explorerCommands
        }

        WindowGroup(id: ExplorerWindowScene.folder, for: String.self) { $requestedPath in
            FullDiskAccessGate {
                ContentView(initialPath: requestedPath)
            }
            .frame(minWidth: 267, minHeight: 200)
            .applyInterfaceLanguageEnvironment()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))

        WindowGroup(id: ExplorerWindowScene.preview, for: PreviewWindowValue.self) { $value in
            Group {
                if let value {
                    DetachedPreviewWindowView(sessionID: value.sessionID)
                } else {
                    EmptyView()
                }
            }
            .applyInterfaceLanguageEnvironment()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .defaultSize(width: 640, height: 480)
        
        Settings {
            SettingsView()
                .applyInterfaceLanguageEnvironment()
        }
    }

    @CommandsBuilder
    private var explorerCommands: some Commands {
        let _ = languageSettings.revision
        FileCommands()
        CommandGroup(after: .sidebar) {
            Button(L10n.Menu.toggleLeftPanel) {
                windowLayoutCommands?.toggleLeftPanel()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleLeftPanel)

            Button(L10n.Menu.toggleRightPanel) {
                windowLayoutCommands?.toggleRightPanel()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleRightPanel)

            Divider()
            Button((windowLayoutCommands?.showPreview ?? true) ? L10n.Menu.hidePreview : L10n.Menu.showPreview) {
                windowLayoutCommands?.togglePreview()
            }
            Button((windowLayoutCommands?.showSnippets ?? true) ? L10n.Menu.hideSnippets : L10n.Menu.showSnippets) {
                windowLayoutCommands?.toggleSnippets()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleSnippets)
            Button((windowLayoutCommands?.isOutputPanelVisible ?? false) ? L10n.Menu.hideOutputPanel : L10n.Menu.showOutputPanel) {
                windowLayoutCommands?.toggleOutputPanel()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleOutputPanel)
            Divider()
            Button(L10n.Menu.importSnippets) {
                NotificationCenter.default.post(name: .snippetsImportRequested, object: nil)
            }
            Button(L10n.Menu.exportSnippets) {
                NotificationCenter.default.post(name: .snippetsExportAllRequested, object: nil)
            }
            Divider()
            Button(L10n.Menu.openPreviewDetached) {
                previewDetachCommands?.detachPreview?()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.detachPreview)
            .disabled(!(previewDetachCommands?.canDetach ?? false))
            Button(L10n.Menu.reattachPreview) {
                previewDetachCommands?.dockPreview?()
            }
            .disabled(!(previewDetachCommands?.canDock ?? false))
            Divider()
            Button(L10n.Menu.previousPreview) {
                previewBrowseCommands?.browsePrevious?()
            }
            .disabled(!(previewBrowseCommands?.canBrowsePrevious ?? false))
            Button(L10n.Menu.nextPreview) {
                previewBrowseCommands?.browseNext?()
            }
            .disabled(!(previewBrowseCommands?.canBrowseNext ?? false))
            Button(previewBrowseCommands?.isStripExpanded == true ? L10n.Menu.collapseStrip : L10n.Menu.expandStrip) {
                previewBrowseCommands?.toggleStrip?()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.togglePreviewBrowserStrip)
            .disabled(!(previewBrowseCommands?.canToggleStrip ?? false))
        }
    }
}

extension Notification.Name {
    static let snippetsImportRequested = Notification.Name("snippetsImportRequested")
    static let snippetsExportAllRequested = Notification.Name("snippetsExportAllRequested")
}

@MainActor
final class ExternalFolderOpenCenter: ObservableObject {
    static let shared = ExternalFolderOpenCenter()

    struct OpenRequest: Equatable {
        let directoryPath: String
        let selectionPath: String?
    }

    @Published private(set) var targetRequest: OpenRequest?
    private var pendingRequest: OpenRequest?
    private var openFolderWindow: ((String) -> Void)?

    private init() {}

    func setOpenFolderWindowHandler(_ handler: @escaping (String) -> Void) {
        openFolderWindow = handler
    }

    func requestOpen(urls: [URL]) {
        guard let resolvedRequest = resolveOpenRequest(from: urls) else { return }
        pendingRequest = resolvedRequest
        targetRequest = resolvedRequest
    }

    func consumePendingRequest() -> OpenRequest? {
        let request = pendingRequest
        pendingRequest = nil
        return request
    }

    func requestOpenInNewWindow(directoryPath: String) {
        let standardized = (directoryPath as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        openFolderWindow?(standardized)
    }

    private func resolveOpenRequest(from urls: [URL]) -> OpenRequest? {
        for url in urls {
            let standardized = url.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else {
                continue
            }
            if isDirectory.boolValue {
                return OpenRequest(
                    directoryPath: standardized.path,
                    selectionPath: nil
                )
            }
            let parentDirectory = standardized.deletingLastPathComponent()
            guard parentDirectory.path != standardized.path else { continue }
            return OpenRequest(
                directoryPath: parentDirectory.path,
                selectionPath: standardized.path
            )
        }
        return nil
    }
}

struct ExternalNavigationTarget: Equatable {
    let directoryPath: String
    let selectionPath: String?
}

private final class ExplorerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        ModuleLocalization.applyAppleLanguagesOverride()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        FileServicesMenuSupport.registerIfNeeded()
        AppMemoryPressure.installHandler()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            ExternalFolderOpenCenter.shared.requestOpen(urls: urls)
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        Task { @MainActor in
            ExternalFolderOpenCenter.shared.requestOpen(urls: urls)
        }
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        Task { @MainActor in
            ExternalFolderOpenCenter.shared.requestOpen(
                urls: [URL(fileURLWithPath: filename)]
            )
        }
        return true
    }
}