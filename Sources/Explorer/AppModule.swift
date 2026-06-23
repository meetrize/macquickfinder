import SwiftUI
import AppKit
import ApplicationServices
import Combine
import PDFKit
import AVKit
import QuickLookUI
import UniformTypeIdentifiers
import ImageIO
import WebKit
import FileList

enum BlankDoubleClickAction: String, CaseIterable, Identifiable {
    case navigateToParent
    case openTerminal
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .navigateToParent:
            return "返回上级目录"
        case .openTerminal:
            return "在本目录打开终端"
        }
    }
}

private enum AppSettings {
    static let blankDoubleClickActionKey = "blankDoubleClickAction"
    static let previewPanelWidthKey = "previewPanelWidth"
    static let favoritesKey = "favoriteLocations"
    static let trashRestoreRecordsKey = "trashRestoreRecords"
    static let autoCalculateDirectorySizesKey = DirectorySizePreferences.autoCalculateKey
    static let leftPanelModeKey = "leftPanelMode"
    static let leftPanelLastVisibleModeKey = "leftPanelLastVisibleMode"
    static let leftPanelSidebarWidthKey = "leftPanelSidebarWidth"
    static let lastOpenedPathKey = "lastOpenedPath"
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

private enum TextEditingCommands {
    static func send(_ selector: Selector) {
        NSApp.sendAction(selector, to: nil, from: nil)
    }
    
    @ViewBuilder
    static func pasteboardButtons() -> some View {
        Button("全选") {
            send(#selector(NSText.selectAll(_:)))
        }
        .keyboardShortcut("a", modifiers: .command)
        
        Button("剪切") {
            send(#selector(NSText.cut(_:)))
        }
        .keyboardShortcut("x", modifiers: .command)
        
        Button("复制") {
            send(#selector(NSText.copy(_:)))
        }
        .keyboardShortcut("c", modifiers: .command)
        
        Button("粘贴") {
            send(#selector(NSText.paste(_:)))
        }
        .keyboardShortcut("v", modifiers: .command)
    }
}

/// 地址栏、搜索栏共用的极简输入框样式：浅背景 + 1px 细边框，无阴影。
private struct TextEditingKeyMonitor: NSViewRepresentable {
    let isBarFieldEditing: Bool
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.install(on: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isBarFieldEditing = isBarFieldEditing
    }
    
    final class Coordinator {
        var isBarFieldEditing = false
        private var monitor: Any?
        
        func install(on view: NSView) {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self else { return event }
                return self.handleKeyDown(event)
            }
        }
        
        private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
            guard isBarFieldEditing else { return event }
            guard event.modifierFlags.contains(.command) else { return event }
            guard let key = event.charactersIgnoringModifiers?.lowercased() else { return event }
            
            let selector: Selector?
            switch key {
            case "a": selector = #selector(NSText.selectAll(_:))
            case "c": selector = #selector(NSText.copy(_:))
            case "v": selector = #selector(NSText.paste(_:))
            case "x": selector = #selector(NSText.cut(_:))
            default: selector = nil
            }
            
            guard let selector else { return event }
            TextEditingCommands.send(selector)
            return nil
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

struct FileCommands: Commands {
    @FocusedValue(\.fileCommandHandlers) private var handlers
    @FocusedValue(\.textFieldEditing) private var textFieldEditing
    
    private var isTextFieldEditing: Bool { textFieldEditing == true }
    
    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            if isTextFieldEditing {
                TextEditingCommands.pasteboardButtons()
            } else {
                Button("剪切") {
                    handlers?.cut?()
                }
                .keyboardShortcut("x", modifiers: .command)
                .disabled(!(handlers?.canCut ?? false))
                
                Button("复制") {
                    handlers?.copy?()
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(!(handlers?.canCopy ?? false))
                
                Button("粘贴") {
                    handlers?.paste?()
                }
                .keyboardShortcut("v", modifiers: .command)
                .disabled(!(handlers?.canPaste ?? false))
            }
        }
        
        CommandGroup(after: .pasteboard) {
            if !isTextFieldEditing {
                Button("删除") {
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

private struct InlineToolbarTitleModifier: ViewModifier {
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

private struct LucideIcon: View {
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
    @FocusedValue(\.windowLayoutCommands) private var windowLayoutCommands
    @FocusedValue(\.previewDetachCommands) private var previewDetachCommands
    @FocusedValue(\.previewBrowseCommands) private var previewBrowseCommands
    
    var body: some Scene {
        WindowGroup {
            FullDiskAccessGate {
                ContentView()
            }
            .frame(minWidth: 267, minHeight: 200)
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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))

        WindowGroup(id: ExplorerWindowScene.preview, for: PreviewWindowValue.self) { $value in
            if let value {
                DetachedPreviewWindowView(sessionID: value.sessionID)
            } else {
                EmptyView()
            }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .defaultSize(width: 640, height: 480)
        
        Settings {
            SettingsView()
        }
    }

    @CommandsBuilder
    private var explorerCommands: some Commands {
        FileCommands()
        CommandGroup(after: .sidebar) {
            Button("切换左侧面板") {
                windowLayoutCommands?.toggleLeftPanel()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleLeftPanel)

            Button("切换右侧面板") {
                windowLayoutCommands?.toggleRightPanel()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleRightPanel)

            Divider()
            Button((windowLayoutCommands?.showPreview ?? true) ? "关闭预览" : "显示预览") {
                windowLayoutCommands?.togglePreview()
            }
            Button((windowLayoutCommands?.showSnippets ?? true) ? "关闭 Snippets" : "显示 Snippets") {
                windowLayoutCommands?.toggleSnippets()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleSnippets)
            Button((windowLayoutCommands?.isOutputPanelVisible ?? false) ? "关闭输出面板" : "显示输出面板") {
                windowLayoutCommands?.toggleOutputPanel()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleOutputPanel)
            Divider()
            Button("导入 Snippets…") {
                NotificationCenter.default.post(name: .snippetsImportRequested, object: nil)
            }
            Button("导出全部 Snippets…") {
                NotificationCenter.default.post(name: .snippetsExportAllRequested, object: nil)
            }
            Divider()
            Button("在独立窗口中打开预览") {
                previewDetachCommands?.detachPreview?()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.detachPreview)
            .disabled(!(previewDetachCommands?.canDetach ?? false))
            Button("收回预览到侧栏") {
                previewDetachCommands?.dockPreview?()
            }
            .disabled(!(previewDetachCommands?.canDock ?? false))
            Divider()
            Button("上一个预览") {
                previewBrowseCommands?.browsePrevious?()
            }
            .disabled(!(previewBrowseCommands?.canBrowsePrevious ?? false))
            Button("下一个预览") {
                previewBrowseCommands?.browseNext?()
            }
            .disabled(!(previewBrowseCommands?.canBrowseNext ?? false))
            Button(previewBrowseCommands?.isStripExpanded == true ? "收起胶片条" : "展开胶片条") {
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
private final class ExternalFolderOpenCenter: ObservableObject {
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

private struct ExternalNavigationTarget: Equatable {
    let directoryPath: String
    let selectionPath: String?
}

private extension ExternalNavigationTarget {
    init(request: ExternalFolderOpenCenter.OpenRequest) {
        self.init(
            directoryPath: request.directoryPath,
            selectionPath: request.selectionPath
        )
    }
}

private extension ContentView {
    func applyExternalNavigationTarget(_ target: ExternalNavigationTarget) {
        pendingExternalSelectionPath = target.selectionPath
        if path == target.directoryPath {
            loadItems()
        } else {
            path = target.directoryPath
        }
    }

    func applyPendingExternalSelectionIfNeeded(loadedItems: [FileItem], for directoryPath: String) {
        guard directoryPath == path else { return }
        guard let pendingExternalSelectionPath else { return }
        defer { self.pendingExternalSelectionPath = nil }
        guard loadedItems.contains(where: { $0.id == pendingExternalSelectionPath }) else { return }
        selection = [pendingExternalSelectionPath]
    }
}

private final class ExplorerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        FileServicesMenuSupport.registerIfNeeded()
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

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    @State private var previewPrefillExtension: String?
    @State private var showPreviewRuleEditor = false

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsTab()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
                .tag(SettingsTab.general)

            SnippetsSettingsTab()
                .tabItem {
                    Label("Snippets", systemImage: "terminal")
                }
                .tag(SettingsTab.snippets)

            PreviewSettingsTab(
                prefillExtension: $previewPrefillExtension,
                showEditor: $showPreviewRuleEditor
            )
            .tabItem {
                Label("预览", systemImage: "eye")
            }
            .tag(SettingsTab.preview)

            AdvancedSettingsTab()
                .tabItem {
                    Label("高级", systemImage: "slider.horizontal.3")
                }
                .tag(SettingsTab.advanced)
        }
        .frame(width: 520, height: 460)
        .onAppear {
            if let ext = SettingsWindowPresenter.shared.consumePendingPrefillExtension() {
                selectedTab = .preview
                previewPrefillExtension = ext
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPreviewSettingsRequested)) { notification in
            selectedTab = .preview
            if let ext = notification.userInfo?["extension"] as? String {
                previewPrefillExtension = ext
            }
        }
    }
}

private struct SnippetsSettingsTab: View {
    @ObservedObject private var settings = SnippetsSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("最近执行置顶", isOn: $settings.pinRecentlyExecutedSnippets)
                Stepper(value: $settings.maxConcurrentJobs, in: 1...4) {
                    Text("Job 并发上限：\(settings.maxConcurrentJobs)")
                }
                Toggle("Shell 执行时自动展开输出面板", isOn: $settings.autoShowOutputPanelOnShellRun)
                Toggle("危险命令二次确认", isOn: $settings.confirmDestructiveSnippets)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.blankDoubleClickActionKey)
    private var blankDoubleClickAction = BlankDoubleClickAction.navigateToParent.rawValue
    @AppStorage(ExplorerAppSettings.windowSnapEnabledKey)
    private var windowSnapEnabled = true
    @StateObject private var defaultFileViewerSettings = DefaultFileViewerSettingsModel()
    
    var body: some View {
        Form {
            Section {
                Picker("空白处双击", selection: $blankDoubleClickAction) {
                    ForEach(BlankDoubleClickAction.allCases) { action in
                        Text(action.displayName).tag(action.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Toggle("启用窗口吸附与联动移动", isOn: $windowSnapEnabled)
            }

            DefaultFileViewerSettingsSection(model: defaultFileViewerSettings, style: .compact)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            defaultFileViewerSettings.refresh()
        }
    }
}

private struct AdvancedSettingsTab: View {
    @StateObject private var defaultFileViewerSettings = DefaultFileViewerSettingsModel()

    var body: some View {
        Form {
            DefaultFileViewerSettingsSection(model: defaultFileViewerSettings, style: .detailed)
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            defaultFileViewerSettings.refresh()
        }
    }
}

private enum DefaultFileViewerSettingsSectionStyle {
    case compact
    case detailed
}

private struct DefaultFileViewerSettingsSection: View {
    @ObservedObject var model: DefaultFileViewerSettingsModel
    let style: DefaultFileViewerSettingsSectionStyle

    var body: some View {
        Section {
            LabeledContent("当前默认") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(model.isDefault ? Color.green : Color.secondary.opacity(0.5))
                        .frame(width: 8, height: 8)
                    Text(model.currentHandlerName)
                }
            }

            HStack {
                Button("设为默认文件夹查看器") {
                    model.setAsDefault()
                }
                .disabled(model.isDefault || model.isApplying)

                Button("恢复 Finder") {
                    model.restoreFinder()
                }
                .disabled(model.isFinderDefault || model.isApplying)
            }

            if model.showsRestartReminder {
                Text("更改后请注销并重新登录，或重启 Mac，才能在全部场景中生效。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if style == .detailed {
                Text("可将 MeoFind 设为系统默认文件夹查看器，使多数应用中的「在 Finder 中显示」等操作打开本应用。无法替代桌面图标、Dock 中的 Finder，以及系统自带的打开/保存对话框。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("默认文件夹查看器")
        }
        .alert("默认文件夹查看器", isPresented: alertBinding) {
            Button("好", role: .cancel) {
                model.alertMessage = nil
            }
        } message: {
            if let alertMessage = model.alertMessage {
                Text(alertMessage)
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { model.alertMessage != nil },
            set: { isPresented in
                if !isPresented {
                    model.alertMessage = nil
                }
            }
        )
    }
}

enum BarTextFieldID: Hashable {
    case path
    case search
}

/// 按窗口记录各输入框对应的 NSTextField，多窗口互不干扰。
private enum BarTextFieldFocusRegistry {
    private final class WindowState {
        weak var pathField: NSTextField?
        weak var searchField: NSTextField?
        weak var pathBarRoot: NSView?
        weak var pathNavigateButton: NSView?
        weak var pathBarBlankClickArea: NSView?
        var pendingSelectAll: BarTextFieldID?
    }

    private static let states = NSMapTable<NSWindow, WindowState>.weakToStrongObjects()

    private static func state(for window: NSWindow) -> WindowState {
        if let existing = states.object(forKey: window) { return existing }
        let created = WindowState()
        states.setObject(created, forKey: window)
        return created
    }

    private static func state(for view: NSView) -> WindowState? {
        guard let window = view.window else { return nil }
        return state(for: window)
    }

    private static func field(for id: BarTextFieldID, in window: NSWindow) -> NSTextField? {
        let windowState = state(for: window)
        switch id {
        case .path: return windowState.pathField
        case .search: return windowState.searchField
        }
    }

    static func register(_ field: NSTextField, for id: BarTextFieldID) {
        guard let window = field.window else { return }
        let windowState = state(for: window)
        switch id {
        case .path: windowState.pathField = field
        case .search: windowState.searchField = field
        }
    }

    static func requestSelectAll(_ id: BarTextFieldID, in window: NSWindow) {
        state(for: window).pendingSelectAll = id
    }

    static func applyPendingSelectAll(for id: BarTextFieldID, in window: NSWindow) {
        let windowState = state(for: window)
        guard windowState.pendingSelectAll == id else { return }
        windowState.pendingSelectAll = nil
        selectAll(id, in: window)
    }

    static func clearPendingSelectAll(in window: NSWindow) {
        state(for: window).pendingSelectAll = nil
    }

    static func hasPendingSelectAll(_ id: BarTextFieldID, in window: NSWindow) -> Bool {
        state(for: window).pendingSelectAll == id
    }

    static func focus(_ id: BarTextFieldID, in window: NSWindow) {
        guard let field = field(for: id, in: window) else { return }
        window.makeFirstResponder(field)
    }

    static func selectAll(_ id: BarTextFieldID, in window: NSWindow) {
        if id == .path, let field = field(for: .path, in: window) as? PathBarTextField {
            field.prepareSelectAllOnFocus()
            field.selectAllText()
            return
        }
        guard let field = field(for: id, in: window) else { return }
        if field.currentEditor() == nil {
            field.selectText(nil)
        }
        if let editor = field.currentEditor() {
            window.makeFirstResponder(editor)
            editor.selectAll(nil)
        } else {
            window.makeFirstResponder(field)
            field.selectText(nil)
            field.currentEditor()?.selectAll(nil)
        }
    }

    /// 聚焦路径/搜索框并立刻全选；若 field editor 尚未就绪则短轮询补齐。
    static func focusAndSelectAll(_ id: BarTextFieldID, in window: NSWindow) {
        requestSelectAll(id, in: window)
        guard let field = field(for: id, in: window), field.window != nil else {
            focusWhenReady(id, in: window, selectAll: true)
            return
        }
        focus(id, in: window)
        if field.currentEditor() == nil {
            field.selectText(nil)
        }
        selectAll(id, in: window)
        guard hasActiveFieldEditor(field) else {
            focusWhenReady(id, in: window, selectAll: true)
            return
        }
        DispatchQueue.main.async {
            selectAll(id, in: window)
        }
    }

    static func focusWhenReady(
        _ id: BarTextFieldID,
        in window: NSWindow,
        selectAll: Bool = false,
        onComplete: ((Bool) -> Void)? = nil,
        attempt: Int = 0
    ) {
        guard attempt < 30 else {
            onComplete?(false)
            return
        }
        guard let field = field(for: id, in: window), field.window != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                focusWhenReady(id, in: window, selectAll: selectAll, onComplete: onComplete, attempt: attempt + 1)
            }
            return
        }

        focus(id, in: window)
        if field.currentEditor() == nil {
            field.selectText(nil)
        }
        if let editor = field.currentEditor() {
            field.window?.makeFirstResponder(editor)
        }

        guard hasActiveFieldEditor(field) else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                focusWhenReady(id, in: window, selectAll: selectAll, onComplete: onComplete, attempt: attempt + 1)
            }
            return
        }

        if selectAll {
            requestSelectAll(id, in: window)
            Self.selectAll(id, in: window)
            DispatchQueue.main.async {
                Self.selectAll(id, in: window)
                onComplete?(true)
            }
        } else {
            onComplete?(true)
        }
    }

    static func resign(_ id: BarTextFieldID, in window: NSWindow) {
        guard let field = field(for: id, in: window) else { return }
        guard isFieldEditing(field) else { return }
        window.makeFirstResponder(nil)
    }

    /// 结束 field editor，确保下次进入文本模式时 textDidBeginEditing 会再次触发。
    static func endEditing(_ id: BarTextFieldID, in window: NSWindow) {
        guard let field = field(for: id, in: window) else { return }
        if field.currentEditor() != nil {
            field.abortEditing()
        }
        window.makeFirstResponder(nil)
    }

    static func isClickInside(_ id: BarTextFieldID, event: NSEvent) -> Bool {
        guard let window = event.window,
              let field = field(for: id, in: window),
              let contentView = window.contentView,
              let hitView = contentView.hitTest(event.locationInWindow) else {
            return false
        }
        return hitView === field || hitView.isDescendant(of: field)
    }

    static func isClickInsideNavigateButton(event: NSEvent) -> Bool {
        guard let window = event.window,
              let button = state(for: window).pathNavigateButton,
              let contentView = window.contentView,
              let hitView = contentView.hitTest(event.locationInWindow) else {
            return false
        }
        return hitView === button || hitView.isDescendant(of: button)
    }

    static func isClickInsidePathBar(event: NSEvent) -> Bool {
        if isClickInsideNavigateButton(event: event) { return true }
        if isClickInside(.path, event: event) { return true }
        guard let window = event.window else { return false }
        let windowState = state(for: window)
        if isClickInsideRegisteredView(windowState.pathBarBlankClickArea, event: event) { return true }
        return isClickInsideRegisteredView(windowState.pathBarRoot, event: event)
    }

    static func registerPathBarRoot(_ view: NSView) {
        guard let windowState = state(for: view) else { return }
        windowState.pathBarRoot = view
    }

    static func registerPathNavigateButton(_ view: NSView) {
        guard let windowState = state(for: view) else { return }
        windowState.pathNavigateButton = view
    }

    static func registerPathBarBlankClickArea(_ view: NSView) {
        guard let windowState = state(for: view) else { return }
        windowState.pathBarBlankClickArea = view
    }

    private static func isClickInsideRegisteredView(_ view: NSView?, event: NSEvent) -> Bool {
        guard let view, view.window != nil else { return false }
        let point = view.convert(event.locationInWindow, from: nil)
        return view.bounds.contains(point)
    }

    static func currentEditingField(in window: NSWindow) -> BarTextFieldID? {
        let windowState = state(for: window)
        if let searchField = windowState.searchField, hasActiveFieldEditor(searchField) { return .search }
        if let pathField = windowState.pathField, hasActiveFieldEditor(pathField) { return .path }
        return nil
    }

    private static func hasActiveFieldEditor(_ field: NSTextField) -> Bool {
        guard let editor = field.currentEditor() else { return false }
        guard let window = field.window, let responder = window.firstResponder else { return false }
        if responder === editor { return true }
        if let view = responder as? NSView, view.isDescendant(of: editor) { return true }
        return false
    }

    private static func isFieldEditing(_ field: NSTextField) -> Bool {
        if hasActiveFieldEditor(field) { return true }
        guard let window = field.window, let responder = window.firstResponder else { return false }
        if responder === field { return field.currentEditor() != nil }
        if let view = responder as? NSView, view.isDescendant(of: field) { return true }
        return false
    }
}

/// 绑定当前 SwiftUI 视图所在的 NSWindow，供地址栏/搜索栏按窗口隔离焦点状态。
private struct HostWindowReader: NSViewRepresentable {
    @Binding var window: NSWindow?

    func makeNSView(context: Context) -> TrackerView {
        let view = TrackerView()
        view.onWindowChange = { newWindow in
            DispatchQueue.main.async {
                window = newWindow
            }
        }
        return view
    }

    func updateNSView(_ nsView: TrackerView, context: Context) {
        nsView.reportWindow()
    }

    final class TrackerView: NSView {
        var onWindowChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            reportWindow()
        }

        func reportWindow() {
            onWindowChange?(window)
        }
    }
}

/// 地址栏/搜索栏有焦点时，点击外部同步失焦；点击文件列表时在同一次点击中选中对应行。
private struct BarFieldOutsideClickHandler: NSViewRepresentable {
    @Binding var activeField: BarTextFieldID?
    @Binding var isPathBarTextMode: Bool
    let tableItems: [FileItem]
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            activeField: $activeField,
            isPathBarTextMode: $isPathBarTextMode,
            tableItems: tableItems
        )
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.anchorView = view
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.tableItems = tableItems
    }
    
    final class Coordinator {
        @Binding var activeField: BarTextFieldID?
        @Binding var isPathBarTextMode: Bool
        var tableItems: [FileItem]
        weak var anchorView: NSView?
        private var monitor: Any?
        
        init(
            activeField: Binding<BarTextFieldID?>,
            isPathBarTextMode: Binding<Bool>,
            tableItems: [FileItem]
        ) {
            _activeField = activeField
            _isPathBarTextMode = isPathBarTextMode
            self.tableItems = tableItems
        }
        
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
                self?.handleMouseDown(event)
                return event
            }
        }
        
        private func handleMouseDown(_ event: NSEvent) {
            guard let window = event.window else { return }
            guard window === anchorView?.window else { return }
            let editingField = BarTextFieldFocusRegistry.currentEditingField(in: window)
            let shouldDismissPathText = isPathBarTextMode
            guard editingField != nil || shouldDismissPathText else { return }
            
            if BarTextFieldFocusRegistry.isClickInsideNavigateButton(event: event) {
                return
            }
            
            if isPathBarTextMode,
               BarTextFieldFocusRegistry.isClickInsidePathBar(event: event)
                || BarTextFieldFocusRegistry.isClickInside(.path, event: event) {
                return
            }
            
            if let editingField, BarTextFieldFocusRegistry.isClickInside(editingField, event: event) {
                return
            }
            
            if let editingField {
                if shouldDismissPathText, editingField == .path {
                    BarTextFieldFocusRegistry.endEditing(.path, in: window)
                } else {
                    BarTextFieldFocusRegistry.resign(editingField, in: window)
                }
                if activeField == editingField {
                    activeField = nil
                }
            }
            
            if shouldDismissPathText {
                isPathBarTextMode = false
            }
            
            guard let tableView = tableView(at: event) else { return }
            guard let window = tableView.window ?? event.window else { return }
            
            if let headerView = tableView.headerView {
                let pointInHeader = headerView.convert(event.locationInWindow, from: nil)
                if headerView.bounds.contains(pointInHeader) {
                    return
                }
            }
            
            window.makeFirstResponder(tableView)
            
            let point = tableView.convert(event.locationInWindow, from: nil)
            let row = tableView.row(at: point)
            Self.selectRow(
                row,
                in: tableView,
                event: event,
                items: tableItems
            )
        }
        
        private func tableView(at event: NSEvent) -> NSTableView? {
            guard let window = event.window,
                  let contentView = window.contentView,
                  let hitView = contentView.hitTest(event.locationInWindow) else {
                return nil
            }
            return findTableView(from: hitView)
        }
        
        private func findTableView(from view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let node = current {
                if let tableView = node as? NSTableView {
                    return tableView
                }
                current = node.superview
            }
            return nil
        }
        
        private static func selectRow(
            _ row: Int,
            in tableView: NSTableView,
            event: NSEvent,
            items: [FileItem]
        ) {
            guard row >= 0, row < items.count else {
                if row < 0 {
                    tableView.deselectAll(nil)
                }
                return
            }
            
            let item = items[row]
            let flags = event.modifierFlags
            
            if flags.contains(.command) {
                var selected = tableView.selectedRowIndexes
                if selected.contains(row) {
                    selected.remove(row)
                } else {
                    selected.insert(row)
                }
                tableView.selectRowIndexes(selected, byExtendingSelection: false)
                return
            }
            
            if flags.contains(.shift) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: true)
                return
            }
            
            var effectiveIDs = Set<FileItem.ID>()
            for selectedRow in tableView.selectedRowIndexes {
                guard selectedRow >= 0, selectedRow < items.count else { continue }
                let rowItem = items[selectedRow]
                guard !rowItem.isParentDirectoryEntry else { continue }
                effectiveIDs.insert(rowItem.id)
            }
            
            if effectiveIDs.contains(item.id) {
                return
            }
            
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

/// 根据当前 firstResponder 同步高亮状态，避免 SwiftUI FocusState 与工具栏输入框冲突。
private struct BarTextFieldFocusSync: NSViewRepresentable {
    @Binding var activeField: BarTextFieldID?
    
    func makeCoordinator() -> Coordinator {
        Coordinator(activeField: $activeField)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.anchorView = view
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.anchorView = nsView
        context.coordinator.syncFromResponder()
    }
    
    final class Coordinator {
        @Binding var activeField: BarTextFieldID?
        weak var anchorView: NSView?
        private var monitor: Any?
        
        init(activeField: Binding<BarTextFieldID?>) {
            _activeField = activeField
        }
        
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
                if event.type == .leftMouseDown {
                    guard let self, event.window === self.anchorView?.window else { return event }
                    self.syncFromResponder(for: event.window)
                } else {
                    DispatchQueue.main.async {
                        self?.syncFromResponder(for: self?.anchorView?.window)
                    }
                }
                return event
            }
        }
        
        /// 仅在有真实 field editor 时提升 activeField，避免同一次点击把尚未完成的聚焦清回 nil。
        fileprivate func syncFromResponder(for eventWindow: NSWindow? = nil) {
            guard let window = eventWindow ?? anchorView?.window else { return }
            guard let current = BarTextFieldFocusRegistry.currentEditingField(in: window) else { return }
            guard activeField != current else { return }
            activeField = current
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}

enum BarTextFieldShape {
    case rounded
    case capsule
}

/// 工具栏内的 TextField 有时无法可靠同步 @FocusState，通过 NSTextField 编辑状态驱动边框高亮。
private struct BarTextFieldFocusObserver: NSViewRepresentable {
    let fieldID: BarTextFieldID
    @Binding var activeField: BarTextFieldID?
    var retainHighlight: Bool = false
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fieldID: fieldID, activeField: $activeField)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        let wasRetainHighlight = context.coordinator.retainHighlight
        context.coordinator.retainHighlight = retainHighlight
        context.coordinator.refreshEditingState()
        if fieldID == .path, retainHighlight, !wasRetainHighlight,
           let window = context.coordinator.textField?.window {
            BarTextFieldFocusRegistry.applyPendingSelectAll(for: .path, in: window)
            BarTextFieldFocusRegistry.selectAll(.path, in: window)
        }
    }
    
    final class Coordinator {
        let fieldID: BarTextFieldID
        @Binding var activeField: BarTextFieldID?
        var retainHighlight = false
        private weak var anchorView: NSView?
        fileprivate weak var textField: NSTextField?
        private var observers: [NSObjectProtocol] = []
        private var retryCount = 0
        private var isHooked = false
        
        init(fieldID: BarTextFieldID, activeField: Binding<BarTextFieldID?>) {
            self.fieldID = fieldID
            _activeField = activeField
        }
        
        func attach(to view: NSView) {
            guard !isHooked else { return }
            anchorView = view
            retryCount = 0
            hookTextFieldIfNeeded()
        }
        
        private func hookTextFieldIfNeeded() {
            guard !isHooked, let anchorView else { return }
            
            guard let field = findAssociatedTextField(from: anchorView) else {
                guard retryCount < 20 else { return }
                retryCount += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.hookTextFieldIfNeeded()
                }
                return
            }
            
            isHooked = true
            textField = field
            BarTextFieldFocusRegistry.register(field, for: fieldID)
            let center = NotificationCenter.default
            observers.append(
                center.addObserver(
                    forName: NSControl.textDidBeginEditingNotification,
                    object: field,
                    queue: .main
                ) { [weak self] _ in
                    guard let self else { return }
                    self.activateField()
                    if let window = self.textField?.window {
                        BarTextFieldFocusRegistry.applyPendingSelectAll(for: self.fieldID, in: window)
                    }
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSControl.textDidEndEditingNotification,
                    object: field,
                    queue: .main
                ) { [weak self] _ in
                    self?.refreshEditingState()
                }
            )
            observers.append(
                center.addObserver(
                    forName: NSWindow.didBecomeKeyNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.refreshEditingState()
                }
            )
            refreshEditingState()
        }
        
        private func activateField() {
            activeField = fieldID
        }
        
        private func deactivateFieldIfNeeded() {
            guard activeField == fieldID else { return }
            if let window = textField?.window {
                activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
            } else {
                activeField = nil
            }
        }
        
        fileprivate func refreshEditingState() {
            guard textField != nil else { return }
            if let window = textField?.window,
               BarTextFieldFocusRegistry.currentEditingField(in: window) == fieldID {
                activateField()
            } else if !retainHighlight {
                deactivateFieldIfNeeded()
            }
        }
        
        private func findAssociatedTextField(from anchor: NSView) -> NSTextField? {
            if let field = anchor as? NSTextField { return field }
            
            var current: NSView? = anchor
            while let node = current {
                for subview in node.subviews {
                    guard subview === anchor || anchor.isDescendant(of: subview) else { continue }
                    if let field = subview as? NSTextField { return field }
                    if let field = findTextField(in: subview) { return field }
                }
                current = node.superview
            }
            return nil
        }
        
        private func findTextField(in view: NSView) -> NSTextField? {
            if let field = view as? NSTextField { return field }
            for subview in view.subviews {
                if let field = findTextField(in: subview) { return field }
            }
            return nil
        }
        
        deinit {
            observers.forEach { NotificationCenter.default.removeObserver($0) }
        }
    }
}

struct BarTextField: View {
    let fieldID: BarTextFieldID
    let prompt: String
    @Binding var text: String
    @Binding var activeField: BarTextFieldID?
    var icon: String? = nil
    var shape: BarTextFieldShape = .rounded
    var showsClearButton = false
    var onSubmit: (() -> Void)? = nil
    
    private let cornerRadius: CGFloat = 7
    private let fieldHeight: CGFloat = 28
    
    private var showsFocusBorder: Bool {
        activeField == fieldID
    }
    
    private var borderColor: Color {
        showsFocusBorder ? Color.accentColor : Color(nsColor: .separatorColor)
    }
    
    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
                .onSubmit { onSubmit?() }
                .background(
                    BarTextFieldFocusObserver(fieldID: fieldID, activeField: $activeField)
                )
            
            if showsClearButton, !text.isEmpty {
                Button {
                    text = ""
                    activeField = fieldID
                    if let window = NSApp.keyWindow {
                        BarTextFieldFocusRegistry.focus(fieldID, in: window)
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("清除")
            }
        }
        .padding(.horizontal, shape == .capsule ? 10 : 8)
        .frame(height: fieldHeight)
        .background {
            Group {
                switch shape {
                case .rounded:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                case .capsule:
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
            }
            .allowsHitTesting(false)
        }
        .overlay {
            Group {
                switch shape {
                case .rounded:
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                case .capsule:
                    Capsule(style: .continuous)
                        .strokeBorder(borderColor, lineWidth: 1)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Path Bar

/// 地址栏路径输入框：进入编辑时在 becomeFirstResponder / textDidBeginEditing 中可靠全选。
final class PathBarTextField: NSTextField {
    var selectAllOnFocus = false
    var onCommit: (() -> Void)?
    var onTextChange: ((String) -> Void)?
    var onEditingBegan: (() -> Void)?
    var onEditingEnded: (() -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        isEditable = true
        isSelectable = true
        isBordered = false
        isBezeled = false
        drawsBackground = false
        focusRingType = .none
        backgroundColor = .clear
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingMiddle
        cell?.wraps = false
        cell?.isScrollable = true
        font = .systemFont(ofSize: NSFont.systemFontSize)
        delegate = self
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard alphaValue > 0.01 else { return nil }
        return super.hitTest(point)
    }
    
    override func becomeFirstResponder() -> Bool {
        let focused = super.becomeFirstResponder()
        if focused {
            onEditingBegan?()
            applySelectAllIfNeeded()
        }
        return focused
    }
    
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            onEditingEnded?()
        }
        return resigned
    }
    
    func prepareSelectAllOnFocus() {
        selectAllOnFocus = true
    }
    
    func selectAllText() {
        guard window != nil else { return }
        if currentEditor() == nil {
            if window?.firstResponder !== self {
                window?.makeFirstResponder(self)
            }
            selectText(nil)
        }
        if let editor = currentEditor() {
            window?.makeFirstResponder(editor)
            editor.selectAll(nil)
        }
    }
    
    private func applySelectAllIfNeeded() {
        guard selectAllOnFocus else { return }
        selectAllText()
        selectAllOnFocus = false
    }
}

extension PathBarTextField: NSTextFieldDelegate {
    func controlTextDidBeginEditing(_ obj: Notification) {
        applySelectAllIfNeeded()
    }
    
    func controlTextDidChange(_ obj: Notification) {
        onTextChange?(stringValue)
    }
    
    func controlTextDidEndEditing(_ obj: Notification) {
        onEditingEnded?()
    }
    
    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            onCommit?()
            return true
        }
        return false
    }
}

private struct PathBarTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    @Binding var activeField: BarTextFieldID?
    var isVisible: Bool
    var retainHighlight: Bool
    var onSubmit: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, activeField: $activeField)
    }
    
    func makeNSView(context: Context) -> PathBarTextField {
        let field = PathBarTextField()
        field.stringValue = text
        field.onCommit = { [weak coordinator = context.coordinator] in
            coordinator?.onSubmit()
        }
        field.onTextChange = { [weak coordinator = context.coordinator] newValue in
            coordinator?.text.wrappedValue = newValue
        }
        field.onEditingBegan = { [weak coordinator = context.coordinator] in
            coordinator?.activeField.wrappedValue = .path
        }
        field.onEditingEnded = { [weak coordinator = context.coordinator] in
            coordinator?.handleEditingEnded()
        }
        context.coordinator.field = field
        return field
    }
    
    func updateNSView(_ nsView: PathBarTextField, context: Context) {
        BarTextFieldFocusRegistry.register(nsView, for: .path)
        context.coordinator.text = $text
        context.coordinator.activeField = $activeField
        context.coordinator.onSubmit = onSubmit
        context.coordinator.retainHighlight = retainHighlight
        
        let wasVisible = context.coordinator.wasVisible
        context.coordinator.wasVisible = isVisible
        
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        nsView.alphaValue = isVisible ? 1 : 0
        nsView.isEnabled = true
        
        guard isVisible else { return }
        guard let window = nsView.window else { return }
        
        let shouldSelectAll = BarTextFieldFocusRegistry.hasPendingSelectAll(.path, in: window)
            || (!wasVisible && isVisible)
        guard shouldSelectAll else { return }
        
        nsView.prepareSelectAllOnFocus()
        nsView.selectAllText()
        BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
        DispatchQueue.main.async {
            nsView.prepareSelectAllOnFocus()
            nsView.window?.makeFirstResponder(nsView)
            nsView.selectAllText()
            if let window = nsView.window {
                BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
            }
        }
    }
    
    final class Coordinator {
        var text: Binding<String>
        var activeField: Binding<BarTextFieldID?>
        var onSubmit: () -> Void = {}
        var retainHighlight = false
        var wasVisible = false
        weak var field: PathBarTextField?
        
        init(text: Binding<String>, activeField: Binding<BarTextFieldID?>) {
            self.text = text
            self.activeField = activeField
        }
        
        func handleEditingEnded() {
            guard !retainHighlight else { return }
            guard activeField.wrappedValue == .path else { return }
            if let window = field?.window {
                activeField.wrappedValue = BarTextFieldFocusRegistry.currentEditingField(in: window)
            } else {
                activeField.wrappedValue = nil
            }
        }
    }
}

private enum PathBarMode {
    case breadcrumb
    case text
}

private struct PathSegment: Identifiable, Equatable {
    let id: Int
    let name: String
    let path: String
}

private enum PathSegmentBuilder {
    static func showsLeadingRootSlash(for path: String) -> Bool {
        guard !TrashLoader.isTrashPath(path) else { return false }
        return (path as NSString).standardizingPath.hasPrefix("/")
    }
    
    static func segments(for path: String) -> [PathSegment] {
        if TrashLoader.isTrashPath(path) {
            return [PathSegment(id: 0, name: TrashLoader.displayName, path: path)]
        }
        
        let standardized = (path as NSString).standardizingPath
        if standardized == "/" {
            return []
        }
        
        let components = standardized.split(separator: "/").map(String.init)
        guard !components.isEmpty else {
            return [PathSegment(id: 0, name: standardized, path: standardized)]
        }
        
        var segments: [PathSegment] = []
        var built = ""
        
        for component in components {
            built = built.isEmpty
                ? "/\(component)"
                : (built as NSString).appendingPathComponent(component)
            segments.append(
                PathSegment(id: segments.count, name: component, path: built)
            )
        }
        
        return segments
    }
}

private struct PathSubdirectory: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
}

private enum PathSubdirectoryCache {
    private struct Entry {
        let subdirectories: [PathSubdirectory]
        let timestamp: Date
    }
    
    private static var storage: [String: Entry] = [:]
    private static let lock = NSLock()
    private static let ttl: TimeInterval = 60
    
    static func invalidate() {
        lock.lock()
        storage.removeAll()
        lock.unlock()
    }
    
    static func preloadBreadcrumbPaths(_ path: String, showHiddenFiles: Bool) {
        var parentPaths = PathSegmentBuilder.segments(for: path).dropLast().map(\.path)
        if PathSegmentBuilder.showsLeadingRootSlash(for: path), path != "/" {
            if parentPaths.first != "/" {
                parentPaths.insert("/", at: 0)
            }
        }
        guard !parentPaths.isEmpty else { return }
        let pathsToPreload = parentPaths

        Task.detached(priority: .utility) {
            for parentPath in pathsToPreload {
                _ = load(parentPath: parentPath, showHiddenFiles: showHiddenFiles)
            }
        }
    }
    
    static func load(
        parentPath: String,
        showHiddenFiles: Bool
    ) -> [PathSubdirectory] {
        let key = cacheKey(parentPath: parentPath, showHiddenFiles: showHiddenFiles)
        
        lock.lock()
        if let entry = storage[key], Date().timeIntervalSince(entry.timestamp) < ttl {
            let cached = entry.subdirectories
            lock.unlock()
            return cached
        }
        lock.unlock()
        
        let subdirectories = enumerateSubdirectories(
            parentPath: parentPath,
            showHiddenFiles: showHiddenFiles
        )
        
        lock.lock()
        storage[key] = Entry(subdirectories: subdirectories, timestamp: Date())
        lock.unlock()
        return subdirectories
    }
    
    private static func cacheKey(parentPath: String, showHiddenFiles: Bool) -> String {
        "\(parentPath)|\(showHiddenFiles)"
    }
    
    private static func enumerateSubdirectories(
        parentPath: String,
        showHiddenFiles: Bool
    ) -> [PathSubdirectory] {
        let parentURL = URL(fileURLWithPath: parentPath, isDirectory: true)
        let propertyKeys: [URLResourceKey] = [.isDirectoryKey]
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]
        
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: parentURL,
            includingPropertiesForKeys: propertyKeys,
            options: options
        ) else {
            return []
        }
        
        var subdirectories: [PathSubdirectory] = []
        subdirectories.reserveCapacity(urls.count)
        for url in urls {
            guard let isDirectory = try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory,
                  isDirectory else { continue }
            let resolvedPath = url.standardizedFileURL.path
            subdirectories.append(
                PathSubdirectory(id: resolvedPath, name: url.lastPathComponent, path: resolvedPath)
            )
        }
        
        return subdirectories.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

private struct PathBarView: View {
    @Binding var path: String
    @Binding var activeField: BarTextFieldID?
    @Binding var isTextMode: Bool
    var hostWindow: NSWindow?
    var showHiddenFiles: Bool
    var onSubmit: () -> Void
    
    @State private var mode: PathBarMode = .breadcrumb
    @State private var editingText = ""
    @State private var committedViaSubmit = false
    @State private var previousActiveField: BarTextFieldID?
    
    private let cornerRadius: CGFloat = 7
    private let fieldHeight: CGFloat = 28
    private let pathBarTrailingClickWidth: CGFloat = 40
    
    private var showsFocusBorder: Bool {
        mode == .text || activeField == .path
    }
    
    private var borderColor: Color {
        showsFocusBorder ? Color.accentColor : Color(nsColor: .separatorColor)
    }
    
    private var displayPath: String {
        path
    }

    private var pendingNavigablePath: String? {
        guard mode == .text else { return nil }
        let raw = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }

        let expanded = (raw as NSString).expandingTildeInPath
        let standardized = (expanded as NSString).standardizingPath
        let current = (path as NSString).standardizingPath
        guard standardized != current else { return nil }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized, isDirectory: &isDir),
              isDir.boolValue else {
            return nil
        }
        return standardized
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            PathBarTextFieldRepresentable(
                text: $editingText,
                activeField: $activeField,
                isVisible: mode == .text,
                retainHighlight: mode == .text,
                onSubmit: commitPath
            )
            .padding(.trailing, pendingNavigablePath == nil ? 0 : 22)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            
            if mode == .breadcrumb {
                PathBreadcrumbView(
                    path: path,
                    showHiddenFiles: showHiddenFiles,
                    onNavigate: { path = $0 },
                    onRequestEdit: enterTextMode
                )
            }
        }
        .padding(.horizontal, 8)
        .frame(height: fieldHeight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .allowsHitTesting(false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .trailing) {
            if mode == .text {
                PathBarBlankClickArea(onClick: handlePathBarTrailingClick)
                    .frame(width: pathBarTrailingClickWidth, height: fieldHeight)
                    .help("点击全选路径")
            }
        }
        .overlay(alignment: .trailing) {
            if let targetPath = pendingNavigablePath {
                PathBarNavigateButton(targetPath: targetPath) { target in
                    navigateToPendingPath(target)
                }
                .frame(width: 24, height: fieldHeight)
                .padding(.trailing, 2)
            }
        }
        .background(PathBarRootRegistrar())
        .onAppear {
            editingText = displayPath
            previousActiveField = activeField
            isTextMode = mode == .text
            PathSubdirectoryCache.preloadBreadcrumbPaths(path, showHiddenFiles: showHiddenFiles)
        }
        .onChange(of: path) { _ in
            if mode == .breadcrumb || activeField != .path {
                editingText = displayPath
            }
            PathSubdirectoryCache.preloadBreadcrumbPaths(path, showHiddenFiles: showHiddenFiles)
        }
        .onChange(of: showHiddenFiles) { _ in
            PathSubdirectoryCache.invalidate()
            PathSubdirectoryCache.preloadBreadcrumbPaths(path, showHiddenFiles: showHiddenFiles)
        }
        .onChange(of: mode) { newMode in
            isTextMode = newMode == .text
            guard newMode == .text else { return }
            activeField = .path
            requestPathFieldFocus()
        }
        .onChange(of: isTextMode) { active in
            guard !active, mode == .text else { return }
            if let window = resolvedHostWindow {
                BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
            }
            editingText = displayPath
            committedViaSubmit = false
            mode = .breadcrumb
            if let window = resolvedHostWindow {
                BarTextFieldFocusRegistry.endEditing(.path, in: window)
            }
            if activeField == .path {
                if let window = resolvedHostWindow {
                    activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
                } else {
                    activeField = nil
                }
            }
        }
        .onChange(of: activeField) { newValue in
            let oldValue = previousActiveField
            previousActiveField = newValue
            
            if newValue == .path {
                if mode != .text {
                    editingText = displayPath
                    mode = .text
                }
                return
            }
            
            if oldValue == .path, mode == .text, newValue != .path {
                if !committedViaSubmit {
                    editingText = displayPath
                }
                committedViaSubmit = false
                mode = .breadcrumb
                isTextMode = false
                if let window = resolvedHostWindow {
                    BarTextFieldFocusRegistry.endEditing(.path, in: window)
                }
            }
        }
    }
    
    private var resolvedHostWindow: NSWindow? {
        hostWindow ?? NSApp.keyWindow
    }
    
    private func requestPathFieldFocus() {
        guard let window = resolvedHostWindow else { return }
        BarTextFieldFocusRegistry.focusAndSelectAll(.path, in: window)
        activeField = .path
    }
    
    private func enterTextMode() {
        guard let window = resolvedHostWindow else { return }
        BarTextFieldFocusRegistry.requestSelectAll(.path, in: window)
        editingText = displayPath
        activeField = .path
        isTextMode = true
        if mode == .text {
            BarTextFieldFocusRegistry.focusAndSelectAll(.path, in: window)
        } else {
            mode = .text
        }
    }
    
    private func handlePathBarTrailingClick() {
        guard let window = resolvedHostWindow else { return }
        if mode == .text {
            BarTextFieldFocusRegistry.focusAndSelectAll(.path, in: window)
        } else {
            enterTextMode()
        }
    }
    
    private func commitPath() {
        committedViaSubmit = true
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
        }
        let newValue = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newValue.isEmpty {
            if newValue == TrashLoader.displayName {
                path = TrashLoader.userTrashPath
            } else {
                path = newValue
            }
        }
        onSubmit()
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.endEditing(.path, in: window)
            activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
        } else {
            activeField = nil
        }
        mode = .breadcrumb
    }

    private func navigateToPendingPath(_ targetPath: String) {
        committedViaSubmit = true
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.clearPendingSelectAll(in: window)
        }
        path = targetPath
        editingText = targetPath
        isTextMode = false
        if let window = resolvedHostWindow {
            BarTextFieldFocusRegistry.endEditing(.path, in: window)
            activeField = BarTextFieldFocusRegistry.currentEditingField(in: window)
        } else {
            activeField = nil
        }
        mode = .breadcrumb
    }
}

private struct PathBarRootRegistrar: NSViewRepresentable {
    func makeNSView(context: Context) -> RegistrarView {
        RegistrarView()
    }
    
    func updateNSView(_ nsView: RegistrarView, context: Context) {
        nsView.registerIfNeeded()
    }
    
    final class RegistrarView: NSView {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerIfNeeded()
        }
        
        override func layout() {
            super.layout()
            registerIfNeeded()
        }
        
        fileprivate func registerIfNeeded() {
            guard bounds.width > 0, bounds.height >= 24, bounds.height <= 52 else { return }
            BarTextFieldFocusRegistry.registerPathBarRoot(self)
        }
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }
    }
}

private struct PathBarNavigateButton: NSViewRepresentable {
    let targetPath: String
    let onNavigate: (String) -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onNavigate: onNavigate)
    }
    
    func makeNSView(context: Context) -> NavigateButton {
        let button = NavigateButton(
            image: NSImage(systemSymbolName: "arrow.right.circle.fill", accessibilityDescription: "进入新路径") ?? NSImage(),
            target: context.coordinator,
            action: #selector(Coordinator.navigate(_:))
        )
        button.isBordered = false
        button.bezelStyle = .inline
        button.imagePosition = .imageOnly
        button.contentTintColor = .controlAccentColor
        button.toolTip = "进入新路径"
        button.setButtonType(.momentaryChange)
        context.coordinator.targetPath = targetPath
        return button
    }
    
    func updateNSView(_ nsView: NavigateButton, context: Context) {
        context.coordinator.targetPath = targetPath
        context.coordinator.onNavigate = onNavigate
        nsView.registerWithFocusRegistry()
    }
    
    final class NavigateButton: NSButton {
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerWithFocusRegistry()
        }
        
        override func layout() {
            super.layout()
            registerWithFocusRegistry()
        }
        
        fileprivate func registerWithFocusRegistry() {
            BarTextFieldFocusRegistry.registerPathNavigateButton(self)
        }
    }
    
    final class Coordinator: NSObject {
        var targetPath: String
        var onNavigate: (String) -> Void
        
        init(targetPath: String = "", onNavigate: @escaping (String) -> Void) {
            self.targetPath = targetPath
            self.onNavigate = onNavigate
        }
        
        @objc func navigate(_ sender: NSButton) {
            onNavigate(targetPath)
        }
    }
}

private struct PathBreadcrumbMetrics {
    let contentWidth: CGFloat
    let isOverflowing: Bool
    let trailingClickWidth: CGFloat
    
    static func compute(
        segments: [PathSegment],
        availableWidth: CGFloat,
        clickGap: CGFloat,
        clickReserve: CGFloat,
        showsLeadingRootSlash: Bool
    ) -> PathBreadcrumbMetrics {
        let contentWidth = PathBreadcrumbLayout.estimatedBreadcrumbWidth(
            for: segments,
            showsLeadingRootSlash: showsLeadingRootSlash
        )
        let isOverflowing = contentWidth + clickGap > availableWidth
        let trailingClickWidth: CGFloat
        if isOverflowing {
            trailingClickWidth = clickReserve
        } else {
            trailingClickWidth = max(clickReserve, availableWidth - contentWidth - clickGap)
        }
        return PathBreadcrumbMetrics(
            contentWidth: contentWidth,
            isOverflowing: isOverflowing,
            trailingClickWidth: trailingClickWidth
        )
    }
}

private struct PathBarBlankClickArea: NSViewRepresentable {
    let onClick: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onClick: onClick)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = ClickView()
        view.coordinator = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onClick = onClick
        (nsView as? ClickView)?.coordinator = context.coordinator
    }
    
    final class Coordinator {
        var onClick: () -> Void
        
        init(onClick: @escaping () -> Void) {
            self.onClick = onClick
        }
    }
    
    final class ClickView: NSView {
        weak var coordinator: Coordinator?
        
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            registerIfNeeded()
        }
        
        override func layout() {
            super.layout()
            registerIfNeeded()
        }
        
        private func registerIfNeeded() {
            guard bounds.width > 0, bounds.height > 0 else { return }
            BarTextFieldFocusRegistry.registerPathBarBlankClickArea(self)
        }
        
        override func mouseDown(with event: NSEvent) {
            if let window {
                BarTextFieldFocusRegistry.requestSelectAll(.path, in: window)
            }
            coordinator?.onClick()
        }
        
        override var acceptsFirstResponder: Bool { false }
    }
}

private struct PathBreadcrumbView: View {
    let path: String
    let showHiddenFiles: Bool
    let onNavigate: (String) -> Void
    let onRequestEdit: () -> Void
    
    @State private var hoveredSegmentID: Int?
    
    private let clickGap: CGFloat = 8
    private let clickReserve: CGFloat = 40
    private let minTailCount = 2
    private let fieldHeight: CGFloat = 28
    
    private var segments: [PathSegment] {
        PathSegmentBuilder.segments(for: path)
    }
    
    private var showsLeadingRootSlash: Bool {
        PathSegmentBuilder.showsLeadingRootSlash(for: path)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let metrics = PathBreadcrumbMetrics.compute(
                segments: segments,
                availableWidth: geometry.size.width,
                clickGap: clickGap,
                clickReserve: clickReserve,
                showsLeadingRootSlash: showsLeadingRootSlash
            )
            let layout = PathBreadcrumbLayout.compute(
                segments: segments,
                availableWidth: geometry.size.width,
                reservedTrailingWidth: metrics.isOverflowing ? clickReserve : 0,
                minTailCount: minTailCount,
                showsLeadingRootSlash: showsLeadingRootSlash
            )
            
            ZStack(alignment: .leading) {
                PathBarBlankClickArea(onClick: onRequestEdit)
                    .frame(width: metrics.trailingClickWidth, height: fieldHeight)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .help("点击编辑完整路径")
                
                ScrollViewReader { scrollProxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .center, spacing: 0) {
                            if showsLeadingRootSlash {
                                PathRootSlashButton(
                                    onNavigate: { onNavigate("/") }
                                )
                            }
                            
                            if layout.showsLeadingEllipsis {
                                PathBreadcrumbEllipsisMenu(
                                    hiddenSegments: layout.hiddenSegments,
                                    onNavigate: onNavigate
                                )
                            }
                            
                            ForEach(layout.visibleSegments) { segment in
                                let isLast = segment.id == segments.last?.id
                                
                                PathSegmentButton(
                                    segment: segment,
                                    isHighlighted: isSegmentHighlighted(segment),
                                    onNavigate: onNavigate
                                )
                                .id(segment.id)
                                .onHover { hovering in
                                    if hovering {
                                        hoveredSegmentID = segment.id
                                    }
                                }
                                
                                if !isLast {
                                    PathSeparatorMenu(
                                        parentPath: segment.path,
                                        showHiddenFiles: showHiddenFiles,
                                        onNavigate: onNavigate
                                    )
                                }
                            }
                        }
                        .frame(height: fieldHeight)
                    }
                    .frame(
                        width: max(0, geometry.size.width - metrics.trailingClickWidth),
                        height: fieldHeight,
                        alignment: .leading
                    )
                    .onChange(of: path) { _ in
                        if let lastID = segments.last?.id {
                            scrollProxy.scrollTo(lastID, anchor: .trailing)
                        }
                    }
                    .onAppear {
                        if let lastID = segments.last?.id {
                            scrollProxy.scrollTo(lastID, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(height: fieldHeight)
        .onHover { hovering in
            if !hovering {
                hoveredSegmentID = nil
            }
        }
    }
    
    private func isSegmentHighlighted(_ segment: PathSegment) -> Bool {
        guard let hoveredSegmentID else { return false }
        return segment.id <= hoveredSegmentID
    }
}

private struct PathBreadcrumbLayout {
    let showsLeadingEllipsis: Bool
    let hiddenSegments: [PathSegment]
    let visibleSegments: [PathSegment]
    
    static func compute(
        segments: [PathSegment],
        availableWidth: CGFloat,
        reservedTrailingWidth: CGFloat,
        minTailCount: Int,
        showsLeadingRootSlash: Bool
    ) -> PathBreadcrumbLayout {
        guard !segments.isEmpty || showsLeadingRootSlash else {
            return PathBreadcrumbLayout(
                showsLeadingEllipsis: false,
                hiddenSegments: [],
                visibleSegments: []
            )
        }
        
        let rootPrefixWidth = showsLeadingRootSlash ? estimatedRootSlashWidth() : 0
        let usableWidth = max(0, availableWidth - reservedTrailingWidth - rootPrefixWidth)
        let ellipsisWidth: CGFloat = 28
        let segmentWidths = segments.map(estimatedWidth(for:))
        let totalWidth = estimatedBreadcrumbWidth(
            for: segments,
            showsLeadingRootSlash: showsLeadingRootSlash
        )
        
        if totalWidth <= usableWidth + rootPrefixWidth {
            return PathBreadcrumbLayout(
                showsLeadingEllipsis: false,
                hiddenSegments: [],
                visibleSegments: segments
            )
        }
        
        let tailCount = min(minTailCount, segments.count)
        var startIndex = 0
        let maxStart = segments.count - tailCount
        
        while startIndex < maxStart {
            let nextStart = startIndex + 1
            let visibleWidth = segmentWidths[nextStart...].reduce(0, +)
                + separatorWidth * CGFloat(max(0, segmentWidths[nextStart...].count - 1))
                + ellipsisWidth
            if visibleWidth <= usableWidth {
                startIndex = nextStart
            } else {
                break
            }
        }
        
        if startIndex == 0, segments.count > tailCount {
            startIndex = max(0, segments.count - tailCount)
            while startIndex > 0 {
                let visibleWidth = segmentWidths[startIndex...].reduce(0, +)
                    + separatorWidth * CGFloat(max(0, segmentWidths[startIndex...].count - 1))
                    + ellipsisWidth
                if visibleWidth <= usableWidth { break }
                startIndex -= 1
            }
            let fallbackWidth = segmentWidths[startIndex...].reduce(0, +)
                + separatorWidth * CGFloat(max(0, segmentWidths[startIndex...].count - 1))
                + ellipsisWidth
            if fallbackWidth > usableWidth {
                startIndex = max(0, segments.count - 1)
            }
        }
        
        let hidden = startIndex > 0 ? Array(segments.prefix(startIndex)) : []
        let visible = Array(segments.suffix(from: startIndex))
        return PathBreadcrumbLayout(
            showsLeadingEllipsis: !hidden.isEmpty,
            hiddenSegments: hidden,
            visibleSegments: visible
        )
    }
    
    static let separatorWidth: CGFloat = 14
    
    static func estimatedBreadcrumbWidth(
        for segments: [PathSegment],
        showsLeadingRootSlash: Bool
    ) -> CGFloat {
        var width: CGFloat = 0
        if showsLeadingRootSlash {
            width += estimatedRootSlashWidth()
        }
        guard !segments.isEmpty else { return width }
        let segmentWidths = segments.map(estimatedWidth(for:))
        let separators = separatorWidth * CGFloat(max(0, segments.count - 1))
        return width + segmentWidths.reduce(0, +) + separators
    }
    
    private static func estimatedRootSlashWidth() -> CGFloat {
        separatorWidth
    }
    
    private static func estimatedWidth(for segment: PathSegment) -> CGFloat {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        let textWidth = (segment.name as NSString).size(withAttributes: [.font: font]).width
        return textWidth + 12
    }
}

private struct PathRootSlashButton: View {
    let onNavigate: () -> Void
    
    var body: some View {
        Text("/")
            .font(.system(size: NSFont.systemFontSize))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 2)
            .frame(width: 14, height: 28)
            .contentShape(Rectangle())
            .onTapGesture(perform: onNavigate)
            .help("/")
    }
}

private struct PathSegmentButton: View {
    let segment: PathSegment
    let isHighlighted: Bool
    let onNavigate: (String) -> Void
    
    var body: some View {
        Button {
            onNavigate(segment.path)
        } label: {
            Text(segment.name)
                .font(.system(size: NSFont.systemFontSize))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
                .background {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(isHighlighted ? Color.accentColor.opacity(0.18) : Color.clear)
                }
        }
        .buttonStyle(.plain)
        .frame(height: 28)
        .help(segment.path)
    }
}

private struct PathSeparatorMenu: View {
    let parentPath: String
    let showHiddenFiles: Bool
    let onNavigate: (String) -> Void
    
    var body: some View {
        Menu {
            PathSeparatorMenuItems(
                parentPath: parentPath,
                showHiddenFiles: showHiddenFiles,
                onNavigate: onNavigate
            )
        } label: {
            Text("/")
                .font(.system(size: NSFont.systemFontSize))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 2)
                .frame(width: 14, height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("显示子目录")
    }
}

private struct PathSeparatorMenuItems: View {
    let parentPath: String
    let showHiddenFiles: Bool
    let onNavigate: (String) -> Void
    
    private var subdirectories: [PathSubdirectory] {
        PathSubdirectoryCache.load(
            parentPath: parentPath,
            showHiddenFiles: showHiddenFiles
        )
    }
    
    var body: some View {
        if subdirectories.isEmpty {
            Text("无子文件夹")
                .disabled(true)
        } else {
            ForEach(subdirectories) { subdirectory in
                Button(subdirectory.name) {
                    onNavigate(subdirectory.path)
                }
            }
        }
    }
}

private struct PathBreadcrumbEllipsisMenu: View {
    let hiddenSegments: [PathSegment]
    let onNavigate: (String) -> Void
    
    var body: some View {
        Menu {
            ForEach(hiddenSegments) { segment in
                Button(segment.name) {
                    onNavigate(segment.path)
                }
            }
        } label: {
            Text("…")
                .font(.system(size: NSFont.systemFontSize, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .frame(height: 28)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("显示上级路径")
    }
}

struct ContentView: View {
    private let initialPath: String?

    @Environment(\.openWindow) private var openWindow
    @StateObject private var layout = ExplorerWindowLayoutState()
    @AppStorage(AppSettings.blankDoubleClickActionKey)
    private var blankDoubleClickActionRaw = BlankDoubleClickAction.navigateToParent.rawValue
    @State private var path: String
    @State private var items: [FileItem] = []
    @State private var selection: Set<FileItem.ID> = []
    @State private var sortOrder: SortOrder = .nameAscending
    @ObservedObject private var fileListPreferences = FileListPreferencesStore.shared
    private let directorySizeOverlay = DirectorySizeOverlay.shared
    private let directoryItemCountOverlay = DirectoryItemCountOverlay.shared
    @State private var isSyncingSortFromPreferences = false
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var quickSearchText = ""
    @State private var isQuickSearchVisible = false
    @State private var fileListFocusToken: UInt = 0
    @State private var showHiddenFiles = false
    @State private var loadGeneration: UInt = 0
    @State private var navigationBackStack: [String] = []
    @State private var isApplyingHistoryNavigation = false
    @State private var lastRecordedPath: String?
    @AppStorage(AppSettings.autoCalculateDirectorySizesKey) private var autoCalculateDirectorySizes = true
    @State private var livePreviewPanelWidth: CGFloat = 320
    @State private var activeBarField: BarTextFieldID?
    @State private var previewHostWindowID = UUID()
    @State private var hostWindow: NSWindow?
    @State private var isFileListRenaming = false
    @State private var isPathBarTextMode = false
    @State private var liveLeftPanelDragWidth: CGFloat?
    @StateObject private var externalFolderOpenCenter = ExternalFolderOpenCenter.shared
    @State private var pendingExternalSelectionPath: String?
    
    init(initialPath: String? = nil) {
        self.initialPath = initialPath
        _path = State(initialValue: initialPath ?? FileManager.default.homeDirectoryForCurrentUser.path)
    }
    
    private let leftPanelConstants = LeftPanelLayoutConstants()
    
    private var isTextFieldEditing: Bool {
        activeBarField != nil || isFileListRenaming
    }
    
    private var fileListViewMode: FileListViewMode {
        layout.fileListViewMode
    }

    private var thumbnailCellSize: CGFloat {
        layout.thumbnailCellSizeValue
    }

    private var currentDirectoryTitle: String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "MeoFind" }
        let url = URL(fileURLWithPath: trimmed)
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }
    
    private var fileListTableItems: [FileItem] {
        let showParent = FileItem.canNavigateUp(from: path) && searchText.isEmpty
        if showParent {
            return [FileItem.parentDirectoryEntry()] + filteredItems
        }
        return filteredItems
    }
    
    private let minPreviewPanelWidth: CGFloat = 200
    private let minMainPanelWidth: CGFloat = 360
    
    private var leftPanelMode: LeftPanelMode { layout.leftPanelMode }
    
    private var leftPanelLastVisibleMode: LeftPanelVisibleMode { layout.leftPanelLastVisibleMode }
    
    private var leftPanelSidebarWidth: CGFloat { layout.leftPanelSidebarWidthValue }
    
    private var leftPanelVisibleWidth: CGFloat {
        layout.leftPanelVisibleWidth
    }
    
    /// 拖拽过程中面板宽度跟随鼠标；松手后回退到 `leftPanelVisibleWidth`。
    private var leftPanelDisplayWidth: CGFloat {
        if let live = liveLeftPanelDragWidth {
            switch leftPanelMode {
            case .sidebar:
                return leftPanelConstants.clampedSidebarWidth(live)
            case .rail:
                return leftPanelConstants.railDisplayWidth(liveDragWidth: live)
            case .hidden:
                return 0
            }
        }
        return leftPanelVisibleWidth
    }
    
    private func handleLeftPanelDrag(delta: CGFloat) {
        let baseWidth = liveLeftPanelDragWidth ?? leftPanelDisplayWidth
        let proposed = baseWidth + delta
        liveLeftPanelDragWidth = proposed
        layout.applyLeftPanelDrag(proposedWidth: proposed, baseWidth: baseWidth)
        if layout.leftPanelMode == .hidden {
            // 拖入隐藏后 divider 会被移出视图，mouseUp 可能到不了；清掉 live 宽度避免再次显示时用脏值。
            liveLeftPanelDragWidth = nil
        }
    }
    
    private func handleLeftPanelDragEnded() {
        liveLeftPanelDragWidth = nil
    }
    
    private func toggleLeftPanelVisibility() {
        liveLeftPanelDragWidth = nil
        layout.toggleLeftPanelVisibility()
    }
    
    private func restoredLaunchPath() -> String {
        ExplorerWindowLayoutState.restoredLastOpenedPath()
    }
    
    var body: some View {
        GeometryReader { outer in
            let outputMaxHeight = max(400, outer.size.height * 0.85)
            VStack(spacing: 0) {
                GeometryReader { geometry in
                let maxPreviewWidth = max(
                    minPreviewPanelWidth,
                    geometry.size.width - minMainPanelWidth
                )
                
                HStack(spacing: 0) {
                    if leftPanelMode != .hidden {
                        Group {
                            Group {
                                switch leftPanelMode {
                                case .sidebar:
                                    SidebarView(
                                        path: $path,
                                        onItemsChanged: {
                                            selection.removeAll()
                                            loadItems()
                                        },
                                        onReload: {
                                            selection.removeAll()
                                            loadItems()
                                        }
                                    )
                                case .rail:
                                    SidebarRailView(
                                        path: $path,
                                        onItemsChanged: {
                                            selection.removeAll()
                                            loadItems()
                                        },
                                        onReload: {
                                            selection.removeAll()
                                            loadItems()
                                        }
                                    )
                                case .hidden:
                                    EmptyView()
                                }
                            }
                            .frame(width: leftPanelDisplayWidth)
                            .frame(maxHeight: .infinity)
                            
                            LeadingResizeDivider(
                                onResize: handleLeftPanelDrag(delta:),
                                onDragEnded: handleLeftPanelDragEnded
                            )
                            .frame(width: 6)
                            .frame(maxHeight: .infinity)
                        }
                        .animation(nil, value: liveLeftPanelDragWidth)
                    }
                    
                    HStack(spacing: 0) {
                        explorerBrowserColumn
                        
                        if layout.showPreview || layout.showSnippets {
                            explorerRightPanelColumn(maxPreviewWidth: maxPreviewWidth)
                        }
                    }
                    .animation(nil, value: livePreviewPanelWidth)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        livePreviewPanelWidth = clampPreviewWidth(
                            CGFloat(layout.previewPanelWidth),
                            maxWidth: maxPreviewWidth
                        )
                    }
                    .onChange(of: geometry.size.width) { newWidth in
                        let maxPreview = max(minPreviewPanelWidth, newWidth - minMainPanelWidth)
                        let clamped = clampPreviewWidth(livePreviewPanelWidth, maxWidth: maxPreview)
                        if clamped != livePreviewPanelWidth {
                            livePreviewPanelWidth = clamped
                            layout.previewPanelWidth = Double(clamped)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            OutputPanelView(layout: layout, maxPanelHeight: outputMaxHeight)
            }
            .frame(width: outer.size.width, height: outer.size.height)
        }
        .background(WindowKeyLayoutTracker(layout: layout).frame(width: 0, height: 0).accessibilityHidden(true))
        .background(HostWindowReader(window: $hostWindow).frame(width: 0, height: 0).accessibilityHidden(true))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            guard let closingWindow = notification.object as? NSWindow,
                  closingWindow == hostWindow else { return }
            PreviewDetachCoordinator.shared.onHostWindowWillClose(hostWindowID: previewHostWindowID)
        }
        .settingsWindowOpenBridge()
        .background(
            BarFieldOutsideClickHandler(
                activeField: $activeBarField,
                isPathBarTextMode: $isPathBarTextMode,
                tableItems: fileListTableItems
            )
        )
        .onAppear {
            externalFolderOpenCenter.setOpenFolderWindowHandler { path in
                openWindow(id: ExplorerWindowScene.folder, value: path)
            }

            if let mapped = fileListPreferences.sort.explorerSortOrder {
                sortOrder = mapped
            }
            
            // 初始化时做一次自愈：持久化宽度可能越界。
            layout.healLeftPanelSidebarWidth()
            if let initialPath {
                path = initialPath
            } else if let launchRequest = externalFolderOpenCenter.consumePendingRequest() {
                pendingExternalSelectionPath = launchRequest.selectionPath
                path = launchRequest.directoryPath
            } else {
                path = restoredLaunchPath()
            }
            lastRecordedPath = path
            layout.recordLastOpenedPath(path)
            loadItems()
        }
        .onReceive(externalFolderOpenCenter.$targetRequest.compactMap { $0 }) { request in
            applyExternalNavigationTarget(ExternalNavigationTarget(request: request))
        }
        .onChange(of: path) { newPath in
            if let oldPath = lastRecordedPath, oldPath != newPath, !isApplyingHistoryNavigation {
                navigationBackStack.append(oldPath)
            }
            lastRecordedPath = newPath
            layout.recordLastOpenedPath(newPath)
            loadItems()
        }
        .onChange(of: autoCalculateDirectorySizes) { enabled in
            handleAutoCalculateDirectorySizesChanged(enabled)
        }
        .onChange(of: sortOrder) { newOrder in
            guard !isSyncingSortFromPreferences else { return }
            fileListPreferences.updateSort(FileListSortState(sortOrder: newOrder))
        }
        .onChange(of: fileListPreferences.preferences.sort) { newSort in
            guard let mapped = newSort.explorerSortOrder else { return }
            guard mapped != sortOrder else { return }
            isSyncingSortFromPreferences = true
            sortOrder = mapped
            isSyncingSortFromPreferences = false
        }
    }
    
    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    @ViewBuilder
    private var explorerBrowserColumn: some View {
        VStack(spacing: 0) {
            PathBarView(
                path: $path,
                activeField: $activeBarField,
                isTextMode: $isPathBarTextMode,
                hostWindow: hostWindow,
                showHiddenFiles: showHiddenFiles,
                onSubmit: { loadItems() }
            )
            .frame(height: PanelTopBarMetrics.contentHeight)
            .padding(.horizontal)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
            
            Divider()
            
            explorerFileListSection
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .focusedValue(\.textFieldEditing, isTextFieldEditing)
        .focusedValue(
            \.windowLayoutCommands,
            WindowLayoutCommands(
                showPreview: layout.showPreview,
                showSnippets: layout.showSnippets,
                isOutputPanelVisible: layout.isOutputPanelVisible,
                toggleLeftPanel: { layout.toggleLeftPanelVisibility() },
                toggleRightPanel: {
                    if layout.showPreview || layout.showSnippets {
                        layout.showPreview = false
                        layout.showSnippets = false
                    } else {
                        layout.showPreview = true
                        layout.showSnippets = true
                    }
                },
                togglePreview: { layout.showPreview.toggle() },
                toggleSnippets: { layout.showSnippets.toggle() },
                toggleOutputPanel: { layout.isOutputPanelVisible.toggle() }
            )
        )
        .background(TextEditingKeyMonitor(isBarFieldEditing: isTextFieldEditing))
        .background(BarTextFieldFocusSync(activeField: $activeBarField))
        .navigationTitle(currentDirectoryTitle)
        .modifier(InlineToolbarTitleModifier())
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: toggleLeftPanelVisibility) {
                    Image(systemName: leftPanelMode == .hidden ? "sidebar.left" : "sidebar.left")
                }
                .buttonStyle(.borderless)
                .help(leftPanelMode == .hidden ? "显示左侧面板" : "隐藏左侧面板")
            }
            .hideSharedBackgroundIfAvailable()
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: createNewFolder) {
                    LucideIcon.folderPlus
                }
                .buttonStyle(.borderless)
                .help("新建文件夹")
            }
            .hideSharedBackgroundIfAvailable()

            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    showHiddenFiles.toggle()
                    loadItems()
                }) {
                    Image(systemName: showHiddenFiles ? "eye.fill" : "eye")
                }
                .buttonStyle(.borderless)
            }
            .hideSharedBackgroundIfAvailable()
            
            ToolbarItem(placement: .primaryAction) {
                Picker("视图", selection: Binding(
                    get: { layout.fileListViewModeRaw },
                    set: { layout.setFileListViewMode(FileListViewMode(rawValue: $0) ?? .list) }
                )) {
                    ForEach(FileListViewMode.allCases, id: \.rawValue) { mode in
                        Image(systemName: mode.systemImageName)
                            .tag(mode.rawValue)
                            .help(mode == .list ? "列表视图" : "缩略图视图")
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 72)
            }
            .hideSharedBackgroundIfAvailable()
            
            if fileListViewMode == .thumbnail {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { layout.thumbnailCellSizeValue },
                                set: { layout.thumbnailCellSizeValue = FileListThumbnailMetrics.steppedCellSize(from: $0) }
                            ),
                            in: FileListThumbnailMetrics.minCellSize...FileListThumbnailMetrics.maxCellSize,
                            step: FileListThumbnailMetrics.cellSizeStep
                        )
                        .frame(width: 120)
                        Text("\(Int(FileListThumbnailMetrics.steppedCellSize(from: layout.thumbnailCellSizeValue)))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)
                    }
                    .help("缩略图大小")
                }
                .hideSharedBackgroundIfAvailable()
            }
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(SortOrder.allCases) { order in
                        Button {
                            sortOrder = order
                        } label: {
                            if sortOrder == order {
                                Label(order.rawValue, systemImage: "checkmark")
                            } else {
                                Text(order.rawValue)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .menuStyle(.borderlessButton)
            }
            .hideSharedBackgroundIfAvailable()
            
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("自动计算文件夹大小", isOn: $autoCalculateDirectorySizes)
                } label: {
                    Image(systemName: "gearshape")
                }
                .menuStyle(.borderlessButton)
                .help("浏览设置")
            }
            .hideSharedBackgroundIfAvailable()
            
            ToolbarItem(placement: .primaryAction) {
                BarTextField(
                    fieldID: .search,
                    prompt: "Search files",
                    text: $searchText,
                    activeField: $activeBarField,
                    icon: "magnifyingglass",
                    shape: .capsule,
                    showsClearButton: true
                )
                .frame(width: 220)
            }
            .hideSharedBackgroundIfAvailable()
        }
        .onChange(of: activeBarField) { field in
            guard let field, let hostWindow else { return }
            BarTextFieldFocusRegistry.focus(field, in: hostWindow)
        }
        .background {
            Button("Focus Search") {
                activeBarField = .search
            }
            .keyboardShortcut("f", modifiers: .command)
            .labelsHidden()
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
    
    @ViewBuilder
    private func explorerRightPanelColumn(maxPreviewWidth: CGFloat) -> some View {
        HorizontalResizeDivider(
            trailingWidth: $livePreviewPanelWidth,
            minTrailingWidth: minPreviewPanelWidth,
            maxTrailingWidth: maxPreviewWidth,
            onDragEnded: {
                layout.previewPanelWidth = Double(livePreviewPanelWidth)
            }
        )
        .frame(width: 6)
        .frame(maxHeight: .infinity)
        
        RightPanelStackView(
            layout: layout,
            hostWindowID: previewHostWindowID,
            selection: selection,
            items: items,
            cwd: path,
            sortOrder: sortOrder,
            showHiddenFiles: showHiddenFiles,
            autoCalculateDirectorySizes: shouldAutoCalculateDirectorySizes(for: path),
            directorySizeOverlay: directorySizeOverlay,
            directoryItemCountOverlay: directoryItemCountOverlay,
            panelWidth: livePreviewPanelWidth,
            onNavigate: { path = $0 },
            onOpenItem: openItem,
            onOpenTerminalAtPath: { TerminalHelper.open(at: $0) }
        )
        .frame(width: livePreviewPanelWidth)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private var explorerFileListSection: some View {
        FileListView(
            items: filteredItems,
            selection: $selection,
            showPreview: $layout.showPreview,
            searchText: searchText,
            quickSearchText: $quickSearchText,
            isQuickSearchVisible: $isQuickSearchVisible,
            isFileListRenaming: $isFileListRenaming,
            focusToken: fileListFocusToken,
            currentDirectoryPath: path,
            canNavigateToParent: FileItem.canNavigateUp(from: path),
            showHiddenFiles: showHiddenFiles,
            directorySizeOverlay: directorySizeOverlay,
            directoryItemCountOverlay: directoryItemCountOverlay,
            viewMode: fileListViewMode,
            thumbnailCellSize: thumbnailCellSize,
            isLoading: isLoading,
            onThumbnailCellSizeChange: { layout.thumbnailCellSizeValue = $0 },
            onItemOpen: openItem,
            onBlankDoubleClick: handleBlankDoubleClick,
            onItemsChanged: handleFileListItemsChanged,
            onScheduleVisibleDirectorySizes: scheduleVisibleDirectorySizes,
            onScheduleVisibleDirectoryItemCounts: scheduleVisibleDirectoryItemCounts,
            contextActions: fileContextActions,
            blankMenuActions: blankMenuActions,
            canNavigateBack: canNavigateBack,
            onNavigateBack: navigateBack
        )
        .focusedValue(\.fileCommandHandlers, fileCommandHandlers)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private func clampPreviewWidth(_ width: CGFloat, maxWidth: CGFloat) -> CGFloat {
        min(max(width, minPreviewPanelWidth), max(maxWidth, minPreviewPanelWidth))
    }
    
    private func loadItems(invalidatingPaths: [String] = []) {
        loadGeneration += 1
        let currentGeneration = loadGeneration
        isLoading = true
        selection.removeAll()
        
        let currentPath = path
        let shouldShowHiddenFiles = showHiddenFiles
        directorySizeOverlay.beginSession(generation: currentGeneration)
        directoryItemCountOverlay.beginSession(generation: currentGeneration)
        
        Task {
            var didApplyItems = false
            defer {
                Task { @MainActor in
                    guard currentGeneration == loadGeneration, !didApplyItems else { return }
                    isLoading = false
                }
            }
            
            await MainActor.run {
                DirectoryFSEventsMonitor.shared.stop()
            }
            
            if !invalidatingPaths.isEmpty {
                await DirectorySizeService.shared.invalidate(paths: invalidatingPaths)
                await DirectoryItemCountService.shared.invalidate(paths: invalidatingPaths)
            }
            await DirectorySizeService.shared.resetSession(generation: currentGeneration)
            await DirectoryItemCountService.shared.resetSession(generation: currentGeneration)
            
            var loadedItems: [FileItem] = []
            
            if TrashLoader.isTrashPath(currentPath) {
                loadedItems = await TrashLoader.loadItems(showHiddenFiles: shouldShowHiddenFiles)
            } else {
                let url = URL(fileURLWithPath: currentPath)
                let propertyKeys: Set<URLResourceKey> = [
                    .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
                ]
                let options: FileManager.DirectoryEnumerationOptions = shouldShowHiddenFiles
                    ? [.skipsPackageDescendants]
                    : [.skipsHiddenFiles, .skipsPackageDescendants]
                
                do {
                    let urls = try FileManager.default.contentsOfDirectory(
                        at: url,
                        includingPropertiesForKeys: Array(propertyKeys),
                        options: options
                    )
                    
                    for fileURL in urls {
                        try Task.checkCancellation()
                        
                        guard let item = TrashLoader.fileItem(
                            from: fileURL,
                            propertyKeys: propertyKeys
                        ) else { continue }
                        
                        loadedItems.append(item)
                    }
                } catch is CancellationError {
                    return
                } catch {
                    print("Error loading directory: \(error)")
                }
            }
            
            guard !Task.isCancelled, currentGeneration == loadGeneration else { return }
            
            await MainActor.run {
                guard currentGeneration == loadGeneration else { return }
                items = loadedItems
                isLoading = false
                didApplyItems = true
                fileListFocusToken &+= 1
                applyPendingExternalSelectionIfNeeded(
                    loadedItems: loadedItems,
                    for: currentPath
                )
            }
            
            guard !Task.isCancelled, currentGeneration == loadGeneration else { return }
            
            let folderPaths = loadedItems
                .filter(\.isDirectory)
                .map(\.id)
            if shouldAutoCalculateDirectorySizes(for: currentPath) {
                await DirectorySizeService.shared.schedule(
                    paths: folderPaths,
                    showHiddenFiles: shouldShowHiddenFiles,
                    priority: .normal
                )
            }
            await DirectoryItemCountService.shared.schedule(
                paths: folderPaths.filter { !FileListApplicationBundle.isBundle(path: $0) },
                showHiddenFiles: shouldShowHiddenFiles,
                priority: .normal
            )
            
            await MainActor.run {
                guard currentGeneration == loadGeneration else { return }
                updateDirectoryFSEventsMonitoring(
                    directoryPath: currentPath,
                    folderPaths: folderPaths,
                    showHiddenFiles: shouldShowHiddenFiles
                )
            }
        }
    }
    
    private func shouldAutoCalculateDirectorySizes(for directoryPath: String) -> Bool {
        autoCalculateDirectorySizes
            && !TrashLoader.isTrashPath(directoryPath)
            && DirectorySizeVolumeFilter.shouldAutoCalculate(path: directoryPath)
    }
    
    private func updateDirectoryFSEventsMonitoring(
        directoryPath: String,
        folderPaths: [String],
        showHiddenFiles: Bool
    ) {
        guard !TrashLoader.isTrashPath(directoryPath) else {
            DirectoryFSEventsMonitor.shared.stop()
            return
        }
        DirectoryFSEventsMonitor.shared.updateSession(
            directoryPath: directoryPath,
            folderPaths: folderPaths,
            showHiddenFiles: showHiddenFiles,
            autoCalculateDirectorySizes: shouldAutoCalculateDirectorySizes(for: directoryPath),
            onListingRefresh: { loadItems() }
        )
    }
    
    private func scheduleVisibleDirectorySizes(_ visiblePaths: [String]) {
        guard shouldAutoCalculateDirectorySizes(for: path) else { return }
        let shouldShowHiddenFiles = showHiddenFiles
        Task {
            await DirectorySizeService.shared.schedule(
                paths: visiblePaths,
                showHiddenFiles: shouldShowHiddenFiles,
                priority: .visible
            )
        }
    }
    
    private func scheduleVisibleDirectoryItemCounts(_ visiblePaths: [String]) {
        guard fileListViewMode == .thumbnail,
              !TrashLoader.isTrashPath(path) else { return }
        let paths = visiblePaths.filter { !FileListApplicationBundle.isBundle(path: $0) }
        guard !paths.isEmpty else { return }
        let shouldShowHiddenFiles = showHiddenFiles
        Task {
            await DirectoryItemCountService.shared.schedule(
                paths: paths,
                showHiddenFiles: shouldShowHiddenFiles,
                priority: .visible
            )
        }
    }
    
    private func handleFileListItemsChanged(_ invalidatedPaths: [String]) {
        selection.removeAll()
        loadItems(invalidatingPaths: invalidatedPaths)
    }
    
    private func handleAutoCalculateDirectorySizesChanged(_ enabled: Bool) {
        let folderPaths = items.filter(\.isDirectory).map(\.id)
        if enabled {
            rescheduleDirectorySizesIfNeeded()
        } else {
            loadGeneration += 1
            directorySizeOverlay.beginSession(generation: loadGeneration)
            Task {
                await DirectorySizeService.shared.resetSession(generation: loadGeneration)
            }
        }
        updateDirectoryFSEventsMonitoring(
            directoryPath: path,
            folderPaths: folderPaths,
            showHiddenFiles: showHiddenFiles
        )
    }
    
    private func rescheduleDirectorySizesIfNeeded() {
        guard shouldAutoCalculateDirectorySizes(for: path) else { return }
        let folderPaths = items.filter(\.isDirectory).map(\.id)
        let shouldShowHiddenFiles = showHiddenFiles
        Task {
            await DirectorySizeService.shared.schedule(
                paths: folderPaths,
                showHiddenFiles: shouldShowHiddenFiles,
                priority: .normal
            )
        }
    }
    
    private var blankDoubleClickAction: BlankDoubleClickAction {
        BlankDoubleClickAction(rawValue: blankDoubleClickActionRaw) ?? .navigateToParent
    }
    
    private func handleBlankDoubleClick() {
        switch blankDoubleClickAction {
        case .navigateToParent:
            navigateUp()
        case .openTerminal:
            TerminalHelper.open(at: path)
        }
    }
    
    private var canNavigateBack: Bool {
        !navigationBackStack.isEmpty
    }
    
    private func navigateBack() {
        guard let previous = navigationBackStack.popLast() else { return }
        isApplyingHistoryNavigation = true
        path = previous
        isApplyingHistoryNavigation = false
    }
    
    private func navigateUp() {
        if TrashLoader.isTrashPath(path) {
            path = FileManager.default.homeDirectoryForCurrentUser.path
            return
        }
        
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        if parent != path {
            path = parent
        }
    }
    
    private func openItem(_ item: FileItem) {
        if item.isParentDirectoryEntry {
            navigateUp()
            return
        }
        FileOperations.open([item]) { path = $0 }
    }
    
    private var selectedItems: [FileItem] {
        filteredItems.filter { selection.contains($0.id) }
    }
    
    private var fileCommandHandlers: FileCommandHandlers {
        let selected = selectedItems
        let destPath = FileOperations.pasteDestination(
            selectedItems: selected,
            currentDirectoryPath: path
        )
        return FileCommandHandlers(
            copy: { FileOperations.copy(selected) },
            cut: { FileOperations.cut(selected) },
            paste: {
                FileOperations.paste(to: URL(fileURLWithPath: destPath)) {
                    selection.removeAll()
                    loadItems()
                }
            },
            delete: {
                let paths = selected.map(\.id)
                FileOperations.delete(selected) {
                    selection.removeAll()
                    loadItems(invalidatingPaths: paths)
                }
            },
            canCopy: !selected.isEmpty,
            canCut: !selected.isEmpty,
            canPaste: FileOperations.canPaste(to: URL(fileURLWithPath: destPath)),
            canDelete: !selected.isEmpty
        )
    }
    
    private var blankMenuActions: FileListBlankMenuActions {
        let inTrash = TrashLoader.isTrashPath(path)
        let pasteDestination = URL(fileURLWithPath: path, isDirectory: true)
        let canPaste = !inTrash && FileOperations.canPaste(to: pasteDestination)
        
        return FileListBlankMenuActions(
            isEnabled: searchText.isEmpty,
            canGoBack: canNavigateBack,
            goBack: navigateBack,
            canGoUp: FileItem.canNavigateUp(from: path),
            goUp: navigateUp,
            canPaste: canPaste,
            paste: {
                FileOperations.paste(to: pasteDestination) {
                    selection.removeAll()
                    loadItems()
                }
            },
            newFolder: createNewFolder,
            newFile: createNewFile,
            openTerminal: { TerminalHelper.open(at: path) },
            isInTrash: inTrash,
            emptyTrash: {
                FileOperations.emptyTrash {
                    selection.removeAll()
                    loadItems()
                }
            },
            appendToMenu: { menu in
                let selectedItems = FileItem.resolveSelection(ids: selection, from: items)
                SnippetsContextMenuBuilder.appendSnippetsMenu(
                    to: menu,
                    cwd: path,
                    selectedItems: selectedItems,
                    showHiddenFiles: showHiddenFiles
                )
            }
        )
    }
    
    private var fileContextActions: FileContextActions {
        FileContextActions(
            open: { FileOperations.open([$0]) { path = $0 } },
            openWith: FileOperations.openWith,
            openWithApplication: FileOperations.openWithApplication,
            cut: FileOperations.cut,
            copy: FileOperations.copy,
            copyFilename: FileOperations.copyFilename,
            copyPaths: FileOperations.copyPaths,
            delete: { items in
                let paths = items.map(\.id)
                FileOperations.delete(items) {
                    selection.removeAll()
                    loadItems(invalidatingPaths: paths)
                }
            },
            rename: { item in
                FileListTableController.shared?.beginRename(itemID: item.id)
            },
            showInfo: FileOperations.showInfo,
            canPaste: { destPath in
                FileOperations.canPaste(to: URL(fileURLWithPath: destPath))
            },
            paste: { destPath in
                FileOperations.paste(to: URL(fileURLWithPath: destPath)) {
                    selection.removeAll()
                    loadItems()
                }
            },
            isFavorited: { FavoritesStore.shared.contains(path: $0.url.path) },
            addToFavorites: { FavoritesStore.shared.addDirectory(at: $0.url.path) },
            isInTrash: TrashLoader.isTrashPath(path),
            emptyTrash: {
                FileOperations.emptyTrash {
                    selection.removeAll()
                    loadItems()
                }
            },
            putBack: { items in
                FileOperations.putBack(items) {
                    selection.removeAll()
                    loadItems()
                }
            },
            deleteImmediately: { items in
                let paths = items.map(\.id)
                FileOperations.deleteImmediately(items) {
                    selection.removeAll()
                    loadItems(invalidatingPaths: paths)
                }
            },
            openTerminal: { item in
                let directoryPath = item.isDirectory
                    ? item.url.path
                    : item.url.deletingLastPathComponent().path
                TerminalHelper.open(at: directoryPath)
            },
            openInNewWindow: { item in
                let directoryPath: String?
                if item.isParentDirectoryEntry {
                    directoryPath = FileItem.parentDirectoryURL(from: path)?.path
                } else if item.isDirectory, item.url.pathExtension.lowercased() != "app" {
                    directoryPath = item.url.path
                } else {
                    directoryPath = nil
                }
                guard let directoryPath else { return }
                externalFolderOpenCenter.requestOpenInNewWindow(directoryPath: directoryPath)
            }
        )
    }
    
    private func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = "新建文件夹"
        alert.informativeText = "输入新文件夹名称："
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "文件夹名称"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        
        alert.window.initialFirstResponder = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let folderName = textField.stringValue
            
            if !folderName.isEmpty {
                let folderURL = URL(fileURLWithPath: path).appendingPathComponent(folderName)
                
                do {
                    try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
                    loadItems()
                } catch {
                    let errorAlert = NSAlert(error: error)
                    errorAlert.runModal()
                }
            }
        }
    }
    
    private func createNewFile() {
        let alert = NSAlert()
        alert.messageText = "新建文件"
        alert.informativeText = "输入新文件名称："
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "文件名称"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "创建")
        alert.addButton(withTitle: "取消")
        
        alert.window.initialFirstResponder = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let fileName = textField.stringValue
            
            if !fileName.isEmpty {
                let fileURL = URL(fileURLWithPath: path).appendingPathComponent(fileName)
                
                guard FileManager.default.createFile(atPath: fileURL.path, contents: Data()) else {
                    let errorAlert = NSAlert()
                    errorAlert.messageText = "无法创建文件"
                    errorAlert.informativeText = "请检查名称是否合法，或目标位置是否可写。"
                    errorAlert.runModal()
                    return
                }
                loadItems()
            }
        }
    }
}

private struct LeadingResizeDivider: NSViewRepresentable {
    var onResize: (CGFloat) -> Void
    var onDragEnded: (() -> Void)?
    
    func makeNSView(context: Context) -> ResizeDividerNSView {
        ResizeDividerNSView()
    }
    
    func updateNSView(_ nsView: ResizeDividerNSView, context: Context) {
        nsView.onResize = onResize
        nsView.onDragEnded = onDragEnded
    }
}

@MainActor
private enum FavoriteSidebarDrop {
    static func handle(
        urls: [URL],
        to destinationPath: String,
        copy: Bool,
        insertBefore: Int?,
        favoritesStore: FavoritesStore,
        onItemsChanged: @escaping () -> Void
    ) {
        var filesToMove: [URL] = []
        
        if let insertBefore {
            var nextInsertIndex = insertBefore
            for url in urls {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
                if isDirectory.boolValue && !FileListApplicationBundle.isBundle(path: url.path) {
                    let previousCount = favoritesStore.items.count
                    favoritesStore.addDirectory(at: url.path, insertBefore: nextInsertIndex)
                    if favoritesStore.items.count > previousCount {
                        nextInsertIndex += 1
                    }
                } else {
                    filesToMove.append(url)
                }
            }
        } else {
            for url in urls {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { continue }
                filesToMove.append(url)
            }
        }
        
        guard !filesToMove.isEmpty else { return }
        if TrashLoader.isTrashPath(destinationPath) {
            FileOperations.trashItems(filesToMove, completion: onItemsChanged)
            return
        }
        let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
        FileOperations.moveItems(filesToMove, to: destination, copy: copy, completion: onItemsChanged)
    }
}

private struct FavoritesSidebarRows: View {
    @ObservedObject var favoritesStore: FavoritesStore
    @Binding var path: String
    var showsTitle: Bool
    var isSelected: (String) -> Bool
    var onDropURLs: ([URL], String, Bool, Int?) -> Void
    
    var body: some View {
        FavoritesSidebarHost(
            favoritesStore: favoritesStore,
            path: $path,
            showsTitle: showsTitle,
            isSelected: isSelected,
            onDropURLs: onDropURLs
        )
        .id(showsTitle)
        .frame(width: showsTitle ? nil : FavoriteSidebarRailLayout.contentWidth)
        .frame(
            maxWidth: showsTitle ? .infinity : FavoriteSidebarRailLayout.contentWidth,
            alignment: showsTitle ? .leading : .center
        )
        .padding(.leading, showsTitle
            ? -FavoriteSidebarRailLayout.sidebarContentLeadingBleed
            : -FavoriteSidebarRailLayout.railContentLeadingBleed)
        .padding(.trailing, showsTitle
            ? -FavoriteSidebarRailLayout.sidebarContentTrailingBleed
            : -FavoriteSidebarRailLayout.railContentTrailingBleed)
        .fixedSize(horizontal: !showsTitle, vertical: true)
    }
}

struct SidebarView: View {
    @Binding var path: String
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @State private var devices: [SidebarVolume] = []
    var onItemsChanged: () -> Void = {}
    var onReload: () -> Void = {}
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sidebarSection("Favorites") {
                    FavoritesSidebarRows(
                        favoritesStore: favoritesStore,
                        path: $path,
                        showsTitle: true,
                        isSelected: isSelected,
                        onDropURLs: handleFavoriteDrop
                    )
                }
                
                sidebarSection("Devices") {
                    if devices.isEmpty {
                        Text("No devices")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                    } else {
                        ForEach(devices) { device in
                            SidebarRow(
                                title: device.name,
                                icon: device.icon,
                                isSelected: isSelected(device.path),
                                dropDestinationPath: device.path,
                                onDropURLs: handleSidebarDrop,
                                onSelect: { path = device.path },
                                trailingAccessory: {
                                    if device.canEject {
                                        Button {
                                            ejectDevice(device)
                                        } label: {
                                            Image(systemName: "eject.fill")
                                                .font(.caption)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(.secondary)
                                        .help("推出 \(device.name)")
                                    }
                                }
                            )
                        }
                    }
                }
                
                sidebarSection("位置") {
                    SidebarRow(
                        title: "废纸篓",
                        icon: "trash",
                        isSelected: isSelected(trashPath),
                        dropDestinationPath: trashPath,
                        onDropURLs: handleSidebarDrop,
                        onSelect: {
                            if TrashLoader.isTrashPath(path) {
                                onReload()
                            } else {
                                path = trashPath
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
        }
        .onAppear(perform: refreshDevices)
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didMountNotification)) { _ in
            refreshDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            refreshDevices()
        }
    }
    
    @ViewBuilder
    private func sidebarSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            content()
        }
    }
    
    private func refreshDevices() {
        devices = SidebarVolumeLoader.load()
    }
    
    private var trashPath: String {
        TrashLoader.userTrashPath
    }
    
    private func isSelected(_ sidebarPath: String) -> Bool {
        if TrashLoader.isTrashPath(sidebarPath) {
            return TrashLoader.isTrashPath(path)
        }
        return Self.pathsRepresentSameLocation(path, sidebarPath)
    }
    
    private static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = (lhs as NSString).standardizingPath
        let normalizedRHS = (rhs as NSString).standardizingPath
        if normalizedLHS == normalizedRHS { return true }
        
        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }
    
    private func handleFavoriteDrop(_ urls: [URL], to destinationPath: String, copy: Bool, insertBefore: Int?) {
        FavoriteSidebarDrop.handle(
            urls: urls,
            to: destinationPath,
            copy: copy,
            insertBefore: insertBefore,
            favoritesStore: favoritesStore,
            onItemsChanged: onItemsChanged
        )
    }
    
    private func handleSidebarDrop(_ urls: [URL], to destinationPath: String, copy: Bool) {
        if TrashLoader.isTrashPath(destinationPath) {
            FileOperations.trashItems(urls, completion: onItemsChanged)
            return
        }
        let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
        FileOperations.moveItems(urls, to: destination, copy: copy, completion: onItemsChanged)
    }

    private func ejectDevice(_ device: SidebarVolume) {
        guard device.canEject else { return }
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = ["eject", device.path]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            try? process.run()
            process.waitUntilExit()
            DispatchQueue.main.async {
                refreshDevices()
            }
        }
    }
}

struct SidebarRailView: View {
    @Binding var path: String
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @State private var devices: [SidebarVolume] = []
    var onItemsChanged: () -> Void = {}
    var onReload: () -> Void = {}
    
    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                VStack(spacing: 6) {
                    FavoritesSidebarRows(
                        favoritesStore: favoritesStore,
                        path: $path,
                        showsTitle: false,
                        isSelected: isSelected,
                        onDropURLs: handleFavoriteDrop
                    )
                    .frame(maxWidth: .infinity)
                }
                
                Divider()
                    .padding(.horizontal, 4)
                
                VStack(spacing: 6) {
                    ForEach(devices) { device in
                        SidebarRow(
                            title: device.name,
                            icon: device.icon,
                            isSelected: isSelected(device.path),
                            dropDestinationPath: device.path,
                            onDropURLs: handleSidebarDrop,
                            onSelect: { path = device.path },
                            showsTitle: false
                        )
                    }
                }
                
                Divider()
                    .padding(.horizontal, 4)
                
                SidebarRow(
                    title: "废纸篓",
                    icon: "trash",
                    isSelected: isSelected(trashPath),
                    dropDestinationPath: trashPath,
                    onDropURLs: handleSidebarDrop,
                    onSelect: {
                        if TrashLoader.isTrashPath(path) {
                            onReload()
                        } else {
                            path = trashPath
                        }
                    },
                    showsTitle: false
                )
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 10)
        }
        .onAppear(perform: refreshDevices)
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didMountNotification)) { _ in
            refreshDevices()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didUnmountNotification)) { _ in
            refreshDevices()
        }
    }
    
    private func refreshDevices() {
        devices = SidebarVolumeLoader.load()
    }
    
    private var trashPath: String {
        TrashLoader.userTrashPath
    }
    
    private func isSelected(_ sidebarPath: String) -> Bool {
        if TrashLoader.isTrashPath(sidebarPath) {
            return TrashLoader.isTrashPath(path)
        }
        return pathsRepresentSameLocation(path, sidebarPath)
    }
    
    private func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = (lhs as NSString).standardizingPath
        let normalizedRHS = (rhs as NSString).standardizingPath
        if normalizedLHS == normalizedRHS { return true }
        
        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }
    
    private func handleFavoriteDrop(_ urls: [URL], to destinationPath: String, copy: Bool, insertBefore: Int?) {
        FavoriteSidebarDrop.handle(
            urls: urls,
            to: destinationPath,
            copy: copy,
            insertBefore: insertBefore,
            favoritesStore: favoritesStore,
            onItemsChanged: onItemsChanged
        )
    }
    
    private func handleSidebarDrop(_ urls: [URL], to destinationPath: String, copy: Bool) {
        if TrashLoader.isTrashPath(destinationPath) {
            FileOperations.trashItems(urls, completion: onItemsChanged)
            return
        }
        let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
        FileOperations.moveItems(urls, to: destination, copy: copy, completion: onItemsChanged)
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    var dropDestinationPath: String?
    var onDropURLs: (([URL], String, Bool) -> Void)?
    let onSelect: () -> Void
    var showsTitle: Bool = true
    var trailingAccessory: (() -> AnyView)? = nil

    @State private var isDropTargeted = false
    
    var body: some View {
        let rowContent = Group {
            if showsTitle {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(title)
                    Spacer(minLength: 0)
                    if let trailingAccessory {
                        trailingAccessory()
                    }
                }
            } else {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Image(systemName: icon)
                    Spacer(minLength: 0)
                }
            }
        }
        .font(.body)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowBackgroundColor)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        
        Group {
            Button(action: onSelect) {
                rowContent
            }
            .buttonStyle(.plain)
            .background {
                if !showsTitle {
                    HoverTooltipAnchor(text: title)
                }
            }
        }
        .frame(height: showsTitle ? nil : FavoriteSidebarRailLayout.rowHeight)
        .onDrop(
            of: [.fileURL],
            delegate: FileDropDelegate(isTargeted: $isDropTargeted) { urls, copy in
                guard let destinationPath = dropDestinationPath,
                      let onDropURLs else {
                    return
                }
                onDropURLs(urls, destinationPath, copy)
            }
        )
    }
    
    private var rowBackgroundColor: Color {
        if isDropTargeted {
            return Color.accentColor.opacity(0.2)
        }
        if isSelected {
            return Color(nsColor: .unemphasizedSelectedContentBackgroundColor)
        }
        return .clear
    }
}

struct FileContextActions {
    var open: (FileItem) -> Void = { _ in }
    var openWith: (FileItem) -> Void = { _ in }
    var openWithApplication: ([FileItem], URL) -> Void = { _, _ in }
    var cut: ([FileItem]) -> Void = { _ in }
    var copy: ([FileItem]) -> Void = { _ in }
    var copyFilename: (FileItem) -> Void = { _ in }
    var copyPaths: ([FileItem]) -> Void = { _ in }
    var delete: ([FileItem]) -> Void = { _ in }
    var rename: (FileItem) -> Void = { _ in }
    var showInfo: ([FileItem]) -> Void = { _ in }
    var canPaste: (String) -> Bool = { _ in false }
    var paste: (String) -> Void = { _ in }
    var isFavorited: (FileItem) -> Bool = { _ in false }
    var addToFavorites: (FileItem) -> Void = { _ in }
    var isInTrash: Bool = false
    var emptyTrash: () -> Void = {}
    var putBack: ([FileItem]) -> Void = { _ in }
    var deleteImmediately: ([FileItem]) -> Void = { _ in }
    var openTerminal: (FileItem) -> Void = { _ in }
    var openInNewWindow: (FileItem) -> Void = { _ in }
}

/// 将目录大小回填限制在表格内部，避免 overlay 发布时触发整表选中同步。
private struct DirectorySizeTableBridge<Content: View>: View {
    @ObservedObject var overlay: DirectorySizeOverlay
    @ViewBuilder let content: (DirectorySizeColumnProvider) -> Content
    
    var body: some View {
        content(
            DirectorySizeColumnProvider(
                revision: overlay.revision,
                display: { overlay.sizeDisplay(for: $0) }
            )
        )
    }
}

/// 缩略图模式目录元数据（大小 + 子项数量）回填桥接。
private struct ThumbnailMetadataBridge<Content: View>: View {
    @ObservedObject var sizeOverlay: DirectorySizeOverlay
    @ObservedObject var countOverlay: DirectoryItemCountOverlay
    @ViewBuilder let content: (DirectorySizeColumnProvider, DirectoryItemCountColumnProvider) -> Content
    
    var body: some View {
        content(
            DirectorySizeColumnProvider(
                revision: sizeOverlay.revision,
                display: { sizeOverlay.sizeDisplay(for: $0) }
            ),
            DirectoryItemCountColumnProvider(
                revision: countOverlay.revision,
                display: { countOverlay.countDisplay(for: $0) }
            )
        )
    }
}

extension SidebarRow {
    init<Accessory: View>(
        title: String,
        icon: String,
        isSelected: Bool,
        dropDestinationPath: String? = nil,
        onDropURLs: (([URL], String, Bool) -> Void)? = nil,
        onSelect: @escaping () -> Void,
        showsTitle: Bool = true,
        @ViewBuilder trailingAccessory: @escaping () -> Accessory
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.dropDestinationPath = dropDestinationPath
        self.onDropURLs = onDropURLs
        self.onSelect = onSelect
        self.showsTitle = showsTitle
        self.trailingAccessory = { AnyView(trailingAccessory()) }
    }
}

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    @Binding var showPreview: Bool
    let searchText: String
    @Binding var quickSearchText: String
    @Binding var isQuickSearchVisible: Bool
    @Binding var isFileListRenaming: Bool
    let focusToken: UInt
    let currentDirectoryPath: String
    let canNavigateToParent: Bool
    let showHiddenFiles: Bool
    let directorySizeOverlay: DirectorySizeOverlay
    let directoryItemCountOverlay: DirectoryItemCountOverlay
    let viewMode: FileListViewMode
    let thumbnailCellSize: CGFloat
    let isLoading: Bool
    let onThumbnailCellSizeChange: (CGFloat) -> Void
    let onItemOpen: (FileItem) -> Void
    let onBlankDoubleClick: () -> Void
    let onItemsChanged: ([String]) -> Void
    let onScheduleVisibleDirectorySizes: ([String]) -> Void
    let onScheduleVisibleDirectoryItemCounts: ([String]) -> Void
    let contextActions: FileContextActions
    let blankMenuActions: FileListBlankMenuActions
    let canNavigateBack: Bool
    let onNavigateBack: () -> Void
    
    @ObservedObject private var preferencesStore = FileListPreferencesStore.shared
    @State private var isCurrentDirectoryDropTargeted = false
    @FocusState private var isQuickSearchFieldFocused: Bool
    @State private var quickSearchAutoCloseWorkItem: DispatchWorkItem?
    @AppStorage("explorer.treeExpandEnabled") private var treeExpandEnabled = true
    @State private var expandedDirectoryIDs: Set<String> = []
    @State private var expandingDirectoryIDs: Set<String> = []
    @State private var cachedChildrenByDirectoryID: [String: [FileItem]] = [:]
    @State private var expandErrorByDirectoryID: [String: String] = [:]
    @State private var directoryLoadGenerationByID: [String: UInt] = [:]
    
    private var showParentDirectoryRow: Bool {
        canNavigateToParent && searchText.isEmpty
    }
    
    private struct VisibleNode {
        let item: FileItem
        let depth: Int
        let parentID: String?
    }
    
    private var rootItemsByID: [String: FileItem] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }
    
    private var treeEnabled: Bool {
        viewMode == .list && treeExpandEnabled && searchText.isEmpty
    }
    
    private var visibleTreeNodes: [VisibleNode] {
        guard treeEnabled else {
            return items.map { VisibleNode(item: $0, depth: 0, parentID: nil) }
        }
        var nodes: [VisibleNode] = []
        nodes.reserveCapacity(items.count)
        appendVisibleNodes(
            from: items,
            depth: 0,
            parentID: nil,
            result: &nodes
        )
        return nodes
    }
    
    private var tableRowItems: [FileItem] {
        var rows: [FileItem] = []
        if showParentDirectoryRow {
            rows.append(FileItem.parentDirectoryEntry())
        }
        rows.append(contentsOf: visibleTreeNodes.map(\.item))
        return rows
    }
    
    private var parentDirectoryURL: URL? {
        FileItem.parentDirectoryURL(from: currentDirectoryPath)
    }
    
    var body: some View {
        FileListPanelLayout {
            Group {
                if isLoading {
                    FileListLoadingPlaceholderView(
                        viewMode: viewMode,
                        thumbnailCellSize: thumbnailCellSize
                    )
                } else {
                    switch viewMode {
                    case .list:
                        fileTable
                    case .thumbnail:
                        fileThumbnailGrid
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .background(FileListAutoFocusRequester(token: focusToken))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isCurrentDirectoryDropTargeted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isQuickSearchVisible {
                quickSearchBar
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
                    .transition(.opacity)
            }
        }
        .onChange(of: isQuickSearchVisible) { visible in
            if !visible {
                cancelQuickSearchAutoClose()
                isQuickSearchFieldFocused = false
                return
            }
            refreshQuickSearchAutoCloseTimer()
        }
        .onChange(of: isQuickSearchFieldFocused) { _ in
            refreshQuickSearchAutoCloseTimer()
        }
        .onDisappear {
            cancelQuickSearchAutoClose()
        }
        .onChange(of: currentDirectoryPath) { _ in
            closeQuickSearch()
            isFileListRenaming = false
            FileListTableController.shared?.cancelRenameIfNeededForDataUpdate()
            resetTreeState(keepExpanded: false)
        }
        .onChange(of: showHiddenFiles) { _ in
            resetTreeState(keepExpanded: true)
        }
        .onChange(of: searchText) { newValue in
            if !newValue.isEmpty {
                expandingDirectoryIDs.removeAll()
            }
        }
    }
    
    private var fileTable: some View {
        let listRows = makeListRows()
        let tableInteraction = makeFileListInteraction()
        
        return DirectorySizeTableBridge(overlay: directorySizeOverlay) { sizeProvider in
            FileListTableHost(
                rows: listRows,
                interaction: tableInteraction,
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                ),
                preferencesStore: preferencesStore,
                onOpenRow: { row in
                    guard let item = tableRowItems.first(where: { $0.id == row.id }) else { return }
                    onItemOpen(item)
                },
                onVisibleDirectoryPathsChanged: onScheduleVisibleDirectorySizes,
                directorySizeProvider: sizeProvider
            )
            .onAppear {
                preferencesStore.resetToDefaultIfNeeded()
            }
        }
    }
    
    private var fileThumbnailGrid: some View {
        let listRows = makeListRows()
        let tableInteraction = makeFileListInteraction()
        
        return ThumbnailMetadataBridge(
            sizeOverlay: directorySizeOverlay,
            countOverlay: directoryItemCountOverlay
        ) { sizeProvider, countProvider in
            FileListThumbnailHost(
                rows: listRows,
                interaction: tableInteraction,
                selection: Binding(
                    get: { selection },
                    set: { selection = $0 }
                ),
                preferencesStore: preferencesStore,
                cellSize: thumbnailCellSize,
                onCellSizeChange: onThumbnailCellSizeChange,
                onOpenRow: { row in
                    guard let item = tableRowItems.first(where: { $0.id == row.id }) else { return }
                    onItemOpen(item)
                },
                onVisibleDirectoryPathsChanged: { paths in
                    onScheduleVisibleDirectorySizes(paths)
                    onScheduleVisibleDirectoryItemCounts(paths)
                },
                directorySizeProvider: sizeProvider,
                directoryItemCountProvider: countProvider
            )
            .onAppear {
                preferencesStore.resetToDefaultIfNeeded()
            }
        }
    }
    
    private func makeFileListInteraction() -> FileListTableInteraction {
        FileListTableInteraction(
            searchText: searchText,
            quickSearchText: quickSearchText,
            blankMenuActions: blankMenuActions,
            onBlankSingleClick: {
                if !selection.isEmpty {
                    selection.removeAll()
                }
            },
            onBlankDoubleClick: onBlankDoubleClick,
            canDelete: {
                !selection.isEmpty && !selection.contains(FileItem.parentDirectoryID)
            },
            onDelete: {
                let deletable = items(for: selection).filter { !$0.isParentDirectoryEntry }
                contextActions.delete(deletable)
            },
            canNavigateBack: { canNavigateBack },
            onNavigateBack: onNavigateBack,
            onTableFocusChanged: { focused in
                guard focused, isQuickSearchVisible else { return }
                // AppKit 表格接管 firstResponder 时，显式让快速搜索框失焦并启动自动关闭计时。
                isQuickSearchFieldFocused = false
                refreshQuickSearchAutoCloseTimer()
            },
            onQuickSearchInput: { input in
                appendQuickSearchText(input)
            },
            onQuickSearchBackspace: {
                removeLastQuickSearchCharacter()
            },
            onQuickSearchEscape: {
                closeQuickSearch()
            },
            onDragEnded: {
                resetTreeState(keepExpanded: true)
                onItemsChanged([])
            },
            onToggleExpand: { row in
                guard row.isDirectory, !row.isParentDirectoryEntry else { return }
                toggleExpansion(for: row.id)
            },
            canRename: { row in
                !row.isParentDirectoryEntry && !contextActions.isInTrash
            },
            performRename: { row, newName, completion in
                guard let item = tableRowItems.first(where: { $0.id == row.id }) else {
                    completion(false)
                    return
                }
                let oldPath = item.id
                switch FileOperations.moveItem(item, toNewName: newName) {
                case .success(let newURL):
                    selection = [newURL.path]
                    resetTreeState(keepExpanded: true)
                    onItemsChanged([oldPath])
                    completion(true)
                case .failure(let error):
                    NSAlert(error: error as NSError).runModal()
                    completion(false)
                }
            },
            onRenameEditingChanged: { isFileListRenaming = $0 },
            makeContextMenu: { clickedRow, selectedIDs in
                let selectedItems = tableRowItems.filter { selectedIDs.contains($0.id) }
                return FileListRowContextMenuBuilder.makeMenu(
                    clickedRow: clickedRow,
                    selectedItems: selectedItems,
                    currentDirectoryPath: currentDirectoryPath,
                    showHiddenFiles: showHiddenFiles,
                    actions: contextActions
                )
            },
            popUpContextMenu: { menu, event, view, fileURLs in
                FileServicesMenuSupport.popUpContextMenu(menu, with: event, for: view, fileURLs: fileURLs)
            },
            servicesRequestor: FileServicesMenuRequestor.shared,
            dropDestinationPath: { row in
                if row.isParentDirectoryEntry {
                    return parentDirectoryURL?.path
                }
                guard row.isDirectory else { return nil }
                return row.iconPath
            },
            currentDirectoryDropPath: currentDirectoryPath,
            canAcceptDrop: { destinationPath, urls in
                let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
                return FileOperations.canMoveItems(urls, to: destination)
            },
            performDrop: { destinationPath, urls, copy in
                let destination = URL(fileURLWithPath: destinationPath, isDirectory: true)
                FileOperations.moveItems(urls, to: destination, copy: copy) {
                    resetTreeState(keepExpanded: true)
                    onItemsChanged(invalidationPaths(for: urls, destinationPath: destinationPath))
                }
            },
            onCurrentDirectoryDropHighlightChanged: { isTargeted in
                isCurrentDirectoryDropTargeted = isTargeted
            },
            onSpacePreview: {
                guard !selection.isEmpty else { return }
                showPreview = true
            }
        )
    }
    
    private func items(for ids: Set<FileItem.ID>) -> [FileItem] {
        tableRowItems.filter { ids.contains($0.id) }
    }
    
    private func makeListRows() -> [FileListRow] {
        var rows: [FileListRow] = []
        rows.reserveCapacity(tableRowItems.count)
        
        if showParentDirectoryRow {
            rows.append(FileListRow(item: FileItem.parentDirectoryEntry()))
        }
        
        for node in visibleTreeNodes {
            let item = node.item
            rows.append(
                FileListRow(
                    item: item,
                    directorySizeDisplay: nil,
                    depth: node.depth,
                    parentID: node.parentID,
                    isExpandable: item.isDirectory && !item.isParentDirectoryEntry,
                    isExpanded: expandedDirectoryIDs.contains(item.id),
                    isExpanding: expandingDirectoryIDs.contains(item.id),
                    expandErrorMessage: expandErrorByDirectoryID[item.id]
                )
            )
        }
        return rows
    }
    
    private func appendVisibleNodes(
        from sourceItems: [FileItem],
        depth: Int,
        parentID: String?,
        result: inout [VisibleNode]
    ) {
        for item in sourceItems {
            result.append(VisibleNode(item: item, depth: depth, parentID: parentID))
            guard treeEnabled,
                  item.isDirectory,
                  expandedDirectoryIDs.contains(item.id),
                  let children = cachedChildrenByDirectoryID[item.id]
            else { continue }
            appendVisibleNodes(
                from: children,
                depth: depth + 1,
                parentID: item.id,
                result: &result
            )
        }
    }
    
    private func toggleExpansion(for directoryID: String) {
        guard treeEnabled else { return }
        if expandedDirectoryIDs.contains(directoryID) {
            collapse(directoryID)
            return
        }
        expandedDirectoryIDs.insert(directoryID)
        expandErrorByDirectoryID[directoryID] = nil
        if cachedChildrenByDirectoryID[directoryID] == nil {
            loadChildren(for: directoryID)
        }
    }
    
    private func collapse(_ directoryID: String) {
        expandedDirectoryIDs.remove(directoryID)
        expandingDirectoryIDs.remove(directoryID)
        expandErrorByDirectoryID[directoryID] = nil
        
        let descendantPrefix = directoryID.hasSuffix("/") ? directoryID : directoryID + "/"
        expandedDirectoryIDs = expandedDirectoryIDs.filter { !$0.hasPrefix(descendantPrefix) }
        expandingDirectoryIDs = expandingDirectoryIDs.filter { !$0.hasPrefix(descendantPrefix) }
    }
    
    private func loadChildren(for directoryID: String) {
        let currentGeneration = (directoryLoadGenerationByID[directoryID] ?? 0) + 1
        directoryLoadGenerationByID[directoryID] = currentGeneration
        expandingDirectoryIDs.insert(directoryID)
        
        let propertyKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
        ]
        let shouldShowHiddenFiles = showHiddenFiles
        
        Task {
            do {
                let canonicalPath = URL(fileURLWithPath: directoryID).resolvingSymlinksInPath().standardizedFileURL.path
                let parentCanonical = URL(fileURLWithPath: currentDirectoryPath)
                    .resolvingSymlinksInPath()
                    .standardizedFileURL
                    .path
                if canonicalPath == parentCanonical {
                    throw NSError(
                        domain: "Explorer.FileTree",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "检测到循环链接"]
                    )
                }
                
                let url = URL(fileURLWithPath: directoryID)
                let options: FileManager.DirectoryEnumerationOptions = shouldShowHiddenFiles
                    ? [.skipsPackageDescendants]
                    : [.skipsHiddenFiles, .skipsPackageDescendants]
                let urls = try FileManager.default.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: Array(propertyKeys),
                    options: options
                )
                var loaded: [FileItem] = []
                loaded.reserveCapacity(urls.count)
                for childURL in urls {
                    if let item = TrashLoader.fileItem(from: childURL, propertyKeys: propertyKeys) {
                        loaded.append(item)
                    }
                }
                
                await MainActor.run {
                    guard directoryLoadGenerationByID[directoryID] == currentGeneration else { return }
                    cachedChildrenByDirectoryID[directoryID] = loaded
                    expandingDirectoryIDs.remove(directoryID)
                    expandErrorByDirectoryID[directoryID] = nil
                }
            } catch {
                await MainActor.run {
                    guard directoryLoadGenerationByID[directoryID] == currentGeneration else { return }
                    cachedChildrenByDirectoryID[directoryID] = []
                    expandingDirectoryIDs.remove(directoryID)
                    let nsError = error as NSError
                    if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError {
                        expandErrorByDirectoryID[directoryID] = "无权限"
                    } else if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError {
                        expandErrorByDirectoryID[directoryID] = "目录不存在"
                    } else {
                        expandErrorByDirectoryID[directoryID] = nsError.localizedDescription
                    }
                }
            }
        }
    }
    
    private func resetTreeState(keepExpanded: Bool) {
        expandingDirectoryIDs.removeAll()
        expandErrorByDirectoryID.removeAll()
        directoryLoadGenerationByID.removeAll()
        if keepExpanded {
            cachedChildrenByDirectoryID.removeAll()
        } else {
            cachedChildrenByDirectoryID.removeAll()
            expandedDirectoryIDs.removeAll()
        }
    }

    private var quickSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("快速搜索", text: $quickSearchText)
                .textFieldStyle(.plain)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focused($isQuickSearchFieldFocused)
                .onChange(of: quickSearchText) { newValue in
                    let normalized = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    if normalized != newValue {
                        quickSearchText = normalized
                        return
                    }
                    isQuickSearchVisible = !normalized.isEmpty
                    if normalized.isEmpty {
                        cancelQuickSearchAutoClose()
                    } else {
                        refreshQuickSearchAutoCloseTimer()
                    }
                }
            Button {
                closeQuickSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("关闭快速搜索")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private func appendQuickSearchText(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        quickSearchText += trimmed
        isQuickSearchVisible = !quickSearchText.isEmpty
        refreshQuickSearchAutoCloseTimer()
    }

    private func removeLastQuickSearchCharacter() {
        guard !quickSearchText.isEmpty else { return }
        quickSearchText.removeLast()
        isQuickSearchVisible = !quickSearchText.isEmpty
        refreshQuickSearchAutoCloseTimer()
    }

    private func closeQuickSearch() {
        cancelQuickSearchAutoClose()
        quickSearchText = ""
        isQuickSearchVisible = false
    }
    
    private func refreshQuickSearchAutoCloseTimer() {
        guard isQuickSearchVisible else {
            cancelQuickSearchAutoClose()
            return
        }
        // Phase 2 语义：快速搜索框失焦后 5 秒自动关闭（与文件列表焦点无关）。
        if isQuickSearchFieldFocused {
            cancelQuickSearchAutoClose()
            return
        }
        
        cancelQuickSearchAutoClose()
        let workItem = DispatchWorkItem {
            closeQuickSearch()
        }
        quickSearchAutoCloseWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }
    
    private func cancelQuickSearchAutoClose() {
        quickSearchAutoCloseWorkItem?.cancel()
        quickSearchAutoCloseWorkItem = nil
    }
    
    private func invalidationPaths(for urls: [URL], destinationPath: String) -> [String] {
        var paths = Set<String>()
        paths.insert(destinationPath)
        for url in urls {
            paths.insert(url.path)
        }
        return Array(paths)
    }
}

/// 目录切换后自动聚焦文件列表（NSTableView），便于立即键入快速搜索。
private struct FileListAutoFocusRequester: NSViewRepresentable {
    let token: UInt
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.requestFocusIfNeeded(token: token, view: nsView)
    }
    
    final class Coordinator {
        private var lastToken: UInt = 0
        
        func requestFocusIfNeeded(token: UInt, view: NSView) {
            guard token != lastToken else { return }
            lastToken = token
            
            // 左侧点击切目录时，NSTableView 可能尚未完成挂载或 firstResponder 仍被侧栏占用；
            // 这里做几次轻量重试（短延迟），不阻塞也不影响目录大小计算。
            scheduleFocusAttempt(token: token, view: view, delay: 0)
            scheduleFocusAttempt(token: token, view: view, delay: 0.03)
            scheduleFocusAttempt(token: token, view: view, delay: 0.12)
        }
        
        private func scheduleFocusAttempt(token: UInt, view: NSView, delay: TimeInterval) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak view] in
                guard let self, let view else { return }
                guard token == self.lastToken else { return }
                guard let window = view.window,
                      let contentView = window.contentView,
                      let tableView = Self.findFileListTableView(in: contentView)
                else { return }
                
                if window.firstResponder === tableView {
                    return
                }
                window.makeFirstResponder(tableView)
            }
        }
        
        private static func findFileListTableView(in root: NSView) -> NSTableView? {
            if let table = root as? NSTableView, table.delegate is FileListTableController {
                return table
            }
            for subview in root.subviews {
                if let found = findFileListTableView(in: subview) {
                    return found
                }
            }
            return nil
        }
    }
}

enum FileDragDrop {
    static func shouldCopyFromCurrentEvent() -> Bool {
        NSApp.currentEvent?.modifierFlags.contains(.option) == true
    }
    
    static func shouldCopyFromDropInfo(_ info: DropInfo) -> Bool {
        _ = info
        return shouldCopyFromCurrentEvent()
    }
    
    static func shouldCopyFromDraggingInfo(_ info: NSDraggingInfo) -> Bool {
        _ = info
        return shouldCopyFromCurrentEvent()
    }
    
    static func dragOperation(for info: NSDraggingInfo) -> NSDragOperation {
        shouldCopyFromDraggingInfo(info) ? .copy : .move
    }
    
    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        
        func append(_ url: URL) {
            let standardized = url.standardizedFileURL
            if seen.insert(standardized.path).inserted {
                urls.append(standardized)
            }
        }
        
        if let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            objects.forEach { append($0) }
        }
        
        if let paths = pasteboard.propertyList(
            forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")
        ) as? [String] {
            paths.forEach { append(URL(fileURLWithPath: $0)) }
        }
        
        if let paths = pasteboard.propertyList(forType: .fileURL) as? [String] {
            paths.forEach { append(URL(fileURLWithPath: $0)) }
        }
        
        return urls
    }
    
    @MainActor
    static func loadFileURLs(from providers: [NSItemProvider]) async -> [URL] {
        var urls: [URL] = []
        var seen = Set<String>()
        for provider in providers {
            if let url = await loadFileURL(from: provider) {
                let path = url.standardizedFileURL.path
                if seen.insert(path).inserted {
                    urls.append(url)
                }
            }
        }
        return urls
    }
    
    @MainActor
    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { item, _ in
                continuation.resume(returning: item?.standardizedFileURL)
            }
        }
    }
}

/// 拖放目标显式提议 .move，避免 SwiftUI 默认 .copy 导致绿色加号光标。
private struct FileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: ([URL], Bool) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        if info.hasItemsConforming(to: [.fileURL]) { return true }
        return !FileDragDrop.fileURLs(from: NSPasteboard(name: .drag)).isEmpty
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        let hasDrop = validateDrop(info: info)
        isTargeted = hasDrop
        guard hasDrop else { return DropProposal(operation: .forbidden) }
        let copy = FileDragDrop.shouldCopyFromDropInfo(info)
        return DropProposal(operation: copy ? .copy : .move)
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let copy = FileDragDrop.shouldCopyFromDropInfo(info)
        
        // 同应用跨窗口拖拽时 SwiftUI itemProviders 常为空，改读 drag pasteboard。
        let dragURLs = FileDragDrop.fileURLs(from: NSPasteboard(name: .drag))
        if !dragURLs.isEmpty {
            onDrop(dragURLs, copy)
            return true
        }
        
        Task { @MainActor in
            let providers = info.itemProviders(for: [.fileURL])
            let urls = await FileDragDrop.loadFileURLs(from: providers)
            guard !urls.isEmpty else { return }
            onDrop(urls, copy)
        }
        return true
    }
}

private struct HorizontalResizeDivider: NSViewRepresentable {
    @Binding var trailingWidth: CGFloat
    let minTrailingWidth: CGFloat
    let maxTrailingWidth: CGFloat
    var onDragEnded: (() -> Void)?
    
    func makeNSView(context: Context) -> ResizeDividerNSView {
        ResizeDividerNSView()
    }
    
    func updateNSView(_ nsView: ResizeDividerNSView, context: Context) {
        context.coordinator.configure(
            trailingWidth: $trailingWidth,
            minTrailingWidth: minTrailingWidth,
            maxTrailingWidth: maxTrailingWidth,
            onDragEnded: onDragEnded,
            view: nsView
        )
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    final class Coordinator {
        func configure(
            trailingWidth: Binding<CGFloat>,
            minTrailingWidth: CGFloat,
            maxTrailingWidth: CGFloat,
            onDragEnded: (() -> Void)?,
            view: ResizeDividerNSView
        ) {
            view.onResize = { delta in
                let newWidth = trailingWidth.wrappedValue - delta
                trailingWidth.wrappedValue = min(
                    max(newWidth, minTrailingWidth),
                    maxTrailingWidth
                )
            }
            view.onDragEnded = onDragEnded
        }
    }
}

private final class ResizeDividerNSView: NSView {
    var onResize: ((CGFloat) -> Void)?
    var onDragEnded: (() -> Void)?
    private var lastMouseX: CGFloat?
    private var trackingArea: NSTrackingArea?
    
    override var isOpaque: Bool { false }
    
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .cursorUpdate, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    override func cursorUpdate(with event: NSEvent) {
        NSCursor.resizeLeftRight.set()
    }
    
    override func mouseDown(with event: NSEvent) {
        lastMouseX = event.locationInWindow.x
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let lastX = lastMouseX else { return }
        let currentX = event.locationInWindow.x
        let delta = currentX - lastX
        lastMouseX = currentX
        onResize?(delta)
    }
    
    override func mouseUp(with event: NSEvent) {
        lastMouseX = nil
        onDragEnded?()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSColor.separatorColor.setFill()
        let lineX = floor((bounds.width - 1) / 2)
        dirtyRect.intersection(NSRect(x: lineX, y: 0, width: 1, height: bounds.height)).fill()
    }
}

struct FilePreviewView: View {
    let hostWindowID: UUID
    @Binding var showPreview: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState
    let selection: Set<FileItem.ID>
    let items: [FileItem]
    let directoryPath: String
    let sortOrder: SortOrder
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    @ObservedObject var directorySizeOverlay: DirectorySizeOverlay
    @ObservedObject var directoryItemCountOverlay: DirectoryItemCountOverlay
    let onNavigate: (String) -> Void
    let onOpenItem: (FileItem) -> Void
    let onOpenTerminalAtPath: (String) -> Void
    @ObservedObject private var detachCoordinator = PreviewDetachCoordinator.shared

    private var selectedItems: [FileItem] {
        FileItem.resolveSelection(ids: selection, from: items)
    }

    private var selectedItem: FileItem? {
        selectedItems.first
    }

    var body: some View {
        if let selectedItem {
            if detachCoordinator.placement.showsPlaceholder(forSelectedFileID: selectedItem.id),
               case .detached(let sessionID, _) = detachCoordinator.placement,
               let session = PreviewSessionStore.shared.session(for: sessionID) {
                PreviewPlaceholderView(
                    fileName: session.previewContentItem?.name ?? selectedItem.name,
                    onFocus: { detachCoordinator.focusDetachedWindow() },
                    onDockBack: {
                        Task {
                            _ = await detachCoordinator.dockBack(
                                sessionID: sessionID,
                                currentSelectedFileID: selectedItem.id
                            )
                        }
                    }
                )
                .focusedValue(\.previewDetachCommands, PreviewDetachCommands(
                    canDetach: false,
                    canDock: true,
                    dockPreview: {
                        Task {
                            _ = await detachCoordinator.dockBack(
                                sessionID: sessionID,
                                currentSelectedFileID: selectedItem.id
                            )
                        }
                    }
                ))
            } else {
                FilePreviewSessionHost(
                    hostWindowID: hostWindowID,
                    selectedItem: selectedItem,
                    showPreview: $showPreview,
                    layout: layout,
                    directoryPath: directoryPath,
                    directoryItems: items,
                    sortOrder: sortOrder,
                    showHiddenFiles: showHiddenFiles,
                    autoCalculateDirectorySizes: autoCalculateDirectorySizes,
                    directorySizeOverlay: directorySizeOverlay,
                    directoryItemCountOverlay: directoryItemCountOverlay,
                    onNavigate: onNavigate,
                    onOpenItem: onOpenItem,
                    onOpenTerminalAtPath: onOpenTerminalAtPath,
                    detachCoordinator: detachCoordinator
                )
                .id(selectedItem.id)
            }
        } else {
            FilePreviewEmptyChrome(showPreview: $showPreview, layout: layout)
        }
    }
}

private struct FilePreviewEmptyChrome: View {
    @Binding var showPreview: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    layout.isPreviewContentCollapsed.toggle()
                } label: {
                    Image(systemName: layout.isPreviewContentCollapsed ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .help(layout.isPreviewContentCollapsed ? "展开预览" : "折叠预览")

                Text("预览")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 0, maxWidth: 72, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(-1)

                Spacer(minLength: 0)

                Button {
                    showPreview = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭预览")
                .fixedSize()
                .layoutPriority(2)
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)

            if !layout.isPreviewContentCollapsed {
                Divider()
                Text("Select a file to preview")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct FilePreviewSessionHost: View {
    let hostWindowID: UUID
    let selectedItem: FileItem
    @Binding var showPreview: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState
    let directoryPath: String
    let directoryItems: [FileItem]
    let sortOrder: SortOrder
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    @ObservedObject var directorySizeOverlay: DirectorySizeOverlay
    @ObservedObject var directoryItemCountOverlay: DirectoryItemCountOverlay
    let onNavigate: (String) -> Void
    let onOpenItem: (FileItem) -> Void
    let onOpenTerminalAtPath: (String) -> Void
    @ObservedObject var detachCoordinator: PreviewDetachCoordinator

    @Environment(\.openWindow) private var openWindow
    @StateObject private var session: PreviewSession

    init(
        hostWindowID: UUID,
        selectedItem: FileItem,
        showPreview: Binding<Bool>,
        layout: ExplorerWindowLayoutState,
        directoryPath: String,
        directoryItems: [FileItem],
        sortOrder: SortOrder,
        showHiddenFiles: Bool,
        autoCalculateDirectorySizes: Bool,
        directorySizeOverlay: DirectorySizeOverlay,
        directoryItemCountOverlay: DirectoryItemCountOverlay,
        onNavigate: @escaping (String) -> Void,
        onOpenItem: @escaping (FileItem) -> Void,
        onOpenTerminalAtPath: @escaping (String) -> Void,
        detachCoordinator: PreviewDetachCoordinator
    ) {
        self.hostWindowID = hostWindowID
        self.selectedItem = selectedItem
        _showPreview = showPreview
        self.layout = layout
        self.directoryPath = directoryPath
        self.directoryItems = directoryItems
        self.sortOrder = sortOrder
        self.showHiddenFiles = showHiddenFiles
        self.autoCalculateDirectorySizes = autoCalculateDirectorySizes
        self.directorySizeOverlay = directorySizeOverlay
        self.directoryItemCountOverlay = directoryItemCountOverlay
        self.onNavigate = onNavigate
        self.onOpenItem = onOpenItem
        self.onOpenTerminalAtPath = onOpenTerminalAtPath
        self.detachCoordinator = detachCoordinator
        let session = PreviewSessionStore.shared.existingInlineSession(
            hostWindowID: hostWindowID,
            fileID: selectedItem.id
        ) ?? PreviewSession(hostWindowID: hostWindowID, file: selectedItem)
        _session = StateObject(wrappedValue: session)
        PreviewSessionStore.shared.register(session)
    }

    private var canDetachPreview: Bool {
        guard session.previewContentItem != nil else { return false }
        if selectedItem.isDirectory, session.folderInlineChild == nil { return false }
        return !session.location.isDetached
    }

    private var previewToolbarTitleMaxWidth: CGFloat {
        if session.isShowingFolderChildPreview {
            return 56
        }
        return 72
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Button {
                    layout.isPreviewContentCollapsed.toggle()
                } label: {
                    Image(systemName: layout.isPreviewContentCollapsed ? "chevron.up" : "chevron.down")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .help(layout.isPreviewContentCollapsed ? "展开预览" : "折叠预览")

                if session.isShowingFolderChildPreview {
                    Button {
                        session.folderInlineChild = nil
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.borderless)
                    .help("返回文件夹")
                }

                Text(session.previewContentItem?.name ?? selectedItem.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(minWidth: 0, maxWidth: previewToolbarTitleMaxWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(-1)

                if !layout.isPreviewContentCollapsed, let item = session.toolbarFileItem {
                    PreviewToolbarOverflowLayout(
                        spacing: 4,
                        items: session.previewToolbarItems(for: item)
                    )
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
                    .layoutPriority(1)
                } else {
                    Spacer(minLength: 0)
                }

                if canDetachPreview {
                    Button {
                        detachCoordinator.detach(
                            session: session,
                            directoryPath: directoryPath,
                            directoryItems: directoryItems,
                            sortOrder: sortOrder,
                            showHiddenFiles: showHiddenFiles,
                            openWindow: openWindow
                        )
                    } label: {
                        Image(systemName: "macwindow.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .help("在独立窗口中打开")
                    .fixedSize()
                    .layoutPriority(2)
                }

                Button {
                    showPreview = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭预览")
                .fixedSize()
                .layoutPriority(2)
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
            
            if !layout.isPreviewContentCollapsed {
                Divider()

                if let folderInlineChild = session.folderInlineChild {
                    FileContentView(session: session)
                    .id(folderInlineChild.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else if selectedItem.isDirectory {
                    FolderPreviewView(
                        folder: selectedItem,
                        showHiddenFiles: showHiddenFiles,
                        autoCalculateDirectorySizes: autoCalculateDirectorySizes,
                        sizeOverlay: directorySizeOverlay,
                        countOverlay: directoryItemCountOverlay,
                        showContentsList: true,
                        onNavigate: onNavigate,
                        onOpenFolder: { onOpenItem(selectedItem) },
                        onOpenTerminal: { onOpenTerminalAtPath(selectedItem.id) },
                        onPreviewChild: { session.folderInlineChild = $0 },
                        onOpenChild: onOpenItem
                    )
                    .id(selectedItem.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    FileContentView(session: session)
                    .id(selectedItem.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: session.folderInlineChild?.id) { _ in
            session.resetControls()
        }
        .onChange(of: session.pdfCurrentPage) { newValue in
            if newValue > 0 {
                session.pdfPageInput = "\(newValue)"
            } else {
                session.pdfPageInput = ""
            }
        }
        .sheet(isPresented: $session.showImageResizeSheet) {
            let dialogSize = session.imageResizeDialogSize
            let oriented = session.imageEffectiveOrientedPixelSize
            ImageResizeSheet(
                initialWidth: dialogSize.width,
                initialHeight: dialogSize.height,
                aspectWidth: max(1, Int(oriented.width.rounded())),
                aspectHeight: max(1, Int(oriented.height.rounded())),
                onCancel: { session.showImageResizeSheet = false },
                onApply: { width, height in
                    session.performImageEdit {
                        session.imageResizeTargetSize = CGSize(width: width, height: height)
                    }
                    session.imageZoomScale = 1.0
                    session.imageZoomAction = .fit
                    session.showImageResizeSheet = false
                }
            )
        }
        .onChange(of: session.imageEditUndoClearNonce) { _ in
            session.clearImageEditUndoStack()
        }
        .focusedValue(\.previewDetachCommands, PreviewDetachCommands(
            canDetach: canDetachPreview,
            canDock: {
                if case .detached(let sessionID, _) = detachCoordinator.placement {
                    return sessionID == session.id
                }
                return false
            }(),
            detachPreview: {
                detachCoordinator.detach(
                    session: session,
                    directoryPath: directoryPath,
                    directoryItems: directoryItems,
                    sortOrder: sortOrder,
                    showHiddenFiles: showHiddenFiles,
                    openWindow: openWindow
                )
            },
            dockPreview: {
                Task {
                    _ = await detachCoordinator.dockBack(
                        sessionID: session.id,
                        currentSelectedFileID: selectedItem.id
                    )
                }
            }
        ))
    }
}

struct FileContentView: View {
    @ObservedObject var session: PreviewSession
    @ObservedObject private var customPreviewStore = CustomPreviewRuleStore.shared
    @State private var lastAppliedLoadTaskID: String?
    @State private var contentOpacity: Double = 1

    private var item: FileItem {
        session.browseTarget
    }

    private var fileExtension: String {
        item.url.pathExtension.lowercased()
    }

    private var isHtmlPreviewMode: Bool {
        PreviewTypeClassifier.isHtmlFile(fileExtension) && session.htmlMode == .preview
    }

    private var usesMarkdownPreview: Bool {
        PreviewTypeClassifier.isMarkdownFile(fileExtension) && session.markdownMode == .preview
    }

    private var imageResizePreviewIdentity: String {
        guard let size = session.imageResizeTargetSize else { return "image-original-size" }
        return "image-resize-\(Int(size.width.rounded()))x\(Int(size.height.rounded()))"
    }

    private var loadTaskID: String {
        let contentID = session.browseTarget.id
        return "\(contentID)-\(session.archiveReloadToken)-\(customPreviewStore.revision)"
    }

    var body: some View {
        ZStack {
            if session.isLoading {
                ProgressView("Loading preview...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = session.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()

                    Text("Error loading preview")
                        .font(.headline)

                    Text(errorMsg)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let image = session.image {
                ImagePreviewContent(
                    image: image,
                    fileURL: item.url,
                    zoomScale: $session.imageZoomScale,
                    zoomAction: $session.imageZoomAction,
                    effectiveZoomPercent: $session.imageEffectiveZoomPercent,
                    rotationQuarterTurns: $session.imageRotationQuarterTurns,
                    flipHorizontal: $session.imageFlipHorizontal,
                    flipVertical: $session.imageFlipVertical,
                    resizeTargetSize: $session.imageResizeTargetSize,
                    eyedropperActive: $session.imageEyedropperActive,
                    pickedWebColor: $session.imagePickedWebColor
                )
                .id(imageResizePreviewIdentity)
            } else if let pdfDoc = session.pdfDocument {
                PDFPreview(
                    document: pdfDoc,
                    navigationAction: $session.pdfNavigateAction
                ) { currentPage, pageCount, scalePercent in
                    session.pdfCurrentPage = currentPage
                    session.pdfPageCount = pageCount
                    session.pdfScalePercent = scalePercent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let player = session.mediaPlayer {
                MediaPreview(
                    player: player,
                    controlAction: $session.mediaControlAction
                ) { isPlaying, isMuted in
                    session.mediaIsPlaying = isPlaying
                    session.mediaIsMuted = isMuted
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let officeRichText = session.officeRichText {
                OfficeRichTextPreview(
                    attributedText: officeRichText,
                    wrapLines: session.textWrapEnabled,
                    zoomScale: session.officeZoomScale
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let officeURL = session.officeURL {
                QuickLookPreview(
                    url: officeURL,
                    reloadToken: session.officeReloadToken,
                    zoomScale: session.officeZoomScale,
                    panMode: session.officePanMode
                )
                .padding(.bottom, 6)
            } else if !session.archiveEntries.isEmpty {
                ArchiveListPreview(
                    entries: session.archiveEntries,
                    truncated: session.archiveTruncated,
                    expanded: session.archiveExpanded,
                    copyAction: $session.archiveCopyAction
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else if isHtmlPreviewMode {
                HTMLFilePreview(fileURL: item.url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !session.textContent.isEmpty {
                if usesMarkdownPreview {
                    MarkdownFilePreview(
                        markdown: session.textContent,
                        wrapLines: session.textWrapEnabled,
                        zoomScale: $session.markdownPreviewScale
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextFilePreview(
                        text: session.textContent,
                        fileExtension: fileExtension,
                        wrapLines: session.textWrapEnabled,
                        fontSize: PreviewTypeClassifier.isMarkdownFile(fileExtension) ? session.markdownSourceFontSize : NSFont.systemFontSize,
                        action: $session.textPreviewAction
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if !session.isLoading, session.errorMessage == nil {
                CustomPreviewUnavailableView(
                    fileExtension: fileExtension,
                    onAddRule: { mode in
                        customPreviewStore.upsertRule(forExtension: fileExtension, mode: mode)
                    },
                    onOpenSettings: {
                        openPreviewSettings(prefillExtension: fileExtension)
                    }
                )
            } else {
                Text("Preview not available for this file type")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .opacity(contentOpacity)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding((session.isImagePreview || session.officeURL != nil || session.officeRichText != nil) ? 0 : 12)
        .task(id: loadTaskID) {
            await applyLoadTaskIfNeeded()
        }
        .onChange(of: session.browseTarget.id) { _ in
            guard session.browseContext != nil else { return }
            contentOpacity = 0.35
            withAnimation(.easeInOut(duration: PreviewBrowserStripMetrics.contentCrossfadeDuration)) {
                contentOpacity = 1
            }
        }
        .onChange(of: session.htmlMode) { newMode in
            guard PreviewTypeClassifier.isHtmlFile(item.url.pathExtension) else { return }
            if newMode == .source, session.textContent.isEmpty {
                Task { await session.loadTextContentIfNeeded() }
            }
        }
        .onChange(of: session.imagePreviewAction) { action in
            guard let action else { return }
            switch action {
            case .save:
                Task { await session.saveEditedImage() }
            }
            DispatchQueue.main.async { session.imagePreviewAction = nil }
        }
        .alert("保存失败", isPresented: Binding(
            get: { session.imageSaveErrorMessage != nil },
            set: { if !$0 { session.imageSaveErrorMessage = nil } }
        )) {
            Button("好", role: .cancel) {}
        } message: {
            Text(session.imageSaveErrorMessage ?? "")
        }
    }

    @MainActor
    private func applyLoadTaskIfNeeded() async {
        if lastAppliedLoadTaskID == loadTaskID {
            return
        }

        if lastAppliedLoadTaskID == nil,
           session.loadPhase == .loaded,
           !session.isLoading {
            lastAppliedLoadTaskID = loadTaskID
            return
        }

        if session.browseContext != nil, lastAppliedLoadTaskID != nil {
            try? await Task.sleep(nanoseconds: PreviewBrowserStripMetrics.switchDebounceMilliseconds * 1_000_000)
            guard !Task.isCancelled else { return }
        }

        guard lastAppliedLoadTaskID != loadTaskID else { return }

        lastAppliedLoadTaskID = loadTaskID
        session.cancelLoad()
        session.resetControls()
        session.beginLoadTask(customPreviewRevision: Int(customPreviewStore.revision))
    }
}


enum ImageZoomAction: Equatable {
    case fit
    case actualSize
}

enum ImagePreviewAction: Equatable {
    case save
}

enum TextPreviewAction: Equatable {
    case copyAll
    case scrollTop
    case scrollBottom
}

enum MediaControlAction: Equatable {
    case togglePlayPause
    case toggleMute
}

enum ArchivePreviewAction: Equatable {
    case copyList
}

enum PDFNavigationAction: Equatable {
    case previous
    case next
    case zoomIn
    case zoomOut
    case fitWidth
    case fitPage
    case goToPage(Int)
}

enum MarkdownDisplayMode: Equatable {
    case preview
    case source
}

enum HtmlDisplayMode: Equatable {
    case preview
    case source
}

private struct HTMLFilePreview: NSViewRepresentable {
    let fileURL: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        load(into: webView, coordinator: context.coordinator)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastLoadedPath != fileURL.path else { return }
        load(into: webView, coordinator: context.coordinator)
    }

    private func load(into webView: WKWebView, coordinator: Coordinator) {
        let accessURL = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: accessURL)
        coordinator.lastLoadedPath = fileURL.path
    }

    final class Coordinator {
        var lastLoadedPath: String?
    }
}

private struct MarkdownFilePreview: NSViewRepresentable {
    let markdown: String
    let wrapLines: Bool
    @Binding var zoomScale: CGFloat

    private static let tableSeparatorRegex: NSRegularExpression? = {
        try? NSRegularExpression(
            pattern: "^\\s*\\|?\\s*:?-{2,}:?\\s*(\\|\\s*:?-{2,}:?\\s*)+\\|?\\s*$",
            options: []
        )
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapLines
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapLines
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        if !wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.currentScale = 1.0
        context.coordinator.lastMarkdown = markdown

        applyMarkdown(markdown, to: textView)
        applyScale(zoomScale, to: textView, context: context)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        scrollView.hasHorizontalScroller = !wrapLines
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isHorizontallyResizable = !wrapLines
        if wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if context.coordinator.lastMarkdown != markdown {
            applyMarkdown(markdown, to: textView)
            context.coordinator.lastMarkdown = markdown
            textView.scrollToBeginningOfDocument(nil)
        }

        applyScale(zoomScale, to: textView, context: context)
    }

    private func applyMarkdown(_ markdown: String, to textView: NSTextView) {
        // 以原始文本作为预览基准，保证换行/缩进完全保留，再做轻量样式增强。
        // 表格需要额外做一次“列宽对齐”，才能在等宽字体下呈现出表格外观。
        let formattedMarkdown = formatMarkdownTables(markdown)
        let rendered = NSMutableAttributedString(string: formattedMarkdown)

        let fullRange = NSRange(location: 0, length: rendered.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
        paragraphStyle.lineSpacing = 2
        rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        rendered.addAttribute(
            .font,
            value: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .regular),
            range: fullRange
        )

        // 低成本标题增强：仅识别 ATX 标题（# 到 ######），并在预览里隐藏前缀 # 号。
        var renderedString = rendered.string as NSString
        var fullRenderedRange = NSRange(location: 0, length: renderedString.length)
        let headingRegex = try? NSRegularExpression(pattern: "^(#{1,6})\\s+(.+)$", options: [.anchorsMatchLines])
        if let headingRegex {
            let matches = headingRegex.matches(in: rendered.string, options: [], range: fullRenderedRange)
            for match in matches.reversed() {
                guard match.numberOfRanges >= 3, match.range(at: 2).location != NSNotFound else { continue }

                let level = max(1, min(6, match.range(at: 1).length))
                let markerRange = match.range(at: 1)
                let titleRange = match.range(at: 2) // 整个「1. 构建前端」都加粗加大
                let markerEnd = markerRange.location + markerRange.length
                let removeLength = max(0, titleRange.location - markerEnd)
                let removeRange = NSRange(location: markerRange.location, length: markerRange.length + removeLength)

                rendered.replaceCharacters(in: removeRange, with: "")

                let adjustedTitleRange = NSRange(
                    location: max(0, titleRange.location - removeRange.length),
                    length: titleRange.length
                )
                let size = max(13, 22 - CGFloat(level) * 2)
                let font = NSFont.systemFont(ofSize: size, weight: .semibold)
                rendered.addAttribute(.font, value: font, range: adjustedTitleRange)
            }
            renderedString = rendered.string as NSString
            fullRenderedRange = NSRange(location: 0, length: renderedString.length)
        }

        // 低成本列表缩进：支持 -, *, + 与有序列表（1. / 2. ...）。
        let bulletRegex = try? NSRegularExpression(pattern: "^([ \\t]*)([-*+])\\s+", options: [.anchorsMatchLines])
        bulletRegex?.enumerateMatches(in: rendered.string, options: [], range: fullRenderedRange) { match, _, _ in
            guard
                let match,
                match.numberOfRanges >= 2,
                match.range.location != NSNotFound
            else { return }
            let lineRange = renderedString.lineRange(for: match.range)
            let leadingWhitespaceCount = max(0, match.range(at: 1).length)
            let indentBase = CGFloat(leadingWhitespaceCount) * 6
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
            style.lineSpacing = 2
            style.firstLineHeadIndent = indentBase
            style.headIndent = indentBase + 16
            rendered.addAttribute(.paragraphStyle, value: style, range: lineRange)
        }

        let orderedListRegex = try? NSRegularExpression(pattern: "^([ \\t]*)(\\d+)\\.\\s+", options: [.anchorsMatchLines])
        orderedListRegex?.enumerateMatches(in: rendered.string, options: [], range: fullRenderedRange) { match, _, _ in
            guard
                let match,
                match.numberOfRanges >= 2,
                match.range.location != NSNotFound
            else { return }
            let lineRange = renderedString.lineRange(for: match.range)
            let leadingWhitespaceCount = max(0, match.range(at: 1).length)
            let indentBase = CGFloat(leadingWhitespaceCount) * 6
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
            style.lineSpacing = 2
            style.firstLineHeadIndent = indentBase
            style.headIndent = indentBase + 20
            rendered.addAttribute(.paragraphStyle, value: style, range: lineRange)
        }

        // fenced code block：优先保证可见背景。按围栏行成对识别，并给中间正文区间加样式。
        let fenceRegex = try? NSRegularExpression(pattern: "^[ \\t]*```.*$", options: [.anchorsMatchLines])
        if let fenceRegex {
            let fenceMatches = fenceRegex.matches(in: rendered.string, options: [], range: fullRenderedRange)
            var i = 0
            while i + 1 < fenceMatches.count {
                let openLine = renderedString.lineRange(for: fenceMatches[i].range)
                let closeLine = renderedString.lineRange(for: fenceMatches[i + 1].range)
                let start = openLine.location + openLine.length
                let end = closeLine.location
                if end > start {
                    let codeRange = NSRange(location: start, length: end - start)
                    let blockFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                    rendered.addAttribute(.font, value: blockFont, range: codeRange)
                    rendered.addAttribute(
                        .backgroundColor,
                        value: NSColor.quaternaryLabelColor.withAlphaComponent(0.12),
                        range: codeRange
                    )

                    let codeParagraph = NSMutableParagraphStyle()
                    codeParagraph.lineBreakMode = .byClipping
                    codeParagraph.lineSpacing = 2
                    codeParagraph.firstLineHeadIndent = 8
                    codeParagraph.headIndent = 8
                    rendered.addAttribute(.paragraphStyle, value: codeParagraph, range: codeRange)
                }
                i += 2
            }
        }

        // 表格不希望在窄窗口里自动换行，否则竖线对齐会被破坏。
        if wrapLines {
            applyNoWrapForMarkdownTables(in: rendered)
        }

        // 表格竖线/分隔符对齐依赖等宽字体；只对表格块应用等宽字体即可。
        applyMonospaceFontForMarkdownTables(in: rendered)

        textView.textStorage?.setAttributedString(rendered)
    }

    private func formatMarkdownTables(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var out: [String] = []
        out.reserveCapacity(lines.count)

        func isWideScalar(_ scalar: UnicodeScalar) -> Bool {
            switch scalar.value {
            // CJK Unified Ideographs + Ext A
            case 0x3400...0x4DBF, 0x4E00...0x9FFF,
                // CJK Compatibility Ideographs
                0xF900...0xFAFF,
                // Hiragana / Katakana / Hangul
                0x3040...0x30FF, 0xAC00...0xD7AF,
                // CJK symbols & punctuation, full-width forms
                0x3000...0x303F, 0xFF01...0xFF60, 0xFFE0...0xFFE6:
                return true
            default:
                return false
            }
        }

        func displayWidth(_ text: String) -> Int {
            var width = 0
            for scalar in text.unicodeScalars {
                // 控制字符不计宽
                if CharacterSet.controlCharacters.contains(scalar) {
                    continue
                }
                width += isWideScalar(scalar) ? 2 : 1
            }
            return max(0, width)
        }

        func isFenceLine(_ line: String) -> Bool {
            line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }

        func isTableRowLine(_ line: String) -> Bool {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2 && trimmed.contains("|")
        }

        func isSeparatorLine(_ line: String) -> Bool {
            guard let re = Self.tableSeparatorRegex else { return false }
            let range = NSRange(location: 0, length: (line as NSString).length)
            return re.firstMatch(in: line, options: [], range: range) != nil
        }

        func leadingIndent(_ line: String) -> String {
            let prefix = line.prefix { $0 == " " || $0 == "\t" }
            return String(prefix)
        }

        func parseCells(_ line: String) -> [String] {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            var core = trimmed
            if core.hasPrefix("|") { core.removeFirst() }
            if core.hasSuffix("|") { core.removeLast() }
            let parts = core.split(separator: "|", omittingEmptySubsequences: false)
            return parts.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        }

        var inFence = false
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if isFenceLine(line) {
                inFence.toggle()
                out.append(line)
                i += 1
                continue
            }
            if inFence {
                out.append(line)
                i += 1
                continue
            }

            // 识别：表头行 + 分隔行 + 多行 body
            if i + 1 < lines.count, isTableRowLine(lines[i]), isSeparatorLine(lines[i + 1]) {
                let headerLine = lines[i]
                let indent = leadingIndent(headerLine)

                var block: [String] = [headerLine, lines[i + 1]]
                var j = i + 2
                while j < lines.count, isTableRowLine(lines[j]) {
                    block.append(lines[j])
                    j += 1
                }

                // 解析 header + body，计算列宽（按等宽字体近似使用字符数）
                let headerCells = parseCells(block[0])
                var bodyRows: [[String]] = []
                if block.count > 2 {
                    bodyRows = block.dropFirst(2).map { parseCells($0) }
                }
                let colCount = max(
                    headerCells.count,
                    bodyRows.map(\.count).max() ?? 0
                )

                var widths = Array(repeating: 1, count: colCount)
                func updateWidths(with row: [String]) {
                    for col in 0..<colCount {
                        let cell = col < row.count ? row[col] : ""
                        widths[col] = max(widths[col], displayWidth(cell))
                    }
                }
                updateWidths(with: headerCells)
                for r in bodyRows { updateWidths(with: r) }

                func formatRow(_ cells: [String], widths: [Int], indent: String) -> String {
                    let formattedCells: [String] = (0..<widths.count).map { col in
                        let cell = col < cells.count ? cells[col] : ""
                        let pad = max(0, widths[col] - displayWidth(cell))
                        return " " + cell + String(repeating: " ", count: pad) + " "
                    }
                    return indent + "|" + formattedCells.joined(separator: "|") + "|"
                }

                // separator 行：用统一长度的 --- 视觉对齐（简单版）
                func formatSeparator(widths: [Int], indent: String) -> String {
                    let parts: [String] = widths.map { w in
                        let dashCount = max(3, w)
                        return " " + String(repeating: "-", count: dashCount) + " "
                    }
                    return indent + "|" + parts.joined(separator: "|") + "|"
                }

                out.append(formatRow(headerCells, widths: widths, indent: indent))
                out.append(formatSeparator(widths: widths, indent: indent))
                if block.count > 2 {
                    for rowLine in block.dropFirst(2) {
                        let cells = parseCells(rowLine)
                        out.append(formatRow(cells, widths: widths, indent: indent))
                    }
                }

                i = j
                continue
            }

            out.append(line)
            i += 1
        }

        return out.joined(separator: "\n")
    }

    private func applyNoWrapForMarkdownTables(in rendered: NSMutableAttributedString) {
        // 用 line-by-line 扫描找表格行块，然后强制 those line 的 lineBreakMode = byClipping
        var inFence = false

        func isFenceLine(_ s: String) -> Bool {
            s.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }

        func isTableRowLine(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2 && trimmed.contains("|")
        }

        func isSeparatorLine(_ s: String) -> Bool {
            guard let re = Self.tableSeparatorRegex else { return false }
            let range = NSRange(location: 0, length: (s as NSString).length)
            return re.firstMatch(in: s, options: [], range: range) != nil
        }

        // 逐行分割并计算 offset，得到每一行在 attributedString 内的 NSRange。
        var lineRanges: [NSRange] = []
        var lineTexts: [String] = []
        lineRanges.reserveCapacity(64)
        lineTexts.reserveCapacity(64)
        var offset = 0
        let rawLines = rendered.string.components(separatedBy: "\n")
        for rawLine in rawLines {
            let length = (rawLine as NSString).length
            lineRanges.append(NSRange(location: offset, length: length))
            lineTexts.append(rawLine)
            offset += length + 1 // + '\n'
        }

        guard !lineTexts.isEmpty else { return }

        func updateLine(_ range: NSRange) {
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byClipping
            style.lineSpacing = 2
            rendered.addAttribute(.paragraphStyle, value: style, range: range)
        }

        var i = 0
        while i + 1 < lineTexts.count {
            let line = lineTexts[i]
            if isFenceLine(line) {
                inFence.toggle()
                i += 1
                continue
            }
            if inFence {
                i += 1
                continue
            }

            if isTableRowLine(line), isSeparatorLine(lineTexts[i + 1]) {
                // 找块结束
                var j = i + 2
                while j < lineTexts.count, isTableRowLine(lineTexts[j]) {
                    j += 1
                }
                // i ..< j 都是表格行：强制不换行
                for k in i..<j {
                    updateLine(lineRanges[k])
                }
                i = j
            } else {
                i += 1
            }
        }
    }

    private func applyMonospaceFontForMarkdownTables(in rendered: NSMutableAttributedString) {
        var inFence = false

        func isFenceLine(_ s: String) -> Bool {
            s.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("```")
        }

        func isTableRowLine(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            let pipeCount = trimmed.filter { $0 == "|" }.count
            return pipeCount >= 2 && trimmed.contains("|")
        }

        func isSeparatorLine(_ s: String) -> Bool {
            guard let re = Self.tableSeparatorRegex else { return false }
            let range = NSRange(location: 0, length: (s as NSString).length)
            return re.firstMatch(in: s, options: [], range: range) != nil
        }

        var offset = 0
        let rawLines = rendered.string.components(separatedBy: "\n")
        let monoFont = NSFont.monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

        var i = 0
        while i + 1 < rawLines.count {
            let line = rawLines[i]
            if isFenceLine(line) {
                inFence.toggle()
                offset += (line as NSString).length + 1
                i += 1
                continue
            }
            if inFence {
                offset += (line as NSString).length + 1
                i += 1
                continue
            }

            if isTableRowLine(line), isSeparatorLine(rawLines[i + 1]) {
                // 找表格块结束
                var j = i + 2
                while j < rawLines.count, isTableRowLine(rawLines[j]) {
                    j += 1
                }

                // i ..< j 都是表格行：应用等宽字体
                var lineOffset = offset
                for k in i..<j {
                    let lineText = rawLines[k]
                    let length = (lineText as NSString).length
                    let lineRange = NSRange(location: lineOffset, length: length)
                    rendered.addAttribute(.font, value: monoFont, range: lineRange)
                    lineOffset += length + 1
                }

                // 跳过已处理的块
                let lastLine = rawLines[j - 1]
                offset += ((lastLine as NSString).length + 1) * (j - i)
                i = j
                continue
            }

            offset += (line as NSString).length + 1
            i += 1
        }
    }

    private func applyScale(_ target: CGFloat, to textView: NSTextView, context: Context) {
        let clamped = min(max(target, 0.5), 3.0)
        let current = context.coordinator.currentScale
        guard abs(clamped - current) > 0.0001 else { return }
        let factor = clamped / max(current, 0.0001)
        textView.scaleUnitSquare(to: NSSize(width: factor, height: factor))
        context.coordinator.currentScale = clamped
    }

    final class Coordinator {
        weak var textView: NSTextView?
        var lastMarkdown: String = ""
        var currentScale: CGFloat = 1.0
    }
}

private struct TextFilePreview: NSViewRepresentable {
    let text: String
    let fileExtension: String
    let wrapLines: Bool
    let fontSize: CGFloat
    @Binding var action: TextPreviewAction?
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wrapLines
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.isRichText = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wrapLines
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.minSize = NSSize(width: 0, height: 0)
        if !wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
        textView.textStorage?.setAttributedString(TextSyntaxHighlighter.makePlainText(text: text, fontSize: fontSize))
        Self.applyWrapStyle(to: textView, wrapLines: wrapLines)
        
        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.lastWrapLines = wrapLines
        context.coordinator.applyHighlight(
            text: text,
            fileExtension: fileExtension,
            fontSize: fontSize,
            wrapLines: wrapLines,
            textView: textView
        )
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        if textView.string != text {
            textView.textStorage?.setAttributedString(TextSyntaxHighlighter.makePlainText(text: text, fontSize: fontSize))
            textView.scrollToBeginningOfDocument(nil)
        }
        if textView.font?.pointSize != fontSize {
            textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
        context.coordinator.applyHighlight(
            text: text,
            fileExtension: fileExtension,
            fontSize: fontSize,
            wrapLines: wrapLines,
            textView: textView
        )
        scrollView.hasHorizontalScroller = !wrapLines
        textView.textContainer?.widthTracksTextView = wrapLines
        textView.autoresizingMask = wrapLines ? [.width] : []
        textView.isHorizontallyResizable = !wrapLines
        if wrapLines {
            textView.textContainer?.containerSize = NSSize(
                width: scrollView.contentSize.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }

        if context.coordinator.lastWrapLines != wrapLines {
            context.coordinator.lastWrapLines = wrapLines
            Self.applyWrapStyle(to: textView, wrapLines: wrapLines)
            textView.scrollToBeginningOfDocument(nil)
            scrollView.contentView.scroll(to: NSPoint(x: 0, y: 0))
            if let textContainer = textView.textContainer {
                textView.layoutManager?.ensureLayout(for: textContainer)
            }
        }

        if let action {
            switch action {
            case .copyAll:
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(textView.string, forType: .string)
            case .scrollTop:
                textView.scrollToBeginningOfDocument(nil)
            case .scrollBottom:
                textView.scrollToEndOfDocument(nil)
            }
            DispatchQueue.main.async {
                self.action = nil
            }
        }
    }
    
    final class Coordinator {
        weak var textView: NSTextView?
        var lastWrapLines: Bool = true
        private var renderWorkItem: DispatchWorkItem?
        private var generation: UInt64 = 0

        deinit {
            renderWorkItem?.cancel()
        }

        func applyHighlight(
            text: String,
            fileExtension: String,
            fontSize: CGFloat,
            wrapLines: Bool,
            textView: NSTextView
        ) {
            generation &+= 1
            let currentGeneration = generation
            renderWorkItem?.cancel()
            let isDark = textView.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

            var workItem: DispatchWorkItem!
            workItem = DispatchWorkItem { [weak self] in
                guard !workItem.isCancelled else { return }
                let highlighted = TextSyntaxHighlighter.highlightedText(
                    text: text,
                    fileExtension: fileExtension,
                    fontSize: fontSize,
                    isDark: isDark
                )
                DispatchQueue.main.async {
                    guard !workItem.isCancelled else { return }
                    guard let self, currentGeneration == self.generation else { return }
                    guard textView.string == text else { return }
                    textView.textStorage?.setAttributedString(highlighted)
                    TextFilePreview.applyWrapStyle(to: textView, wrapLines: wrapLines)
                }
            }
            renderWorkItem = workItem
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
        }
    }

    private static func applyWrapStyle(to textView: NSTextView, wrapLines: Bool) {
        guard let storage = textView.textStorage, storage.length > 0 else { return }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = wrapLines ? .byWordWrapping : .byClipping
        storage.addAttribute(
            .paragraphStyle,
            value: style,
            range: NSRange(location: 0, length: storage.length)
        )
    }
}

private enum TextSyntaxHighlighter {
    private enum Language {
        case swift
        case javascript
        case python
        case json
        case shell
        case rust
        case vue
    }

    private struct Palette {
        let plain: NSColor
        let keyword: NSColor
        let string: NSColor
        let comment: NSColor
        let number: NSColor
        let key: NSColor
    }

    private static let cache = NSCache<NSString, NSAttributedString>()
    private static let maxHighlightCharacters = 18_000
    private static let maxHighlightLines = 1_200

    static func makePlainText(text: String, fontSize: CGFloat) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    static func highlightedText(
        text: String,
        fileExtension: String,
        fontSize: CGFloat,
        isDark: Bool
    ) -> NSAttributedString {
        guard shouldHighlight(text: text) else {
            return makePlainText(text: text, fontSize: fontSize)
        }
        guard let language = language(for: fileExtension) else {
            return makePlainText(text: text, fontSize: fontSize)
        }
        let key = cacheKey(text: text, fileExtension: fileExtension, fontSize: fontSize, isDark: isDark)
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        let palette = palette(isDark: isDark)
        let result = highlight(text: text, language: language, fontSize: fontSize, palette: palette)
        cache.setObject(result, forKey: key as NSString)
        return result
    }

    private static func shouldHighlight(text: String) -> Bool {
        if text.count > maxHighlightCharacters { return false }
        var lineCount = 1
        for scalar in text.unicodeScalars where scalar == "\n" {
            lineCount += 1
            if lineCount > maxHighlightLines { return false }
        }
        return true
    }

    private static func language(for ext: String) -> Language? {
        switch ext.lowercased() {
        case "swift":
            return .swift
        case "js", "jsx", "ts", "tsx":
            return .javascript
        case "py":
            return .python
        case "json":
            return .json
        case "sh", "bash", "zsh":
            return .shell
        case "rs":
            return .rust
        case "vue":
            return .vue
        default:
            return nil
        }
    }

    private static func palette(isDark: Bool) -> Palette {
        if isDark {
            return Palette(
                plain: NSColor(calibratedRed: 0.86, green: 0.88, blue: 0.91, alpha: 1),
                keyword: NSColor(calibratedRed: 0.49, green: 0.68, blue: 0.96, alpha: 1),
                string: NSColor(calibratedRed: 0.60, green: 0.85, blue: 0.64, alpha: 1),
                comment: NSColor(calibratedRed: 0.52, green: 0.59, blue: 0.65, alpha: 1),
                number: NSColor(calibratedRed: 0.95, green: 0.73, blue: 0.46, alpha: 1),
                key: NSColor(calibratedRed: 0.91, green: 0.60, blue: 0.78, alpha: 1)
            )
        }
        return Palette(
            plain: NSColor.labelColor,
            keyword: NSColor(calibratedRed: 0.07, green: 0.32, blue: 0.79, alpha: 1),
            string: NSColor(calibratedRed: 0.13, green: 0.53, blue: 0.17, alpha: 1),
            comment: NSColor(calibratedRed: 0.42, green: 0.47, blue: 0.52, alpha: 1),
            number: NSColor(calibratedRed: 0.75, green: 0.41, blue: 0.09, alpha: 1),
            key: NSColor(calibratedRed: 0.62, green: 0.24, blue: 0.54, alpha: 1)
        )
    }

    private static func highlight(text: String, language: Language, fontSize: CGFloat, palette: Palette) -> NSAttributedString {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: palette.plain
            ]
        )
        let fullRange = NSRange(location: 0, length: attributed.length)
        let protectedRanges = NSMutableArray()

        func apply(_ regex: NSRegularExpression, color: NSColor, protectedToken: Bool = false) {
            let matches = regex.matches(in: text, options: [], range: fullRange)
            for match in matches {
                if match.range.length == 0 { continue }
                if intersectsProtected(match.range, protectedRanges) { continue }
                attributed.addAttribute(.foregroundColor, value: color, range: match.range)
                if protectedToken {
                    protectedRanges.add(NSValue(range: match.range))
                }
            }
        }

        switch language {
        case .swift:
            apply(swiftCommentRegex, color: palette.comment, protectedToken: true)
            apply(swiftStringRegex, color: palette.string, protectedToken: true)
            apply(swiftKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .javascript:
            apply(jsCommentRegex, color: palette.comment, protectedToken: true)
            apply(jsStringRegex, color: palette.string, protectedToken: true)
            apply(jsKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .python:
            apply(pythonCommentRegex, color: palette.comment, protectedToken: true)
            apply(pythonStringRegex, color: palette.string, protectedToken: true)
            apply(pythonKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .json:
            apply(jsonStringRegex, color: palette.string, protectedToken: true)
            apply(jsonKeyRegex, color: palette.key)
            apply(jsonKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .shell:
            apply(shellCommentRegex, color: palette.comment, protectedToken: true)
            apply(shellStringRegex, color: palette.string, protectedToken: true)
            apply(shellKeywordRegex, color: palette.keyword)
            apply(shellVariableRegex, color: palette.number)
            apply(numberRegex, color: palette.number)
        case .rust:
            apply(rustCommentRegex, color: palette.comment, protectedToken: true)
            apply(rustStringRegex, color: palette.string, protectedToken: true)
            apply(rustKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        case .vue:
            apply(vueCommentRegex, color: palette.comment, protectedToken: true)
            apply(vueTagRegex, color: palette.key)
            apply(vueAttrRegex, color: palette.keyword)
            apply(vueStringRegex, color: palette.string, protectedToken: true)
            apply(jsKeywordRegex, color: palette.keyword)
            apply(numberRegex, color: palette.number)
        }

        return attributed
    }

    private static func intersectsProtected(_ range: NSRange, _ protectedRanges: NSMutableArray) -> Bool {
        for value in protectedRanges {
            guard let nsValue = value as? NSValue else { continue }
            if NSIntersectionRange(range, nsValue.rangeValue).length > 0 {
                return true
            }
        }
        return false
    }

    private static func cacheKey(text: String, fileExtension: String, fontSize: CGFloat, isDark: Bool) -> String {
        let digest = fnv1a64(text)
        return "\(fileExtension.lowercased())|\(Int(fontSize.rounded()))|\(isDark ? 1 : 0)|\(text.count)|\(digest)"
    }

    private static func fnv1a64(_ input: String) -> UInt64 {
        let prime: UInt64 = 1_099_511_628_211
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in input.utf8 {
            hash ^= UInt64(byte)
            hash &*= prime
        }
        return hash
    }

    private static let numberRegex = try! NSRegularExpression(pattern: #"(?<![\w.])\d+(?:\.\d+)?(?![\w.])"#)

    private static let swiftCommentRegex = try! NSRegularExpression(pattern: #"//.*|/\*[\s\S]*?\*/"#)
    private static let swiftStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*""#)
    private static let swiftKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:func|let|var|if|else|switch|case|for|while|guard|return|class|struct|enum|protocol|extension|import|private|fileprivate|internal|public|open|static|mutating|async|await|throw|throws|do|catch|in|where|nil|true|false)\b"#
    )

    private static let jsCommentRegex = try! NSRegularExpression(pattern: #"//.*|/\*[\s\S]*?\*/"#)
    private static let jsStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#)
    private static let jsKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:function|const|let|var|if|else|switch|case|for|while|return|class|extends|import|export|default|async|await|try|catch|throw|new|null|undefined|true|false)\b"#
    )

    private static let pythonCommentRegex = try! NSRegularExpression(pattern: #"(?m)#.*$"#)
    private static let pythonStringRegex = try! NSRegularExpression(pattern: #"'''[\s\S]*?'''|"""[\s\S]*?"""|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*""#)
    private static let pythonKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:def|class|if|elif|else|for|while|try|except|finally|return|import|from|as|with|lambda|yield|async|await|pass|break|continue|None|True|False)\b"#
    )

    private static let jsonStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*""#)
    private static let jsonKeyRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"(?=\s*:)"#)
    private static let jsonKeywordRegex = try! NSRegularExpression(pattern: #"\b(?:true|false|null)\b"#)

    private static let shellCommentRegex = try! NSRegularExpression(pattern: #"(?m)#.*$"#)
    private static let shellStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#)
    private static let shellKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:if|then|else|fi|for|in|do|done|case|esac|while|function|return|export|local)\b"#
    )
    private static let shellVariableRegex = try! NSRegularExpression(pattern: #"\$(?:[A-Za-z_]\w*|\{[^}]+\})"#)

    private static let rustCommentRegex = try! NSRegularExpression(pattern: #"//.*|/\*[\s\S]*?\*/"#)
    private static let rustStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'"#)
    private static let rustKeywordRegex = try! NSRegularExpression(
        pattern: #"\b(?:fn|let|mut|if|else|match|for|while|loop|return|struct|enum|impl|trait|use|mod|pub|crate|super|self|where|as|const|static|async|await|move|unsafe|dyn|ref|type|true|false|None|Some|Result|Option)\b"#
    )

    private static let vueCommentRegex = try! NSRegularExpression(pattern: #"<!--[\s\S]*?-->|//.*|/\*[\s\S]*?\*/"#)
    private static let vueTagRegex = try! NSRegularExpression(pattern: #"</?[A-Za-z][\w:-]*"#)
    private static let vueAttrRegex = try! NSRegularExpression(pattern: #"\s(?:v-[\w:-]+|:[\w:-]+|@[\w:-]+|[\w:-]+)(?=\=)"#)
    private static let vueStringRegex = try! NSRegularExpression(pattern: #""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`"#)
}

private struct ArchiveListPreview: View {
    let entries: [ArchiveEntryPreview]
    let truncated: Bool
    let expanded: Bool
    @Binding var copyAction: ArchivePreviewAction?

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()

    private var displayedEntries: [ArchiveEntryPreview] {
        if expanded { return entries }

        var map: [String: Bool] = [:] // name -> isDirectory
        for e in entries {
            let comps = e.path.split(separator: "/")
            guard let first = comps.first else { continue }
            let name = String(first)
            let isDirAtTop = e.isDirectory || comps.count > 1
            map[name] = (map[name] ?? false) || isDirAtTop
        }

        let dirs = map.keys.filter { map[$0] == true }.sorted()
        let files = map.keys.filter { map[$0] == false }.sorted()
        return dirs.map { ArchiveEntryPreview(path: $0, isDirectory: true, size: nil) }
            + files.map { ArchiveEntryPreview(path: $0, isDirectory: false, size: nil) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(displayedEntries) { entry in
                    let comps = entry.path.split(separator: "/")
                    let depth = expanded ? max(0, comps.count - 1) : 0

                    HStack(alignment: .top, spacing: 8) {
                        Color.clear.frame(width: CGFloat(depth) * 10)
                        Image(systemName: entry.isDirectory ? "folder" : "doc")
                            .foregroundColor(entry.isDirectory ? .accentColor : .secondary)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.path)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)

                            if let size = entry.size, !entry.isDirectory {
                                Text(Self.sizeFormatter.string(fromByteCount: size))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }

                if truncated && expanded {
                    Text("[Truncated...]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 10)
        }
        .onChange(of: copyAction) { action in
            guard let action else { return }
            switch action {
            case .copyList:
                let lines = displayedEntries.map { e in
                    if let size = e.size, !e.isDirectory {
                        return "\(e.path)\t\(Self.sizeFormatter.string(fromByteCount: size))"
                    }
                    return e.path
                }
                let text = lines.joined(separator: "\n")
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(text, forType: .string)
                DispatchQueue.main.async { copyAction = nil }
            }
        }
    }
}

private struct MediaPreview: NSViewRepresentable {
    let player: AVPlayer
    @Binding var controlAction: MediaControlAction?
    var onStateChanged: (_ isPlaying: Bool, _ isMuted: Bool) -> Void

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .floating
        onStateChanged(player.timeControlStatus == .playing, player.isMuted)
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }

        if let action = controlAction {
            switch action {
            case .togglePlayPause:
                if player.timeControlStatus == .playing {
                    player.pause()
                } else {
                    player.play()
                }
            case .toggleMute:
                player.isMuted.toggle()
            }
            DispatchQueue.main.async { controlAction = nil }
        }
        onStateChanged(player.timeControlStatus == .playing, player.isMuted)
    }
}

private struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    let reloadToken: Int
    let zoomScale: CGFloat
    let panMode: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> OfficePreviewHostView {
        let host = OfficePreviewHostView()
        guard let qlView = QLPreviewView(frame: .zero, style: .normal) else {
            return host
        }
        qlView.previewItem = url as NSURL
        host.embed(qlView)
        context.coordinator.hostView = host
        context.coordinator.lastReloadToken = reloadToken
        context.coordinator.lastAppliedZoomScale = -1
        context.coordinator.lastAppliedPanMode = panMode
        host.setZoomScale(zoomScale)
        context.coordinator.lastAppliedZoomScale = zoomScale
        host.setPanMode(panMode)
        return host
    }

    func updateNSView(_ host: OfficePreviewHostView, context: Context) {
        context.coordinator.hostView = host

        if context.coordinator.lastReloadToken != reloadToken {
            guard let qlView = host.qlPreviewView ?? makePreviewView() else { return }
            qlView.previewItem = nil
            qlView.previewItem = url as NSURL
            if host.qlPreviewView == nil {
                host.embed(qlView)
            }
            context.coordinator.lastReloadToken = reloadToken
            host.resetZoomState()
            context.coordinator.lastAppliedZoomScale = 1.0
        } else if let qlView = host.qlPreviewView {
            let currentURL = qlView.previewItem?.previewItemURL
            if currentURL?.path != url.path {
                qlView.previewItem = url as NSURL
                host.resetZoomState()
                context.coordinator.lastAppliedZoomScale = 1.0
            }
        } else if let qlView = makePreviewView() {
            host.embed(qlView)
        }

        if abs(context.coordinator.lastAppliedZoomScale - zoomScale) > 0.001 {
            host.setZoomScale(zoomScale)
            context.coordinator.lastAppliedZoomScale = zoomScale
        }

        if context.coordinator.lastAppliedPanMode != panMode {
            host.setPanMode(panMode)
            context.coordinator.lastAppliedPanMode = panMode
        }
    }

    private func makePreviewView() -> QLPreviewView? {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else { return nil }
        view.previewItem = url as NSURL
        return view
    }

    final class Coordinator {
        weak var hostView: OfficePreviewHostView?
        var lastReloadToken: Int = 0
        var lastAppliedZoomScale: CGFloat = 1.0
        var lastAppliedPanMode = false
    }
}

struct ImageResizeSheet: View {
    let aspectWidth: Int
    let aspectHeight: Int
    let onCancel: () -> Void
    let onApply: (Int, Int) -> Void

    @State private var widthText: String
    @State private var heightText: String
    @State private var maintainAspectRatio = true
    @State private var isSyncingFields = false

    init(
        initialWidth: Int,
        initialHeight: Int,
        aspectWidth: Int,
        aspectHeight: Int,
        onCancel: @escaping () -> Void,
        onApply: @escaping (Int, Int) -> Void
    ) {
        let safeWidth = max(1, initialWidth)
        let safeHeight = max(1, initialHeight)
        self.aspectWidth = max(1, aspectWidth)
        self.aspectHeight = max(1, aspectHeight)
        self.onCancel = onCancel
        self.onApply = onApply
        _widthText = State(initialValue: "\(safeWidth)")
        _heightText = State(initialValue: "\(safeHeight)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("调整图片尺寸")
                .font(.headline)

            Text("按像素设置输出尺寸。确认后需点击「保存编辑结果」写入文件。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("保持宽高比", isOn: $maintainAspectRatio)
                .toggleStyle(.checkbox)
                .onChange(of: maintainAspectRatio) { isLocked in
                    guard isLocked else { return }
                    syncHeightFromWidth()
                }

            HStack(spacing: 12) {
                dimensionField(title: "宽度", text: widthBinding)
                Text("×")
                    .foregroundStyle(.secondary)
                dimensionField(title: "高度", text: heightBinding)
            }

            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("取消", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("确定") {
                    guard let size = parsedSize else { return }
                    onApply(size.width, size.height)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(parsedSize == nil)
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private var widthBinding: Binding<String> {
        Binding(
            get: { widthText },
            set: { newValue in
                widthText = sanitizedDigits(from: newValue)
                if maintainAspectRatio {
                    syncHeightFromWidth()
                }
            }
        )
    }

    private var heightBinding: Binding<String> {
        Binding(
            get: { heightText },
            set: { newValue in
                heightText = sanitizedDigits(from: newValue)
                if maintainAspectRatio {
                    syncWidthFromHeight()
                }
            }
        )
    }

    private var parsedSize: (width: Int, height: Int)? {
        guard let width = Int(widthText), let height = Int(heightText) else { return nil }
        guard width > 0, height > 0, width <= 65_535, height <= 65_535 else { return nil }
        return (width, height)
    }

    private var validationMessage: String? {
        if widthText.isEmpty || heightText.isEmpty {
            return "请输入宽度和高度"
        }
        guard let width = Int(widthText), let height = Int(heightText) else {
            return "请输入有效的像素数值"
        }
        if width <= 0 || height <= 0 {
            return "宽度和高度必须大于 0"
        }
        if width > 65_535 || height > 65_535 {
            return "单边像素不能超过 65535"
        }
        return nil
    }

    @ViewBuilder
    private func dimensionField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 96)
                    .multilineTextAlignment(.trailing)
                Text("px")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func sanitizedDigits(from value: String) -> String {
        String(value.filter(\.isNumber))
    }

    private func syncHeightFromWidth() {
        guard !isSyncingFields else { return }
        guard let width = Int(widthText), width > 0, aspectWidth > 0 else { return }
        isSyncingFields = true
        let height = max(1, Int((Double(width) * Double(aspectHeight) / Double(aspectWidth)).rounded()))
        heightText = "\(height)"
        isSyncingFields = false
    }

    private func syncWidthFromHeight() {
        guard !isSyncingFields else { return }
        guard let height = Int(heightText), height > 0, aspectHeight > 0 else { return }
        isSyncingFields = true
        let width = max(1, Int((Double(height) * Double(aspectWidth) / Double(aspectHeight)).rounded()))
        widthText = "\(width)"
        isSyncingFields = false
    }
}

enum ImagePreviewSaveError: LocalizedError {
    case unableToEncode
    case unableToWrite

    var errorDescription: String? {
        switch self {
        case .unableToEncode:
            return "无法编码图片"
        case .unableToWrite:
            return "无法写入文件"
        }
    }
}

enum ImagePreviewTransformApplier {
    static func pixelSize(of image: NSImage) -> CGSize {
        if let rep = image.representations.first, rep.pixelsWide > 0, rep.pixelsHigh > 0 {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return CGSize(width: cgImage.width, height: cgImage.height)
        }
        return image.size
    }

    static func orientedPixelSize(of image: NSImage, rotationQuarterTurns: Int) -> CGSize {
        let source = pixelSize(of: image)
        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        if turns % 2 != 0 {
            return CGSize(width: source.height, height: source.width)
        }
        return source
    }

    static func apply(
        to image: NSImage,
        rotationQuarterTurns: Int,
        flipHorizontal: Bool,
        flipVertical: Bool
    ) -> NSImage? {
        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        guard turns != 0 || flipHorizontal || flipVertical else {
            return image.copy() as? NSImage ?? image
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let isSideways = turns % 2 != 0
        let outWidth = isSideways ? height : width
        let outHeight = isSideways ? width : height
        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let context = CGContext(
            data: nil,
            width: outWidth,
            height: outHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.translateBy(x: CGFloat(outWidth) / 2, y: CGFloat(outHeight) / 2)
        context.rotate(by: CGFloat(turns) * .pi / 2)
        context.scaleBy(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
        context.draw(
            cgImage,
            in: CGRect(
                x: -CGFloat(width) / 2,
                y: -CGFloat(height) / 2,
                width: CGFloat(width),
                height: CGFloat(height)
            )
        )

        guard let output = context.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: outWidth, height: outHeight))
    }

    static func resize(_ image: NSImage, to targetSize: CGSize) -> NSImage? {
        let width = Int(targetSize.width.rounded())
        let height = Int(targetSize.height.rounded())
        guard width > 0, height > 0,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let colorSpace = cgImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(
            cgImage,
            in: CGRect(x: 0, y: 0, width: width, height: height)
        )

        guard let output = context.makeImage() else { return nil }
        return NSImage(cgImage: output, size: NSSize(width: width, height: height))
    }

    static func write(_ image: NSImage, to url: URL) throws {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImagePreviewSaveError.unableToEncode
        }

        let ext = url.pathExtension.lowercased()

        if ext == "heic" || ext == "heif" {
            guard let destination = CGImageDestinationCreateWithURL(
                url as CFURL,
                UTType.heic.identifier as CFString,
                1,
                nil
            ) else {
                throw ImagePreviewSaveError.unableToEncode
            }
            CGImageDestinationAddImage(destination, cgImage, nil)
            guard CGImageDestinationFinalize(destination) else {
                throw ImagePreviewSaveError.unableToWrite
            }
            return
        }

        if ext == "webp",
           let destination = CGImageDestinationCreateWithURL(
               url as CFURL,
               UTType.webP.identifier as CFString,
               1,
               nil
           ) {
            CGImageDestinationAddImage(destination, cgImage, nil)
            if CGImageDestinationFinalize(destination) {
                return
            }
        }

        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw ImagePreviewSaveError.unableToEncode
        }

        let fileType: NSBitmapImageRep.FileType
        var properties: [NSBitmapImageRep.PropertyKey: Any] = [:]
        switch ext {
        case "jpg", "jpeg":
            fileType = .jpeg
            properties[.compressionFactor] = 0.92
        case "png":
            fileType = .png
        case "gif":
            fileType = .gif
        case "tiff", "tif":
            fileType = .tiff
        case "bmp":
            fileType = .bmp
        default:
            fileType = .png
        }

        guard let data = rep.representation(using: fileType, properties: properties) else {
            throw ImagePreviewSaveError.unableToEncode
        }
        try data.write(to: url, options: .atomic)
    }

    static func sampleWebColor(from image: NSImage, normalizedPoint: CGPoint) -> String? {
        guard normalizedPoint.x >= 0, normalizedPoint.x <= 1,
              normalizedPoint.y >= 0, normalizedPoint.y <= 1,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height
        let x = min(max(Int(normalizedPoint.x * CGFloat(width)), 0), max(width - 1, 0))
        let y = min(max(Int((1 - normalizedPoint.y) * CGFloat(height)), 0), max(height - 1, 0))

        let rep = NSBitmapImageRep(cgImage: cgImage)
        rep.size = NSSize(width: width, height: height)
        guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return nil }

        let red = Int(round(color.redComponent * 255))
        let green = Int(round(color.greenComponent * 255))
        let blue = Int(round(color.blueComponent * 255))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

private enum ImagePreviewContextActions {
    private static let previewBundleIdentifier = "com.apple.Preview"

    @MainActor
    static func openMarkup(for url: URL) {
        if let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: previewBundleIdentifier) {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.promptsUserIfNeeded = false
            NSWorkspace.shared.open([url], withApplicationAt: previewURL, configuration: configuration)
            return
        }
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func copyImage(from url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        if let image = NSImage(contentsOf: url) {
            pasteboard.writeObjects([image])
        } else {
            pasteboard.writeObjects([url as NSURL])
        }
    }

    @MainActor
    static func copyPath(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }

    @MainActor
    static func revealInFinder(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    @MainActor
    static func openWithDefaultApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    @MainActor
    static func setAsDesktopPicture(_ url: URL) {
        guard let screen = NSScreen.main else { return }
        do {
            try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:])
        } catch {
            let alert = NSAlert()
            alert.messageText = "无法设为桌面图片"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
        }
    }
}

private struct ImagePreviewContent: View {
    let image: NSImage
    let fileURL: URL
    @Binding var zoomScale: CGFloat
    @Binding var zoomAction: ImageZoomAction?
    @Binding var effectiveZoomPercent: Int
    @Binding var rotationQuarterTurns: Int
    @Binding var flipHorizontal: Bool
    @Binding var flipVertical: Bool
    @Binding var resizeTargetSize: CGSize?
    @Binding var eyedropperActive: Bool
    @Binding var pickedWebColor: String?
    
    @State private var panOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let rawImageSize = resolvedImageSize(image)
            let isRotatedSideways = rotationQuarterTurns % 2 != 0
            let orientedSize = isRotatedSideways
                ? CGSize(width: rawImageSize.height, height: rawImageSize.width)
                : rawImageSize
            let layoutImageSize = resizeTargetSize ?? orientedSize
            let resizeScaleX = layoutImageSize.width / max(orientedSize.width, 1)
            let resizeScaleY = layoutImageSize.height / max(orientedSize.height, 1)
            let fitScale = min(
                containerSize.width / max(layoutImageSize.width, 1),
                containerSize.height / max(layoutImageSize.height, 1)
            )
            let imageDisplaySize = CGSize(
                width: rawImageSize.width * fitScale * zoomScale * resizeScaleX,
                height: rawImageSize.height * fitScale * zoomScale * resizeScaleY
            )
            let layoutDisplaySize = CGSize(
                width: layoutImageSize.width * fitScale * zoomScale,
                height: layoutImageSize.height * fitScale * zoomScale
            )
            let currentOffset = clampedPanOffset(
                proposed: CGSize(
                    width: panOffset.width + dragTranslation.width,
                    height: panOffset.height + dragTranslation.height
                ),
                containerSize: containerSize,
                displaySize: layoutDisplaySize
            )
            
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaleEffect(x: flipHorizontal ? -1 : 1, y: flipVertical ? -1 : 1)
                    .rotationEffect(.degrees(Double(rotationQuarterTurns) * 90))
                    .frame(width: imageDisplaySize.width, height: imageDisplaySize.height)
                    .offset(x: currentOffset.width, y: currentOffset.height)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
            .contentShape(Rectangle())
            .contextMenu {
                imagePreviewContextMenu()
            }
            .onHover { isHovering in
                if eyedropperActive && isHovering {
                    NSCursor.crosshair.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(imageInteractionGesture(
                containerSize: containerSize,
                imageDisplaySize: imageDisplaySize,
                layoutDisplaySize: layoutDisplaySize
            ))
            .onAppear {
                let percent = Int((fitScale * zoomScale * 100).rounded())
                effectiveZoomPercent = max(1, min(percent, 1000))
            }
            .onChange(of: zoomScale) { _ in
                let percent = Int((fitScale * zoomScale * 100).rounded())
                effectiveZoomPercent = max(1, min(percent, 1000))
            }
            .onChange(of: resizeTargetSize) { _ in
                let percent = Int((fitScale * zoomScale * 100).rounded())
                effectiveZoomPercent = max(1, min(percent, 1000))
            }
            .onChange(of: zoomAction) { action in
                guard let action else { return }
                switch action {
                case .fit:
                    zoomScale = 1.0
                case .actualSize:
                    zoomScale = max(0.1, min(1.0 / max(fitScale, 0.0001), 5.0))
                }
                DispatchQueue.main.async { zoomAction = nil }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: zoomScale) { _ in
            panOffset = .zero
        }
        .onChange(of: rotationQuarterTurns) { _ in
            panOffset = .zero
        }
        .onChange(of: flipHorizontal) { _ in
            panOffset = .zero
        }
        .onChange(of: flipVertical) { _ in
            panOffset = .zero
        }
        .onChange(of: resizeTargetSize) { _ in
            panOffset = .zero
        }
    }

    @ViewBuilder
    private func imagePreviewContextMenu() -> some View {
        Button {
            ImagePreviewContextActions.openMarkup(for: fileURL)
        } label: {
            Label("标记…", systemImage: "pencil.tip.crop.circle")
        }

        Divider()

        Button {
            ImagePreviewContextActions.copyImage(from: fileURL)
        } label: {
            Label("复制图片", systemImage: "doc.on.doc")
        }

        Button {
            ImagePreviewContextActions.copyPath(fileURL)
        } label: {
            Label("复制路径", systemImage: "link")
        }

        Divider()

        Button {
            ImagePreviewContextActions.revealInFinder(fileURL)
        } label: {
            Label("在 Finder 中显示", systemImage: "folder")
        }

        Button {
            ImagePreviewContextActions.openWithDefaultApp(fileURL)
        } label: {
            Label("用默认应用打开", systemImage: "arrow.up.forward.app")
        }

        Divider()

        Button {
            ImagePreviewContextActions.setAsDesktopPicture(fileURL)
        } label: {
            Label("设为桌面图片", systemImage: "photo.on.rectangle.angled")
        }

        ShareLink(item: fileURL, preview: SharePreview(fileURL.lastPathComponent, image: Image(nsImage: image))) {
            Label("共享…", systemImage: "square.and.arrow.up")
        }
    }

    private func imageInteractionGesture(
        containerSize: CGSize,
        imageDisplaySize: CGSize,
        layoutDisplaySize: CGSize
    ) -> some Gesture {
        if eyedropperActive {
            return AnyGesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        pickWebColor(
                            at: value.location,
                            containerSize: containerSize,
                            imageDisplaySize: imageDisplaySize
                        )
                    }
            )
        }

        return AnyGesture(
            DragGesture(minimumDistance: 0)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    panOffset = clampedPanOffset(
                        proposed: CGSize(
                            width: panOffset.width + value.translation.width,
                            height: panOffset.height + value.translation.height
                        ),
                        containerSize: containerSize,
                        displaySize: layoutDisplaySize
                    )
                }
        )
    }

    private func pickWebColor(
        at location: CGPoint,
        containerSize: CGSize,
        imageDisplaySize: CGSize
    ) {
        guard let normalizedPoint = normalizedImagePoint(
            at: location,
            containerSize: containerSize,
            imageDisplaySize: imageDisplaySize
        ), let hex = ImagePreviewTransformApplier.sampleWebColor(
            from: image,
            normalizedPoint: normalizedPoint
        ) else {
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(hex, forType: .string)
        pickedWebColor = hex
    }

    private func normalizedImagePoint(
        at location: CGPoint,
        containerSize: CGSize,
        imageDisplaySize: CGSize
    ) -> CGPoint? {
        guard imageDisplaySize.width > 0, imageDisplaySize.height > 0 else { return nil }

        let centerX = containerSize.width / 2 + panOffset.width
        let centerY = containerSize.height / 2 + panOffset.height
        var point = CGPoint(x: location.x - centerX, y: location.y - centerY)

        let turns = ((rotationQuarterTurns % 4) + 4) % 4
        if turns != 0 {
            let radians = -Double(turns) * .pi / 2
            let cosValue = cos(radians)
            let sinValue = sin(radians)
            let rotatedX = point.x * cosValue - point.y * sinValue
            let rotatedY = point.x * sinValue + point.y * cosValue
            point = CGPoint(x: rotatedX, y: rotatedY)
        }

        if flipHorizontal { point.x *= -1 }
        if flipVertical { point.y *= -1 }

        let normalizedX = point.x / imageDisplaySize.width + 0.5
        let normalizedY = point.y / imageDisplaySize.height + 0.5
        guard normalizedX >= 0, normalizedX <= 1, normalizedY >= 0, normalizedY <= 1 else {
            return nil
        }
        return CGPoint(x: normalizedX, y: normalizedY)
    }
    
    private func clampedPanOffset(
        proposed: CGSize,
        containerSize: CGSize,
        displaySize: CGSize
    ) -> CGSize {
        let maxX = displaySize.width > containerSize.width
            ? (displaySize.width - containerSize.width) / 2
            : 0
        let maxY = displaySize.height > containerSize.height
            ? (displaySize.height - containerSize.height) / 2
            : 0
        
        return CGSize(
            width: min(max(proposed.width, -maxX), maxX),
            height: min(max(proposed.height, -maxY), maxY)
        )
    }
    
    private func resolvedImageSize(_ image: NSImage) -> CGSize {
        if image.size.width > 0, image.size.height > 0 {
            return image.size
        }
        if let rep = image.representations.first {
            return CGSize(width: max(rep.pixelsWide, 1), height: max(rep.pixelsHigh, 1))
        }
        return CGSize(width: 1, height: 1)
    }
}

struct PDFPreview: NSViewRepresentable {
    let document: PDFDocument
    @Binding var navigationAction: PDFNavigationAction?
    var onStateChanged: (_ currentPage: Int, _ pageCount: Int, _ scalePercent: Int) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onStateChanged: onStateChanged)
    }

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        context.coordinator.onStateChanged = onStateChanged
        context.coordinator.startObserving(pdfView)
        context.coordinator.emitState(from: pdfView)
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.onStateChanged = onStateChanged
        if nsView.document !== document {
            nsView.document = document
            nsView.autoScales = true
            context.coordinator.emitState(from: nsView)
        }

        if let action = navigationAction {
            switch action {
            case .previous:
                nsView.goToPreviousPage(nil)
            case .next:
                nsView.goToNextPage(nil)
            case .goToPage(let pageNumber):
                if let doc = nsView.document,
                   pageNumber >= 1,
                   pageNumber <= doc.pageCount,
                   let page = doc.page(at: pageNumber - 1) {
                    nsView.go(to: page)
                }
            case .zoomIn:
                nsView.autoScales = false
                nsView.scaleFactor = min(nsView.scaleFactor * 1.2, 5.0)
            case .zoomOut:
                nsView.autoScales = false
                nsView.scaleFactor = max(nsView.scaleFactor / 1.2, 0.25)
            case .fitWidth:
                nsView.autoScales = false
                context.coordinator.applyFitWidth(to: nsView)
            case .fitPage:
                nsView.autoScales = true
            }
            // PDFView 的 currentPage/scaleFactor 往往在动作后的下一帧才稳定，异步读取才能实时刷新标题栏状态。
            DispatchQueue.main.async {
                navigationAction = nil
                context.coordinator.emitState(from: nsView)
            }
        }
    }

    final class Coordinator: NSObject, PDFViewDelegate {
        var onStateChanged: (_ currentPage: Int, _ pageCount: Int, _ scalePercent: Int) -> Void
        private var pageChangedObserver: NSObjectProtocol?
        private var scaleChangedObserver: NSObjectProtocol?
        private weak var observedView: PDFView?

        init(onStateChanged: @escaping (_ currentPage: Int, _ pageCount: Int, _ scalePercent: Int) -> Void) {
            self.onStateChanged = onStateChanged
        }

        deinit {
            stopObserving()
        }

        func startObserving(_ pdfView: PDFView) {
            if observedView === pdfView { return }
            stopObserving()
            observedView = pdfView
            let center = NotificationCenter.default
            pageChangedObserver = center.addObserver(
                forName: .PDFViewPageChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] note in
                guard let view = note.object as? PDFView else { return }
                self?.emitState(from: view)
            }
            scaleChangedObserver = center.addObserver(
                forName: .PDFViewScaleChanged,
                object: pdfView,
                queue: .main
            ) { [weak self] note in
                guard let view = note.object as? PDFView else { return }
                self?.emitState(from: view)
            }
        }

        private func stopObserving() {
            let center = NotificationCenter.default
            if let pageChangedObserver { center.removeObserver(pageChangedObserver) }
            if let scaleChangedObserver { center.removeObserver(scaleChangedObserver) }
            pageChangedObserver = nil
            scaleChangedObserver = nil
            observedView = nil
        }

        func emitState(from pdfView: PDFView) {
            let pageCount = pdfView.document?.pageCount ?? 0
            let currentPage: Int
            if let current = pdfView.currentPage,
               let index = pdfView.document?.index(for: current) {
                currentPage = index + 1
            } else {
                currentPage = pageCount > 0 ? 1 : 0
            }
            let scalePercent = Int((pdfView.scaleFactor * 100).rounded())
            onStateChanged(currentPage, pageCount, scalePercent)
        }

        func applyFitWidth(to pdfView: PDFView) {
            guard let page = pdfView.currentPage else { return }
            let pageBounds = page.bounds(for: pdfView.displayBox)
            let availableWidth = max(pdfView.bounds.width - 24, 1)
            let targetScale = availableWidth / max(pageBounds.width, 1)
            pdfView.scaleFactor = max(0.25, min(targetScale, 5.0))
        }
    }
}

enum SortOrder: String, CaseIterable, Identifiable {
    case nameAscending = "Name (A to Z)"
    case nameDescending = "Name (Z to A)"
    case dateNewest = "Date (Newest First)"
    case dateOldest = "Date (Oldest First)"
    case sizeSmallest = "Size (Smallest First)"
    case sizeLargest = "Size (Largest First)"
    
    var id: String { rawValue }
}

enum FileItemFormatters {
    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static func formatSize(_ bytes: Int64) -> String {
        sizeFormatter.string(fromByteCount: bytes)
    }
    
    static func formatDate(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }
}

struct FileItem: Identifiable, Hashable {
    static let parentDirectoryID = "__parent_directory__"
    
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let modificationDate: Date
    let size: Int64
    let isHidden: Bool
    let fileType: String
    let sizeDisplay: String
    let dateDisplay: String
    
    var isParentDirectoryEntry: Bool {
        id == Self.parentDirectoryID
    }
    
    static func parentDirectoryEntry() -> FileItem {
        FileItem(
            id: parentDirectoryID,
            url: URL(fileURLWithPath: "/"),
            name: "..",
            isDirectory: true,
            modificationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "",
            sizeDisplay: "",
            dateDisplay: ""
        )
    }
    
    static func fileType(for name: String, isDirectory: Bool) -> String {
        if isDirectory {
            return "文件夹"
        }
        return (name as NSString).pathExtension
    }
    
    static func canNavigateUp(from path: String) -> Bool {
        parentDirectoryURL(from: path) != nil
    }
    
    static func parentDirectoryURL(from path: String) -> URL? {
        if TrashLoader.isTrashPath(path) {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent()
        guard parent.path != url.path else { return nil }
        return parent
    }
    
    /// 先用当前列表命中，再回查文件系统，保证树展开后选中的子目录文件可被预览/作用域识别。
    static func resolveSelection(
        ids: Set<String>,
        from knownItems: [FileItem]
    ) -> [FileItem] {
        guard !ids.isEmpty else { return [] }
        let knownByID = Dictionary(uniqueKeysWithValues: knownItems.map { ($0.id, $0) })
        var resolved: [FileItem] = []
        resolved.reserveCapacity(ids.count)
        
        for id in ids {
            if let known = knownByID[id] {
                resolved.append(known)
                continue
            }
            guard id != parentDirectoryID else { continue }
            if let lookedUp = itemFromFileSystem(path: id) {
                resolved.append(lookedUp)
            }
        }
        return resolved
    }
    
    private static func itemFromFileSystem(path: String) -> FileItem? {
        let standardized = (path as NSString).standardizingPath
        let url = URL(fileURLWithPath: standardized)
        let keys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
        ]
        
        do {
            let values = try url.resourceValues(forKeys: keys)
            guard let isDirectory = values.isDirectory else { return nil }
            let modificationDate = values.contentModificationDate ?? .distantPast
            let fileSize = Int64(values.fileSize ?? 0)
            let isHidden = values.isHidden ?? false
            let name = url.lastPathComponent
            let sizeDisplay = isDirectory ? "--" : FileItemFormatters.formatSize(fileSize)
            return FileItem(
                id: standardized,
                url: url,
                name: name,
                isDirectory: isDirectory,
                modificationDate: modificationDate,
                size: fileSize,
                isHidden: isHidden,
                fileType: fileType(for: name, isDirectory: isDirectory),
                sizeDisplay: sizeDisplay,
                dateDisplay: FileItemFormatters.formatDate(modificationDate)
            )
        } catch {
            return nil
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

struct FavoriteItem: Codable, Identifiable, Equatable {
    let path: String
    let name: String
    let icon: String
    
    var id: String { path }
}

@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    
    @Published private(set) var items: [FavoriteItem] = []
    
    private init() {
        load()
    }
    
    static func defaultItems() -> [FavoriteItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            FavoriteItem(path: home, name: "Home", icon: "house"),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Desktop"),
                name: "Desktop",
                icon: "desktopcomputer"
            ),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Documents"),
                name: "Documents",
                icon: "doc"
            ),
            FavoriteItem(
                path: (home as NSString).appendingPathComponent("Downloads"),
                name: "Downloads",
                icon: "arrow.down.circle"
            )
        ]
    }
    
    func contains(path: String) -> Bool {
        let normalized = (path as NSString).standardizingPath
        return items.contains { Self.pathsRepresentSameLocation($0.path, normalized) }
    }
    
    func addDirectory(at path: String, insertBefore: Int? = nil) {
        let normalized = (path as NSString).standardizingPath
        guard !contains(path: normalized) else { return }
        let name = (normalized as NSString).lastPathComponent
        let item = FavoriteItem(path: normalized, name: name, icon: "folder")
        if let insertBefore {
            let index = min(max(insertBefore, 0), items.count)
            items.insert(item, at: index)
        } else {
            items.append(item)
        }
        save()
    }
    
    func remove(path: String) {
        let normalized = (path as NSString).standardizingPath
        items.removeAll { Self.pathsRepresentSameLocation($0.path, normalized) }
        save()
    }
    
    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }
    
    func moveItem(withPath draggedPath: String, toInsertBefore insertIndex: Int) {
        let normalizedDragged = (draggedPath as NSString).standardizingPath
        guard let fromIndex = items.firstIndex(where: { Self.pathsRepresentSameLocation($0.path, normalizedDragged) }) else {
            return
        }
        
        var targetIndex = insertIndex
        if fromIndex < targetIndex {
            targetIndex -= 1
        }
        guard targetIndex != fromIndex else { return }
        
        let item = items.remove(at: fromIndex)
        let clampedIndex = max(0, min(targetIndex, items.count))
        items.insert(item, at: clampedIndex)
        save()
    }
    
    static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = (lhs as NSString).standardizingPath
        let normalizedRHS = (rhs as NSString).standardizingPath
        if normalizedLHS == normalizedRHS { return true }
        
        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }
    
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: AppSettings.favoritesKey),
              let decoded = try? JSONDecoder().decode([FavoriteItem].self, from: data) else {
            items = Self.defaultItems()
            return
        }
        items = decoded
    }
    
    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: AppSettings.favoritesKey)
    }
}

struct SidebarVolume: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let isExternal: Bool
    let canEject: Bool
    
    var icon: String {
        isExternal ? "externaldrive" : "internaldrive"
    }
}

enum FinderAutomationPermission {
    private static let finderBundleID = "com.apple.finder"
    
    @MainActor
    static func ensureAccess() async -> Bool {
        activateFinder()
        
        if hasAccess() {
            return true
        }
        
        if requestAccessPromptingUser() {
            return true
        }
        
        if await runProbeScript() {
            return true
        }
        
        showAccessDeniedAlert()
        return false
    }
    
    @MainActor
    private static func hasAccess() -> Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: finderBundleID)
        return AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            false
        ) == noErr
    }
    
    @MainActor
    private static func launchFinderIfNeeded() {
        if NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).isEmpty {
            let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            NSWorkspace.shared.openApplication(at: finderURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @MainActor
    private static func requestAccessPromptingUser() -> Bool {
        var status = determinePermission(promptUser: true)
        
        if status == procNotFound {
            launchFinderIfNeeded()
            Thread.sleep(forTimeInterval: 0.6)
            status = determinePermission(promptUser: true)
        }
        
        return status == noErr
    }
    
    @MainActor
    private static func determinePermission(promptUser: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: finderBundleID)
        return AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            promptUser
        )
    }
    
    @MainActor
    private static func activateFinder() {
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first {
            finder.activate(options: [.activateIgnoringOtherApps])
        } else {
            launchFinderIfNeeded()
        }
    }
    
    @MainActor
    private static func runProbeScript() async -> Bool {
        let scriptSource = """
        tell application "Finder"
            return name
        end tell
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: scriptSource) else { return false }
        _ = appleScript.executeAndReturnError(&error)
        return error == nil
    }
    
    @MainActor
    private static func showAccessDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "需要自动化权限"
        alert.informativeText = """
        MeoFind 需要「控制 Finder」的权限才能显示废纸篓内容。

        请在「系统设置 → 隐私与安全性 → 自动化」中，允许 MeoFind 控制 Finder。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openAutomationSettings()
        }
    }
    
    @MainActor
    private static func openAutomationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Automation"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}

enum TrashLoader {
    static let displayName = "废纸篓"
    
    static var userTrashPath: String {
        knownTrashDirectoryPaths().first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
    }
    
    static func canonicalTrashPath(_ path: String) -> String {
        var standardized = (path as NSString).standardizingPath
        if standardized.hasPrefix("/private") {
            standardized = String(standardized.dropFirst("/private".count))
        }
        return standardized
    }
    
    /// 用户废纸篓的候选路径（不依赖 fileExists，避免 TCC 导致无法识别废纸篓）。
    static func knownTrashDirectoryPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [String] = [
            FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first?.path,
            (home as NSString).appendingPathComponent(".Trash"),
            "/System/Volumes/Data\(home)/.Trash"
        ].compactMap { $0 }
        
        var paths: [String] = []
        var seen = Set<String>()
        for raw in candidates {
            let path = canonicalTrashPath(raw)
            guard seen.insert(path).inserted else { continue }
            paths.append(path)
        }
        return paths
    }
    
    static func resolvedTrashPaths() -> [String] {
        knownTrashDirectoryPaths().filter { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
    }
    
    static func isTrashPath(_ path: String) -> Bool {
        let normalized = canonicalTrashPath(path)
        if knownTrashDirectoryPaths().contains(where: { canonicalTrashPath($0) == normalized }) {
            return true
        }
        return trashDirectoryURLs().contains { canonicalTrashPath($0.path) == normalized }
    }
    
    static func trashDirectoryURLs() -> [URL] {
        var urls = knownTrashDirectoryPaths().map { URL(fileURLWithPath: $0, isDirectory: true) }
        var seenPaths = Set(urls.map { canonicalTrashPath($0.path) })
        
        let uid = getuid()
        guard let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) else {
            return urls
        }
        
        for volumeURL in volumeURLs {
            let trashURL = volumeURL.appendingPathComponent(".Trashes/\(uid)", isDirectory: true)
            let path = canonicalTrashPath(trashURL.path)
            guard seenPaths.insert(path).inserted else { continue }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: trashURL.path, isDirectory: &isDirectory),
               isDirectory.boolValue {
                urls.append(trashURL)
            }
        }
        
        return urls
    }
    
    static func loadItems(showHiddenFiles: Bool) async -> [FileItem] {
        var items = loadItemsFromFilesystem(showHiddenFiles: showHiddenFiles)
        if items.isEmpty {
            let finderPaths = await FinderTrashEnumerator.itemPaths()
            items = loadItems(fromPaths: finderPaths, showHiddenFiles: showHiddenFiles)
        }
        return items
    }
    
    private static func loadItemsFromFilesystem(showHiddenFiles: Bool) -> [FileItem] {
        let propertyKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
        ]
        var itemsByPath: [String: FileItem] = [:]
        
        let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles
            ? [.skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants]
        
        for trashURL in trashDirectoryURLs() {
            do {
                let urls = try FileManager.default.contentsOfDirectory(
                    at: trashURL,
                    includingPropertiesForKeys: Array(propertyKeys),
                    options: options
                )
                for fileURL in urls {
                    if fileURL.lastPathComponent == ".DS_Store" { continue }
                    guard let item = fileItem(from: fileURL, propertyKeys: propertyKeys) else { continue }
                    let key = canonicalTrashPath(item.id)
                    itemsByPath[key] = item
                }
            } catch {
                print("Error loading trash at \(trashURL.path): \(error)")
            }
        }
        
        return Array(itemsByPath.values)
    }
    
    private static func loadItems(fromPaths paths: [String], showHiddenFiles: Bool) -> [FileItem] {
        let propertyKeys: Set<URLResourceKey> = [
            .isDirectoryKey, .contentModificationDateKey, .fileSizeKey, .isHiddenKey
        ]
        var itemsByPath: [String: FileItem] = [:]
        
        for filePath in paths {
            let fileURL = URL(fileURLWithPath: filePath)
            guard let item = fileItem(from: fileURL, propertyKeys: propertyKeys) else { continue }
            if !showHiddenFiles && item.isHidden { continue }
            let key = canonicalTrashPath(item.id)
            itemsByPath[key] = item
        }
        
        return Array(itemsByPath.values)
    }
    
    static func fileItem(from fileURL: URL, propertyKeys: Set<URLResourceKey>) -> FileItem? {
        let resourceValues = try? fileURL.resourceValues(forKeys: propertyKeys)
        let isDirectory = resourceValues?.isDirectory ?? false
        let modDate = resourceValues?.contentModificationDate ?? Date.distantPast
        let size = Int64(resourceValues?.fileSize ?? 0)
        let isHidden = resourceValues?.isHidden ?? fileURL.lastPathComponent.hasPrefix(".")
        
        return FileItem(
            id: fileURL.path,
            url: fileURL,
            name: fileURL.lastPathComponent,
            isDirectory: isDirectory,
            modificationDate: modDate,
            size: size,
            isHidden: isHidden,
            fileType: FileItem.fileType(for: fileURL.lastPathComponent, isDirectory: isDirectory),
            sizeDisplay: isDirectory ? "--" : FileItemFormatters.formatSize(size),
            dateDisplay: FileItemFormatters.formatDate(modDate)
        )
    }
}

private enum FinderTrashEnumerator {
    static func itemPaths(timeout: TimeInterval = 20) async -> [String] {
        await withCheckedContinuation { continuation in
            final class ResumeGuard: @unchecked Sendable {
                private let lock = NSLock()
                private var resumed = false
                private let continuation: CheckedContinuation<[String], Never>
                
                init(continuation: CheckedContinuation<[String], Never>) {
                    self.continuation = continuation
                }
                
                func resumeOnce(_ paths: [String]) {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !resumed else { return }
                    resumed = true
                    continuation.resume(returning: paths)
                }
            }
            
            let resumeGuard = ResumeGuard(continuation: continuation)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            let script = """
            tell application "Finder"
                set output to ""
                repeat with anItem in trash
                    set output to output & (POSIX path of (anItem as alias)) & linefeed
                end repeat
                return output
            end tell
            """
            process.arguments = ["-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            process.terminationHandler = { _ in
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let text = String(data: data, encoding: .utf8) ?? ""
                let paths = text
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
                    .filter { !$0.isEmpty }
                resumeGuard.resumeOnce(paths)
            }
            
            do {
                try process.run()
            } catch {
                print("Finder trash osascript launch error: \(error)")
                resumeGuard.resumeOnce([])
                return
            }
            
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + timeout) {
                guard process.isRunning else { return }
                process.terminate()
            }
        }
    }
}

enum SidebarVolumeLoader {
    private static let propertyKeys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeLocalizedNameKey,
        .volumeIsInternalKey,
        .volumeIsBrowsableKey,
        .volumeIsEjectableKey,
        .volumeIsLocalKey
    ]
    
    static func load() -> [SidebarVolume] {
        guard let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(propertyKeys),
            options: [.skipHiddenVolumes]
        ) else { return [] }
        
        var volumes: [SidebarVolume] = []
        var seenPaths = Set<String>()
        
        for url in urls {
            guard let values = try? url.resourceValues(forKeys: propertyKeys) else { continue }
            guard values.volumeIsBrowsable ?? true else { continue }
            
            let name = values.volumeLocalizedName ?? values.volumeName ?? url.lastPathComponent
            guard !name.isEmpty else { continue }
            
            let volumePath = url.path
            let isInternal = values.volumeIsInternal ?? false
            let isExternal = volumePath.hasPrefix("/Volumes/")
            let isEjectable = values.volumeIsEjectable ?? false
            let isLocal = values.volumeIsLocal ?? true
            
            guard isMainInternalVolume(path: volumePath, isInternal: isInternal) || isExternal else {
                continue
            }
            
            guard !seenPaths.contains(volumePath) else { continue }
            seenPaths.insert(volumePath)
            
            volumes.append(SidebarVolume(
                id: volumePath,
                name: name,
                path: volumePath,
                isExternal: isExternal,
                canEject: isEjectable && isExternal && isLocal
            ))
        }
        
        return volumes.sorted { lhs, rhs in
            if lhs.isExternal != rhs.isExternal {
                return !lhs.isExternal
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
    
    private static func isMainInternalVolume(path: String, isInternal: Bool) -> Bool {
        isInternal && (path == "/" || path == "/System/Volumes/Data")
    }
}

private struct TrashRestoreRecord: Codable, Equatable {
    let trashedPath: String
    let originalDirectory: String
    let originalName: String
}

/// 记录通过本应用删除的文件原位置，用于「放回原处」。
private enum TrashRestoreStore {
    private static func normalized(_ path: String) -> String {
        (path as NSString).standardizingPath
    }
    
    private static func loadRecords() -> [TrashRestoreRecord] {
        guard let data = UserDefaults.standard.data(forKey: AppSettings.trashRestoreRecordsKey),
              let records = try? JSONDecoder().decode([TrashRestoreRecord].self, from: data) else {
            return []
        }
        return records
    }
    
    private static func saveRecords(_ records: [TrashRestoreRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: AppSettings.trashRestoreRecordsKey)
    }
    
    static func recordTrash(source: URL, resultingTrashedURL: URL?) {
        let trashedPath = normalized((resultingTrashedURL ?? defaultTrashedURL(for: source)).path)
        let record = TrashRestoreRecord(
            trashedPath: trashedPath,
            originalDirectory: source.deletingLastPathComponent().path,
            originalName: source.lastPathComponent
        )
        
        var records = loadRecords().filter { normalized($0.trashedPath) != trashedPath }
        records.append(record)
        saveRecords(records)
    }
    
    static func record(forTrashedPath path: String) -> TrashRestoreRecord? {
        let target = normalized(path)
        return loadRecords().first { normalized($0.trashedPath) == target }
    }
    
    static func canRestore(trashedPath: String) -> Bool {
        record(forTrashedPath: trashedPath) != nil
    }
    
    static func removeRecord(forTrashedPath path: String) {
        let target = normalized(path)
        let records = loadRecords().filter { normalized($0.trashedPath) != target }
        saveRecords(records)
    }
    
    static func removeAllRecords() {
        UserDefaults.standard.removeObject(forKey: AppSettings.trashRestoreRecordsKey)
    }
    
    private static func defaultTrashedURL(for source: URL) -> URL {
        let trashRoot = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash", isDirectory: true)
        return trashRoot.appendingPathComponent(source.lastPathComponent)
    }
}

enum FileOperations {
    private static let finderCopyPasteboardType = NSPasteboard.PasteboardType("com.apple.finder.copy")
    
    struct PasteboardState {
        let urls: [URL]
        let isCut: Bool
    }
    
    static func pasteboardState() -> PasteboardState {
        let pasteboard = NSPasteboard.general
        let urls = readFileURLs(from: pasteboard)
        let isCut = pasteboard.types?.contains(finderCopyPasteboardType) == true
        return PasteboardState(urls: urls, isCut: isCut)
    }
    
    static func pasteDestination(selectedItems: [FileItem], currentDirectoryPath: String) -> String {
        if selectedItems.count == 1,
           let item = selectedItems.first,
           item.isDirectory {
            return item.url.path
        }
        return currentDirectoryPath
    }
    
    static func canPaste(to destinationDirectory: URL) -> Bool {
        let state = pasteboardState()
        guard !state.urls.isEmpty else { return false }
        return canMoveItems(
            state.urls,
            to: destinationDirectory,
            allowSameDirectory: !state.isCut
        )
    }
    
    static func canMoveItems(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        allowSameDirectory: Bool = false
    ) -> Bool {
        let destURL = destinationDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        let destPath = destURL.path
        for sourceURL in sourceURLs {
            let srcURL = sourceURL.standardizedFileURL
            guard FileManager.default.fileExists(atPath: srcURL.path) else { return false }
            
            let srcPath = srcURL.path
            if srcPath == destPath { return false }
            if destPath.hasPrefix(srcPath + "/") { return false }
            if !allowSameDirectory,
               srcURL.deletingLastPathComponent().standardizedFileURL.path == destPath {
                return false
            }
        }
        return true
    }
    
    static func moveItems(
        _ sourceURLs: [URL],
        to destinationDirectory: URL,
        copy: Bool,
        completion: @escaping () -> Void
    ) {
        guard canMoveItems(sourceURLs, to: destinationDirectory) else { return }
        
        let fileManager = FileManager.default
        var hadError = false
        
        for sourceURL in sourceURLs {
            let destinationURL = uniqueDestinationURL(
                for: sourceURL.lastPathComponent,
                in: destinationDirectory
            )
            
            do {
                if copy {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                } else {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                }
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }
        
        if !hadError {
            completion()
        }
    }
    
    static func trashItems(_ sourceURLs: [URL], completion: @escaping () -> Void) {
        var hadError = false
        for sourceURL in sourceURLs {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: sourceURL, resultingItemURL: &resultingURL)
                TrashRestoreStore.recordTrash(
                    source: sourceURL,
                    resultingTrashedURL: resultingURL as URL?
                )
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }
        if !hadError {
            completion()
        }
    }
    
    static func emptyTrash(completion: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "清倒废纸篓？"
        alert.informativeText = "废纸篓中的所有项目将被永久删除，此操作无法撤销。"
        alert.alertStyle = .warning
        let emptyButton = alert.addButton(withTitle: "清倒废纸篓")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = emptyButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let script = """
        tell application "Finder"
            empty trash
        end tell
        """
        if runFinderAppleScript(script) {
            TrashRestoreStore.removeAllRecords()
            completion()
        }
    }
    
    static func putBack(_ items: [FileItem], completion: @escaping () -> Void) {
        guard !items.isEmpty else { return }
        
        var restoredCount = 0
        var failedItems: [FileItem] = []
        
        for item in items {
            if restoreItem(item) {
                restoredCount += 1
            } else {
                failedItems.append(item)
            }
        }
        
        if failedItems.isEmpty {
            completion()
            return
        }
        
        if restoredCount > 0 {
            completion()
        }
        
        let alert = NSAlert()
        if failedItems.count == 1 {
            alert.messageText = "无法放回原处"
            alert.informativeText = "「\(failedItems[0].name)」没有可用的原始位置记录，且 Finder 无法恢复此项目。"
        } else {
            alert.informativeText = "\(failedItems.count) 个项目无法放回原处。"
        }
        alert.alertStyle = .warning
        alert.runModal()
    }
    
    private static func restoreItem(_ item: FileItem) -> Bool {
        let escapedPath = appleScriptEscapedPath(item.url.path)
        let finderScript = """
        tell application "Finder"
            put (POSIX file "\(escapedPath)") back
        end tell
        """
        if runFinderAppleScript(finderScript, showError: false) {
            TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            return true
        }
        
        guard let record = TrashRestoreStore.record(forTrashedPath: item.url.path) else {
            return false
        }
        
        let destinationDirectory = URL(fileURLWithPath: record.originalDirectory, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destinationDirectory.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        let destinationURL = uniqueDestinationURL(for: record.originalName, in: destinationDirectory)
        do {
            try FileManager.default.moveItem(at: item.url, to: destinationURL)
            TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            return true
        } catch {
            NSAlert(error: error).runModal()
            return false
        }
    }
    
    static func deleteImmediately(_ items: [FileItem], completion: @escaping () -> Void) {
        guard !items.isEmpty else { return }
        
        let alert = NSAlert()
        if items.count == 1 {
            alert.messageText = "立刻删除「\(items[0].name)」？"
        } else {
            alert.messageText = "立刻删除 \(items.count) 个项目？"
        }
        alert.informativeText = "这些项目将被永久删除，无法恢复。"
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "立刻删除")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = deleteButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        for item in items {
            do {
                try FileManager.default.removeItem(at: item.url)
                TrashRestoreStore.removeRecord(forTrashedPath: item.url.path)
            } catch {
                NSAlert(error: error).runModal()
                return
            }
        }
        completion()
    }
    
    private static func runFinderAppleScript(_ source: String, showError: Bool = true) -> Bool {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return false }
        _ = script.executeAndReturnError(&error)
        
        if let error {
            guard showError else { return false }
            let message = error[NSAppleScript.errorMessage] as? String ?? "操作失败"
            let alert = NSAlert()
            alert.messageText = "操作失败"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
            return false
        }
        return true
    }
    
    private static func appleScriptEscapedPath(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    static func paste(to destinationDirectory: URL, completion: @escaping () -> Void) {
        let state = pasteboardState()
        guard canPaste(to: destinationDirectory) else { return }
        
        let fileManager = FileManager.default
        var hadError = false
        
        for sourceURL in state.urls {
            let destinationURL = uniqueDestinationURL(
                for: sourceURL.lastPathComponent,
                in: destinationDirectory
            )
            
            do {
                if state.isCut {
                    try fileManager.moveItem(at: sourceURL, to: destinationURL)
                } else {
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
            } catch {
                NSAlert(error: error).runModal()
                hadError = true
                break
            }
        }
        
        if state.isCut && !hadError {
            clearCutPasteboard()
        }
        if !hadError {
            completion()
        }
    }
    
    static func open(_ items: [FileItem], onNavigate: (String) -> Void) {
        guard let first = items.first else { return }
        func isAppBundle(_ item: FileItem) -> Bool {
            item.isDirectory && item.url.pathExtension.lowercased() == "app"
        }
        
        if items.count == 1 {
            if isAppBundle(first) {
                NSWorkspace.shared.open(first.url)
            } else if first.isDirectory {
                onNavigate(first.url.path)
            } else {
                NSWorkspace.shared.open(first.url)
            }
            return
        }
        
        for item in items where !item.isDirectory || isAppBundle(item) {
            NSWorkspace.shared.open(item.url)
        }
        if let directory = items.first(where: { $0.isDirectory && !isAppBundle($0) }) {
            onNavigate(directory.url.path)
        }
    }
    
    static func openWith(_ item: FileItem) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application, .applicationBundle]
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.message = "选择用于打开「\(item.name)」的应用"
        panel.prompt = "打开"
        
        guard panel.runModal() == .OK, let appURL = panel.url else { return }
        
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open([item.url], withApplicationAt: appURL, configuration: configuration)
    }

    static func openWithApplication(_ items: [FileItem], appURL: URL) {
        let urls = items.filter { !$0.isDirectory }.map(\.url)
        guard !urls.isEmpty else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration)
    }
    
    static func cut(_ items: [FileItem]) {
        let urls = items.map(\.url)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls as [NSURL])
        pasteboard.setPropertyList(
            urls.map(\.path),
            forType: finderCopyPasteboardType
        )
    }
    
    static func copy(_ items: [FileItem]) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(items.map(\.url) as [NSURL])
    }
    
    static func copyFilename(_ item: FileItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.name, forType: .string)
    }
    
    static func copyPaths(_ items: [FileItem]) {
        let paths = items.map(\.url.path).joined(separator: "\n")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths, forType: .string)
    }
    
    static func delete(_ items: [FileItem], completion: @escaping () -> Void) {
        let alert = NSAlert()
        if items.count == 1 {
            alert.messageText = "确认删除「\(items[0].name)」？"
        } else {
            alert.messageText = "确认删除 \(items.count) 个项目？"
        }
        alert.informativeText = "项目将移至废纸篓。"
        alert.alertStyle = .warning
        let deleteButton = alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = deleteButton
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        for item in items {
            do {
                var resultingURL: NSURL?
                try FileManager.default.trashItem(at: item.url, resultingItemURL: &resultingURL)
                TrashRestoreStore.recordTrash(
                    source: item.url,
                    resultingTrashedURL: resultingURL as URL?
                )
            } catch {
                NSAlert(error: error).runModal()
                return
            }
        }
        completion()
    }
    
    @discardableResult
    static func moveItem(_ item: FileItem, toNewName newName: String) -> Result<URL, Error> {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .failure(NSError(
                domain: NSCocoaErrorDomain,
                code: NSFileWriteInvalidFileNameError,
                userInfo: [NSLocalizedDescriptionKey: "名称不能为空"]
            ))
        }
        guard trimmed != item.name else {
            return .success(item.url)
        }
        
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            return .success(newURL)
        } catch {
            return .failure(error)
        }
    }
    
    static func showInfo(_ items: [FileItem]) {
        guard !items.isEmpty else { return }
        
        let alert = NSAlert()
        alert.alertStyle = .informational
        
        if items.count == 1, let item = items.first {
            alert.messageText = item.name
            alert.informativeText = buildInfoText(for: item)
        } else {
            alert.messageText = "已选择 \(items.count) 个项目"
            let preview = items.prefix(20).map { item in
                let kind = item.isDirectory ? "文件夹" : "文件"
                return "• \(item.name)（\(kind)，\(item.sizeDisplay)）"
            }.joined(separator: "\n")
            alert.informativeText = items.count > 20 ? preview + "\n…" : preview
        }
        
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    
    private static func buildInfoText(for item: FileItem) -> String {
        var lines: [String] = []
        
        if item.isDirectory {
            lines.append("种类：文件夹")
        } else if item.url.pathExtension.isEmpty {
            lines.append("种类：文件")
        } else {
            lines.append("种类：\(item.url.pathExtension.uppercased()) 文件")
        }
        
        lines.append("大小：\(item.sizeDisplay)")
        lines.append("位置：\(item.url.deletingLastPathComponent().path)")
        
        let keys: Set<URLResourceKey> = [
            .creationDateKey,
            .contentModificationDateKey,
            .isHiddenKey,
            .isReadableKey,
            .isWritableKey,
            .isExecutableKey,
            .typeIdentifierKey
        ]
        
        if let values = try? item.url.resourceValues(forKeys: keys) {
            if let created = values.creationDate {
                lines.append("创建时间：\(FileItemFormatters.formatDate(created))")
            }
            lines.append("修改时间：\(item.dateDisplay)")
            lines.append("隐藏：\(item.isHidden ? "是" : "否")")
            
            if let attributes = try? FileManager.default.attributesOfItem(atPath: item.url.path),
               let permissions = attributes[.posixPermissions] as? Int {
                lines.append(
                    "权限：\(posixPermissionString(permissions))（\(String(format: "%04o", permissions))）"
                )
            }
            
            var access: [String] = []
            if values.isReadable == true { access.append("可读") }
            if values.isWritable == true { access.append("可写") }
            if values.isExecutable == true { access.append("可执行") }
            if !access.isEmpty {
                lines.append("访问：\(access.joined(separator: "、"))")
            }
            
            if let typeIdentifier = values.typeIdentifier {
                lines.append("类型标识：\(typeIdentifier)")
            }
        }
        
        lines.append("路径：\(item.url.path)")
        return lines.joined(separator: "\n")
    }
    
    private static func posixPermissionString(_ permissions: Int) -> String {
        let mode = permissions & 0o777
        let symbols = ["r", "w", "x"]
        var result = ""
        for shift in stride(from: 6, through: 0, by: -3) {
            for (index, symbol) in symbols.enumerated() {
                let bit = 1 << (shift + (2 - index))
                result += (mode & bit) != 0 ? symbol : "-"
            }
        }
        return result
    }
    
    private static func readFileURLs(from pasteboard: NSPasteboard) -> [URL] {
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] else {
            return []
        }
        return objects.map(\.standardizedFileURL)
    }
    
    private static func uniqueDestinationURL(for name: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        
        let baseName = (name as NSString).deletingPathExtension
        let pathExtension = (name as NSString).pathExtension
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let newName: String
            if pathExtension.isEmpty {
                newName = "\(baseName) \(counter)"
            } else {
                newName = "\(baseName) \(counter).\(pathExtension)"
            }
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }
    
    private static func clearCutPasteboard() {
        NSPasteboard.general.clearContents()
    }
}

enum TerminalHelper {
    static func open(at directoryPath: String) {
        let standardizedPath = (directoryPath as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardizedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        
        // 使用 open 而非 AppleScript，无需「自动化」权限；
        // -n 在 Terminal 已运行时仍新建窗口，-a 指定应用。
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", "Terminal", standardizedPath]
        
        do {
            try process.run()
        } catch {
            print("Failed to open Terminal: \(error)")
        }
    }
}