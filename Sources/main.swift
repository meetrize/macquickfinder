import SwiftUI
import AppKit
import ApplicationServices
import PDFKit
import UniformTypeIdentifiers

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
    @ToolbarContentBuilder
    func hideSharedBackgroundIfAvailable() -> some ToolbarContent {
        if #available(macOS 26.0, *) {
            sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
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

private enum FileIconKind {
    case folder, generic, image, video, audio, document, pdf, code, json
    case archive, spreadsheet, presentation, application, package, shell, database, config

    var svgData: Data {
        switch self {
        case .folder: LucideSVG.folder
        case .generic: LucideSVG.file
        case .image: LucideSVG.fileImage
        case .video: LucideSVG.fileVideo
        case .audio: LucideSVG.fileAudio
        case .document: LucideSVG.fileText
        case .pdf: LucideSVG.fileType
        case .code: LucideSVG.fileCode
        case .json: LucideSVG.fileJson
        case .archive: LucideSVG.fileArchive
        case .spreadsheet: LucideSVG.fileSpreadsheet
        case .presentation: LucideSVG.presentation
        case .application: LucideSVG.appWindow
        case .package: LucideSVG.box
        case .shell: LucideSVG.terminal
        case .database: LucideSVG.database
        case .config: LucideSVG.settings
        }
    }

    var tint: Color {
        switch self {
        case .folder: .blue
        case .generic: .secondary
        case .image: Color(red: 0.2, green: 0.65, blue: 0.45)
        case .video: Color(red: 0.85, green: 0.25, blue: 0.35)
        case .audio: Color(red: 0.55, green: 0.35, blue: 0.85)
        case .document: .secondary
        case .pdf: Color(red: 0.9, green: 0.3, blue: 0.25)
        case .code: Color(red: 0.25, green: 0.55, blue: 0.9)
        case .json: Color(red: 0.85, green: 0.65, blue: 0.15)
        case .archive: Color(red: 0.6, green: 0.45, blue: 0.3)
        case .spreadsheet: Color(red: 0.2, green: 0.7, blue: 0.35)
        case .presentation: Color(red: 0.95, green: 0.5, blue: 0.15)
        case .application: Color(red: 0.3, green: 0.55, blue: 0.95)
        case .package: Color(red: 0.5, green: 0.5, blue: 0.55)
        case .shell: Color(red: 0.35, green: 0.35, blue: 0.4)
        case .database: Color(red: 0.3, green: 0.65, blue: 0.75)
        case .config: .secondary
        }
    }
}

private enum FileIconResolver {
    private static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "gif", "webp", "bmp", "tiff", "tif", "heic", "heif", "svg", "ico", "avif", "raw"
    ]
    private static let videoExtensions: Set<String> = [
        "mp4", "mov", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg", "3gp"
    ]
    private static let audioExtensions: Set<String> = [
        "mp3", "wav", "aiff", "aif", "flac", "m4a", "aac", "ogg", "wma", "opus", "caf"
    ]
    private static let documentExtensions: Set<String> = [
        "txt", "md", "markdown", "rtf", "doc", "docx", "pages", "odt", "tex"
    ]
    private static let codeExtensions: Set<String> = [
        "swift", "py", "js", "ts", "jsx", "tsx", "html", "htm", "css", "scss", "less",
        "xml", "yaml", "yml", "rb", "go", "rs", "java", "kt", "c", "cpp", "h", "hpp",
        "m", "mm", "php", "sql", "vue", "svelte", "r", "lua", "pl"
    ]
    private static let archiveExtensions: Set<String> = [
        "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "tgz", "dmg", "iso"
    ]
    private static let spreadsheetExtensions: Set<String> = [
        "xls", "xlsx", "numbers", "ods", "csv", "tsv"
    ]
    private static let presentationExtensions: Set<String> = [
        "ppt", "pptx", "key", "odp"
    ]
    private static let packageExtensions: Set<String> = [
        "bundle", "framework", "appex", "plugin", "kext"
    ]
    private static let shellExtensions: Set<String> = [
        "sh", "bash", "zsh", "command", "tool"
    ]
    private static let databaseExtensions: Set<String> = [
        "db", "sqlite", "sqlite3", "mdb"
    ]
    private static let configExtensions: Set<String> = [
        "plist", "env", "ini", "conf", "cfg", "toml", "properties"
    ]

    static func kind(for item: FileItem) -> FileIconKind {
        let ext = item.url.pathExtension.lowercased()

        if ext == "app" { return .application }
        if packageExtensions.contains(ext) { return .package }
        if item.isDirectory { return .folder }

        switch ext {
        case "pdf": return .pdf
        case "json", "jsonc": return .json
        case _ where imageExtensions.contains(ext): return .image
        case _ where videoExtensions.contains(ext): return .video
        case _ where audioExtensions.contains(ext): return .audio
        case _ where documentExtensions.contains(ext): return .document
        case _ where shellExtensions.contains(ext): return .shell
        case _ where codeExtensions.contains(ext): return .code
        case _ where archiveExtensions.contains(ext): return .archive
        case _ where spreadsheetExtensions.contains(ext): return .spreadsheet
        case _ where presentationExtensions.contains(ext): return .presentation
        case _ where databaseExtensions.contains(ext): return .database
        case _ where configExtensions.contains(ext): return .config
        default: return .generic
        }
    }
}

private struct FileItemIcon: View {
    let item: FileItem

    private var kind: FileIconKind {
        FileIconResolver.kind(for: item)
    }

    var body: some View {
        LucideIcon(svgData: kind.svgData)
            .foregroundStyle(kind.tint)
            .opacity(item.isHidden ? 0.6 : 1.0)
    }
}

@main
struct ExplorerApp: App {
    @State private var showPreview = true
    
    var body: some Scene {
        WindowGroup {
            ContentView(showPreview: $showPreview)
                .frame(minWidth: 800, minHeight: 600)
                .onAppear {
                    FileDragDebug.resetLogFile()
                    FileDragDebug.log("app launched logPath=\(FileDragDebug.logPath)")
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            FileCommands()
            CommandGroup(after: .sidebar) {
                Button(showPreview ? "关闭预览" : "显示预览") {
                    showPreview.toggle()
                }
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("通用", systemImage: "gearshape")
                }
            
            AdvancedSettingsTab()
                .tabItem {
                    Label("高级", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 480, height: 300)
    }
}

private struct GeneralSettingsTab: View {
    @AppStorage(AppSettings.blankDoubleClickActionKey)
    private var blankDoubleClickAction = BlankDoubleClickAction.navigateToParent.rawValue
    
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
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AdvancedSettingsTab: View {
    var body: some View {
        Form {
            Section {
                Text("暂无高级选项")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

enum BarTextFieldID: Hashable {
    case path
    case search
}

/// 记录各输入框对应的 NSTextField，供工具栏搜索栏等无法使用 SwiftUI FocusState 的场景聚焦。
private enum BarTextFieldFocusRegistry {
    private static weak var pathField: NSTextField?
    private static weak var searchField: NSTextField?
    
    static func register(_ field: NSTextField, for id: BarTextFieldID) {
        switch id {
        case .path: pathField = field
        case .search: searchField = field
        }
    }
    
    static func focus(_ id: BarTextFieldID) {
        let field: NSTextField?
        switch id {
        case .path: field = pathField
        case .search: field = searchField
        }
        guard let field, let window = field.window else { return }
        window.makeFirstResponder(field)
    }
    
    static func selectAll(_ id: BarTextFieldID) {
        guard let field = field(for: id), let window = field.window else { return }
        window.makeFirstResponder(field)
        if let editor = field.currentEditor() {
            editor.selectAll(nil)
        } else {
            field.selectText(nil)
        }
    }
    
    static func focusWhenReady(
        _ id: BarTextFieldID,
        selectAll: Bool = false,
        attempt: Int = 0
    ) {
        guard attempt < 12 else { return }
        guard let field = field(for: id), field.window != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) {
                focusWhenReady(id, selectAll: selectAll, attempt: attempt + 1)
            }
            return
        }
        focus(id)
        guard selectAll else { return }
        DispatchQueue.main.async {
            if let editor = field.currentEditor() {
                editor.selectAll(nil)
            } else {
                field.selectText(nil)
            }
        }
    }
    
    static func resign(_ id: BarTextFieldID) {
        guard let field = field(for: id), let window = field.window else { return }
        guard isFieldEditing(field) else { return }
        window.makeFirstResponder(nil)
    }
    
    static func isClickInside(_ id: BarTextFieldID, event: NSEvent) -> Bool {
        guard let field = field(for: id) else { return false }
        guard let window = field.window ?? event.window,
              let contentView = window.contentView else { return false }
        guard let hitView = contentView.hitTest(event.locationInWindow) else { return false }
        return hitView === field || hitView.isDescendant(of: field)
    }
    
    private static func field(for id: BarTextFieldID) -> NSTextField? {
        switch id {
        case .path: return pathField
        case .search: return searchField
        }
    }
    
    static func currentEditingField() -> BarTextFieldID? {
        if let searchField, isFieldEditing(searchField) { return .search }
        if let pathField, isFieldEditing(pathField) { return .path }
        return nil
    }
    
    private static func isFieldEditing(_ field: NSTextField) -> Bool {
        guard let window = field.window, let responder = window.firstResponder else { return false }
        if responder === field { return true }
        if let view = responder as? NSView, view.isDescendant(of: field) { return true }
        if let textView = responder as? NSTextView,
           let delegate = textView.delegate as AnyObject?,
           delegate === field {
            return true
        }
        return false
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
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.tableItems = tableItems
    }
    
    final class Coordinator {
        @Binding var activeField: BarTextFieldID?
        @Binding var isPathBarTextMode: Bool
        var tableItems: [FileItem]
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
            let editingField = BarTextFieldFocusRegistry.currentEditingField()
            let shouldDismissPathText = isPathBarTextMode
            guard editingField != nil || shouldDismissPathText else { return }
            
            if let editingField, BarTextFieldFocusRegistry.isClickInside(editingField, event: event) {
                return
            }
            
            if let editingField {
                BarTextFieldFocusRegistry.resign(editingField)
                if activeField == editingField {
                    activeField = nil
                }
            }
            
            if shouldDismissPathText {
                isPathBarTextMode = false
            }
            
            guard let tableView = tableView(at: event) else { return }
            guard let window = tableView.window ?? event.window else { return }
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
        context.coordinator.start()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.syncFromResponder()
    }
    
    final class Coordinator {
        @Binding var activeField: BarTextFieldID?
        private var monitor: Any?
        
        init(activeField: Binding<BarTextFieldID?>) {
            _activeField = activeField
        }
        
        func start() {
            guard monitor == nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .keyDown]) { [weak self] event in
                if event.type == .leftMouseDown {
                    self?.syncFromResponder()
                } else {
                    DispatchQueue.main.async {
                        self?.syncFromResponder()
                    }
                }
                return event
            }
        }
        
        fileprivate func syncFromResponder() {
            let current = BarTextFieldFocusRegistry.currentEditingField()
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(fieldID: fieldID, activeField: $activeField)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.attach(to: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.refreshEditingState()
    }
    
    final class Coordinator {
        let fieldID: BarTextFieldID
        @Binding var activeField: BarTextFieldID?
        private weak var anchorView: NSView?
        private weak var textField: NSTextField?
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
                    self?.activateField()
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
            activeField = BarTextFieldFocusRegistry.currentEditingField()
        }
        
        fileprivate func refreshEditingState() {
            guard textField != nil else { return }
            if BarTextFieldFocusRegistry.currentEditingField() == fieldID {
                activateField()
            } else {
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
                    BarTextFieldFocusRegistry.focus(fieldID)
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

private enum PanelTopBarMetrics {
    static let contentHeight: CGFloat = 28
    static let verticalPadding: CGFloat = 6
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
        
        Task.detached(priority: .utility) {
            for parentPath in parentPaths {
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
    var showHiddenFiles: Bool
    var onSubmit: () -> Void
    
    @State private var mode: PathBarMode = .breadcrumb
    @State private var editingText = ""
    @State private var committedViaSubmit = false
    @State private var previousActiveField: BarTextFieldID?
    
    private let cornerRadius: CGFloat = 7
    private let fieldHeight: CGFloat = 28
    
    private var showsFocusBorder: Bool {
        activeField == .path
    }
    
    private var borderColor: Color {
        showsFocusBorder ? Color.accentColor : Color(nsColor: .separatorColor)
    }
    
    private var displayPath: String {
        path
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            TextField("Path", text: $editingText)
                .textFieldStyle(.plain)
                .opacity(mode == .text ? 1 : 0)
                .allowsHitTesting(mode == .text)
                .frame(maxHeight: .infinity, alignment: .center)
                .onSubmit(commitPath)
                .background(
                    BarTextFieldFocusObserver(fieldID: .path, activeField: $activeField)
                )
            
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
        }
        .onChange(of: isTextMode) { active in
            guard !active, mode == .text else { return }
            editingText = displayPath
            committedViaSubmit = false
            mode = .breadcrumb
            BarTextFieldFocusRegistry.resign(.path)
            if activeField == .path {
                activeField = BarTextFieldFocusRegistry.currentEditingField()
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
            
            if oldValue == .path, mode == .text {
                if !committedViaSubmit {
                    editingText = displayPath
                }
                committedViaSubmit = false
                mode = .breadcrumb
            }
        }
    }
    
    private func enterTextMode() {
        editingText = path
        mode = .text
        DispatchQueue.main.async {
            BarTextFieldFocusRegistry.focusWhenReady(.path, selectAll: true)
        }
    }
    
    private func commitPath() {
        committedViaSubmit = true
        let newValue = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !newValue.isEmpty {
            if newValue == TrashLoader.displayName {
                path = TrashLoader.userTrashPath
            } else {
                path = newValue
            }
        }
        onSubmit()
        BarTextFieldFocusRegistry.resign(.path)
        activeField = BarTextFieldFocusRegistry.currentEditingField()
        mode = .breadcrumb
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
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
                
                HStack(spacing: 0) {
                    Color.clear
                        .frame(
                            width: metrics.isOverflowing
                                ? max(0, geometry.size.width - metrics.trailingClickWidth)
                                : min(geometry.size.width, metrics.contentWidth + clickGap)
                        )
                        .allowsHitTesting(false)
                    
                    Color.clear
                        .frame(width: metrics.trailingClickWidth, height: fieldHeight)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: onRequestEdit)
                        .help("点击编辑完整路径")
                }
                .frame(width: geometry.size.width, height: fieldHeight)
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
    @Binding var showPreview: Bool
    @AppStorage(AppSettings.blankDoubleClickActionKey)
    private var blankDoubleClickActionRaw = BlankDoubleClickAction.navigateToParent.rawValue
    @State private var path = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var items: [FileItem] = []
    @State private var selection: Set<FileItem.ID> = []
    @State private var sortOrder: SortOrder = .nameAscending
    @State private var tableSortOrder: [KeyPathComparator<FileItem>] = [
        KeyPathComparator(\.name, order: .forward)
    ]
    @State private var isSyncingSortFromTable = false
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showHiddenFiles = false
    @State private var loadGeneration: UInt = 0
    @State private var navigationBackStack: [String] = []
    @State private var isApplyingHistoryNavigation = false
    @State private var lastRecordedPath: String?
    @AppStorage(AppSettings.previewPanelWidthKey) private var storedPreviewPanelWidth = 320.0
    @State private var livePreviewPanelWidth: CGFloat = 320
    @State private var activeBarField: BarTextFieldID?
    @State private var isPathBarTextMode = false
    
    private var isTextFieldEditing: Bool {
        activeBarField != nil
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
    
    var body: some View {
        NavigationSplitView {
            SidebarView(path: $path, onItemsChanged: {
                selection.removeAll()
                loadItems()
            })
        } detail: {
            GeometryReader { geometry in
                let maxPreviewWidth = max(
                    minPreviewPanelWidth,
                    geometry.size.width - minMainPanelWidth
                )
                
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        PathBarView(
                            path: $path,
                            activeField: $activeBarField,
                            isTextMode: $isPathBarTextMode,
                            showHiddenFiles: showHiddenFiles,
                            onSubmit: loadItems
                        )
                        .frame(height: PanelTopBarMetrics.contentHeight)
                        .padding(.horizontal)
                        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
                        
                        Divider()
                        
                        if isLoading {
                            ProgressView()
                                .padding()
                        } else {
                            FileListView(
                                items: filteredItems,
                                selection: $selection,
                                tableSortOrder: $tableSortOrder,
                                searchText: searchText,
                                currentDirectoryPath: path,
                                canNavigateToParent: FileItem.canNavigateUp(from: path),
                                onItemOpen: openItem,
                                onBlankDoubleClick: handleBlankDoubleClick,
                                onItemsChanged: {
                                    selection.removeAll()
                                    loadItems()
                                },
                                contextActions: fileContextActions,
                                blankMenuActions: blankMenuActions
                            )
                            .focusedValue(\.fileCommandHandlers, fileCommandHandlers)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .focusedValue(\.textFieldEditing, isTextFieldEditing)
                    .background(TextEditingKeyMonitor(isBarFieldEditing: isTextFieldEditing))
                    .background(BarTextFieldFocusSync(activeField: $activeBarField))
                    .navigationTitle("Explorer")
                    .modifier(InlineToolbarTitleModifier())
                    .toolbar {
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
                        guard let field else { return }
                        BarTextFieldFocusRegistry.focus(field)
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
                    
                    if showPreview {
                        HorizontalResizeDivider(
                            trailingWidth: $livePreviewPanelWidth,
                            minTrailingWidth: minPreviewPanelWidth,
                            maxTrailingWidth: maxPreviewWidth,
                            onDragEnded: {
                                storedPreviewPanelWidth = Double(livePreviewPanelWidth)
                            }
                        )
                        .frame(width: 6)
                        .frame(maxHeight: .infinity)
                        
                        FilePreviewView(
                            showPreview: $showPreview,
                            selection: selection,
                            items: items
                        )
                        .frame(width: livePreviewPanelWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                    }
                }
                .animation(nil, value: livePreviewPanelWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    livePreviewPanelWidth = clampPreviewWidth(
                        CGFloat(storedPreviewPanelWidth),
                        maxWidth: maxPreviewWidth
                    )
                }
                .onChange(of: geometry.size.width) { newWidth in
                    let maxPreview = max(minPreviewPanelWidth, newWidth - minMainPanelWidth)
                    let clamped = clampPreviewWidth(livePreviewPanelWidth, maxWidth: maxPreview)
                    if clamped != livePreviewPanelWidth {
                        livePreviewPanelWidth = clamped
                        storedPreviewPanelWidth = Double(clamped)
                    }
                }
            }
        }
        .background(
            BarFieldOutsideClickHandler(
                activeField: $activeBarField,
                isPathBarTextMode: $isPathBarTextMode,
                tableItems: fileListTableItems
            )
        )
        .onAppear {
            lastRecordedPath = path
            loadItems()
        }
        .onChange(of: path) { newPath in
            if let oldPath = lastRecordedPath, oldPath != newPath, !isApplyingHistoryNavigation {
                navigationBackStack.append(oldPath)
            }
            lastRecordedPath = newPath
            loadItems()
        }
        .onChange(of: sortOrder) { newOrder in
            items.sort(by: newOrder.comparator)
            guard !isSyncingSortFromTable else { return }
            let newPath = FileListView.sortingKeyPath(for: newOrder)
            if !FileListView.pathsProduceSameSortOrder(tableSortOrder, newPath) {
                tableSortOrder = newPath
            }
        }
        .onChange(of: tableSortOrder) { newPath in
            guard let mapped = FileListView.sortOrder(from: newPath) else {
                items.sort(using: newPath)
                return
            }
            items.sort(by: mapped.comparator)
            guard mapped != sortOrder else { return }
            isSyncingSortFromTable = true
            sortOrder = mapped
            isSyncingSortFromTable = false
        }
    }
    
    private var filteredItems: [FileItem] {
        if searchText.isEmpty {
            return items
        }
        return items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private func clampPreviewWidth(_ width: CGFloat, maxWidth: CGFloat) -> CGFloat {
        min(max(width, minPreviewPanelWidth), max(maxWidth, minPreviewPanelWidth))
    }
    
    private func loadItems() {
        loadGeneration += 1
        let currentGeneration = loadGeneration
        isLoading = true
        selection.removeAll()
        
        let currentPath = path
        let shouldShowHiddenFiles = showHiddenFiles
        let currentSortOrder = sortOrder
        
        Task {
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
            
            let sorted = loadedItems.sorted(by: currentSortOrder.comparator)
            
            await MainActor.run {
                guard currentGeneration == loadGeneration else { return }
                items = sorted
                isLoading = false
            }
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
                FileOperations.delete(selected) {
                    selection.removeAll()
                    loadItems()
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
            }
        )
    }
    
    private var fileContextActions: FileContextActions {
        FileContextActions(
            open: { FileOperations.open([$0]) { path = $0 } },
            openWith: FileOperations.openWith,
            cut: FileOperations.cut,
            copy: FileOperations.copy,
            copyFilename: FileOperations.copyFilename,
            copyPaths: FileOperations.copyPaths,
            delete: { items in
                FileOperations.delete(items) {
                    selection.removeAll()
                    loadItems()
                }
            },
            rename: { item in
                FileOperations.rename(item) {
                    selection.removeAll()
                    loadItems()
                }
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
                FileOperations.deleteImmediately(items) {
                    selection.removeAll()
                    loadItems()
                }
            },
            openTerminal: { item in
                let directoryPath = item.isDirectory
                    ? item.url.path
                    : item.url.deletingLastPathComponent().path
                TerminalHelper.open(at: directoryPath)
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

struct SidebarView: View {
    @Binding var path: String
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @State private var devices: [SidebarVolume] = []
    var onItemsChanged: () -> Void = {}
    
    var body: some View {
        List {
            Section("Favorites") {
                ForEach(favoritesStore.items) { location in
                    SidebarRow(
                        title: location.name,
                        icon: location.icon,
                        isSelected: isSelected(location.path),
                        dropDestinationPath: location.path,
                        onDropURLs: handleSidebarDrop
                    ) {
                        path = location.path
                    }
                    .contextMenu {
                        Button("取消收藏", role: .destructive) {
                            favoritesStore.remove(path: location.path)
                        }
                    }
                }
            }
            
            Section("Devices") {
                if devices.isEmpty {
                    Text("No devices")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(devices) { device in
                        SidebarRow(
                            title: device.name,
                            icon: device.icon,
                            isSelected: isSelected(device.path),
                            dropDestinationPath: device.path,
                            onDropURLs: handleSidebarDrop
                        ) {
                            path = device.path
                        }
                    }
                }
            }
            
            Section("位置") {
                SidebarRow(
                    title: "废纸篓",
                    icon: "trash",
                    isSelected: isSelected(trashPath),
                    dropDestinationPath: trashPath,
                    onDropURLs: handleSidebarDrop
                ) {
                    path = trashPath
                }
            }
        }
        .listStyle(.sidebar)
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
        return Self.pathsRepresentSameLocation(path, sidebarPath)
    }
    
    private static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = (lhs as NSString).standardizingPath
        let normalizedRHS = (rhs as NSString).standardizingPath
        if normalizedLHS == normalizedRHS { return true }
        
        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
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
    let action: () -> Void
    
    @State private var isDropTargeted = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                Spacer(minLength: 0)
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
        }
        .buttonStyle(.plain)
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

private struct HighlightedText: View {
    let text: String
    let searchText: String
    var fontWeight: Font.Weight = .regular
    var opacity: Double = 1.0
    
    var body: some View {
        Text(attributedText)
            .fontWeight(fontWeight)
            .opacity(opacity)
    }
    
    private var attributedText: AttributedString {
        guard !searchText.isEmpty else {
            return AttributedString(text)
        }
        
        var result = AttributedString(text)
        var searchStart = text.startIndex
        
        while searchStart < text.endIndex {
            guard let range = text.range(
                of: searchText,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: searchStart..<text.endIndex,
                locale: .current
            ) else { break }
            
            if let attrRange = Range(range, in: result) {
                result[attrRange].backgroundColor = .yellow.opacity(0.45)
            }
            searchStart = range.upperBound
        }
        
        return result
    }
}

struct FileContextActions {
    var open: (FileItem) -> Void = { _ in }
    var openWith: (FileItem) -> Void = { _ in }
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
}

struct FileListBlankMenuActions {
    var isEnabled = true
    var canGoBack = false
    var goBack: () -> Void = {}
    var canGoUp = false
    var goUp: () -> Void = {}
    var canPaste = false
    var paste: () -> Void = {}
    var newFolder: () -> Void = {}
    var newFile: () -> Void = {}
    var openTerminal: () -> Void = {}
    var isInTrash = false
    var emptyTrash: () -> Void = {}
}

private enum FileListTableMetrics {
    static let blankColumnWidth: CGFloat = 30
    
    static func isBlankColumnClick(in tableView: NSTableView, column: Int) -> Bool {
        guard column >= 0 else { return false }
        return column == tableView.numberOfColumns - 1
    }
    
    static func isBlankAreaClick(in tableView: NSTableView, at point: NSPoint) -> Bool {
        if tableView.row(at: point) < 0 { return true }
        return isBlankColumnClick(in: tableView, column: tableView.column(at: point))
    }
}

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    @Binding var tableSortOrder: [KeyPathComparator<FileItem>]
    let searchText: String
    let currentDirectoryPath: String
    let canNavigateToParent: Bool
    let onItemOpen: (FileItem) -> Void
    let onBlankDoubleClick: () -> Void
    let onItemsChanged: () -> Void
    let contextActions: FileContextActions
    let blankMenuActions: FileListBlankMenuActions
    
    @State private var isCurrentDirectoryDropTargeted = false
    @State private var folderDropTargetID: FileItem.ID?
    
    private var showParentDirectoryRow: Bool {
        canNavigateToParent && searchText.isEmpty
    }
    
    private var tableRowItems: [FileItem] {
        guard showParentDirectoryRow else { return items }
        return [FileItem.parentDirectoryEntry()] + items
    }
    
    private var parentDirectoryURL: URL? {
        FileItem.parentDirectoryURL(from: currentDirectoryPath)
    }
    
    var body: some View {
        Table(tableRowItems, selection: $selection, sortOrder: preservedTableSortOrder) {
            TableColumn("Name", value: \.name) { (item: FileItem) in
                fileRowCell(for: item) {
                    HStack(spacing: 6) {
                        if item.isParentDirectoryEntry {
                            LucideIcon.folderUp
                                .foregroundStyle(FileIconKind.folder.tint)
                        } else {
                            FileItemIcon(item: item)
                        }
                        if item.isParentDirectoryEntry {
                            Text("..")
                                .fontWeight(.medium)
                        } else {
                            HighlightedText(
                                text: item.name,
                                searchText: searchText,
                                fontWeight: item.isDirectory ? .medium : .regular,
                                opacity: item.isHidden ? 0.6 : 1.0
                            )
                        }
                    }
                    .overlay {
                        if !item.isParentDirectoryEntry {
                            FileDragZoneAnchor(item: item)
                        }
                    }
                }
            }
            .width(min: 220, ideal: 300)
            
            TableColumn("Size", value: \.size) { (item: FileItem) in
                fileRowCell(for: item) {
                    if item.isParentDirectoryEntry {
                        Text("")
                    } else {
                        Text(item.sizeDisplay)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Date Modified", value: \.modificationDate) { (item: FileItem) in
                fileRowCell(for: item) {
                    if item.isParentDirectoryEntry {
                        Text("")
                    } else {
                        Text(item.dateDisplay)
                    }
                }
            }
            .width(min: 150, ideal: 180)
            
            TableColumn("") { (_: FileItem) in
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .width(min: FileListTableMetrics.blankColumnWidth, ideal: FileListTableMetrics.blankColumnWidth, max: FileListTableMetrics.blankColumnWidth)
        }
        .background(TableDoubleClickHandler(
            items: tableRowItems,
            onOpen: onItemOpen,
            onBlankDoubleClick: onBlankDoubleClick
        ))
        .background(TableDeleteKeyHandler(
            isEnabled: !selection.isEmpty && !selection.contains(FileItem.parentDirectoryID),
            onDelete: {
                let deletable = items(for: selection).filter { !$0.isParentDirectoryEntry }
                contextActions.delete(deletable)
            }
        ))
        .background(TableFileDragDropHandler(
            items: tableRowItems,
            selection: selection,
            onItemOpen: onItemOpen,
            onDragEnded: onItemsChanged
        ))
        .background(TableBlankContextMenuHandler(actions: blankMenuActions))
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            let selected = items(for: ids)
            let fileSelection = selected.filter { !$0.isParentDirectoryEntry }
            let inTrash = contextActions.isInTrash
            
            if selected.count == 1, let item = selected.first, item.isParentDirectoryEntry {
                Button("打开") {
                    onItemOpen(item)
                }
            } else if selected.isEmpty {
                blankAreaContextMenu(inTrash: inTrash)
            }
            
            if inTrash && !selected.isEmpty {
                if selected.count == 1, let item = selected.first {
                    Button("打开") {
                        contextActions.open(item)
                    }
                } else {
                    Button("打开") {
                        for item in selected {
                            contextActions.open(item)
                        }
                    }
                }
                
                Divider()
                
                Button("放回原处") {
                    contextActions.putBack(selected)
                }
                Button("立刻删除", role: .destructive) {
                    contextActions.deleteImmediately(selected)
                }
                
                Divider()
                
                Button("清倒废纸篓", role: .destructive) {
                    contextActions.emptyTrash()
                }
            } else if !fileSelection.isEmpty {
            let destination = FileOperations.pasteDestination(
                selectedItems: fileSelection,
                currentDirectoryPath: currentDirectoryPath
            )
            let showPaste = contextActions.canPaste(destination)
            
            if showPaste {
                Button("粘贴") {
                    contextActions.paste(destination)
                }
            }
            
                if showPaste {
                    Divider()
                }
                
                if fileSelection.count == 1, let item = fileSelection.first {
                    Button("打开") {
                        contextActions.open(item)
                    }
                    
                    if !item.isDirectory {
                        Button("打开方式…") {
                            contextActions.openWith(item)
                        }
                    }
                    
                    if item.isDirectory, !contextActions.isFavorited(item) {
                        Button("收藏") {
                            contextActions.addToFavorites(item)
                        }
                    }
                    
                    Divider()
                } else {
                    Button("打开") {
                        for item in fileSelection {
                            contextActions.open(item)
                        }
                    }
                    Divider()
                }
                
                Button("剪切") {
                    contextActions.cut(fileSelection)
                }
                Button("复制") {
                    contextActions.copy(fileSelection)
                }
                
                Divider()
                
                if fileSelection.count == 1, let item = fileSelection.first {
                    Button("复制文件名") {
                        contextActions.copyFilename(item)
                    }
                }
                Button("复制完整路径") {
                    contextActions.copyPaths(fileSelection)
                }
                
                Divider()
                
                Button("删除", role: .destructive) {
                    contextActions.delete(fileSelection)
                }
                
                if fileSelection.count == 1, let item = fileSelection.first {
                    Button("重命名") {
                        contextActions.rename(item)
                    }
                }
                
                Divider()
                
                if fileSelection.count == 1, let item = fileSelection.first {
                    Button("在此处打开终端") {
                        contextActions.openTerminal(item)
                    }
                }
                
                Button("属性") {
                    contextActions.showInfo(fileSelection)
                }
            }
        } primaryAction: { ids in
            guard let item = items(for: ids).first else { return }
            if item.isParentDirectoryEntry {
                onItemOpen(item)
            } else {
                contextActions.open(item)
            }
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .tableStyle(.inset)
        .onDrop(
            of: [.fileURL],
            delegate: FileDropDelegate(isTargeted: $isCurrentDirectoryDropTargeted) { urls, copy in
                handleDrop(
                    into: URL(fileURLWithPath: currentDirectoryPath, isDirectory: true),
                    urls: urls,
                    copy: copy
                )
            }
        )
        .overlay {
            if isCurrentDirectoryDropTargeted {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.6), lineWidth: 2)
                    .padding(4)
                    .allowsHitTesting(false)
            }
        }
    }
    
    private var preservedTableSortOrder: Binding<[KeyPathComparator<FileItem>]> {
        Binding(
            get: { [] },
            set: { newValue in
                tableSortOrder = newValue
            }
        )
    }
    
    @ViewBuilder
    private func fileRowCell<Content: View>(
        for item: FileItem,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isDropTarget = folderDropTargetID == item.id
        
        let row = content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isDropTarget ? Color.accentColor.opacity(0.18) : Color.clear)
            )
        
        if let destination = dropDestination(for: item) {
            row.onDrop(
                of: [.fileURL],
                delegate: FileDropDelegate(
                    isTargeted: Binding(
                        get: { folderDropTargetID == item.id },
                        set: { isTargeted in
                            folderDropTargetID = isTargeted ? item.id : nil
                        }
                    )
                ) { urls, copy in
                    handleDrop(into: destination, urls: urls, copy: copy)
                }
            )
        } else {
            row
        }
    }
    
    private func dropDestination(for item: FileItem) -> URL? {
        if item.isParentDirectoryEntry {
            return parentDirectoryURL
        }
        if item.isDirectory {
            return item.url
        }
        return nil
    }
    
    private func handleDrop(into destination: URL, urls: [URL], copy: Bool) {
        guard FileOperations.canMoveItems(urls, to: destination) else { return }
        FileOperations.moveItems(urls, to: destination, copy: copy, completion: onItemsChanged)
    }
    
    private func items(for ids: Set<FileItem.ID>) -> [FileItem] {
        tableRowItems.filter { ids.contains($0.id) }
    }
    
    @ViewBuilder
    private func blankAreaContextMenu(inTrash: Bool) -> some View {
        if blankMenuActions.isEnabled {
            Button("返回") {
                blankMenuActions.goBack()
            }
            .disabled(!blankMenuActions.canGoBack)
            
            Button("向上") {
                blankMenuActions.goUp()
            }
            .disabled(!blankMenuActions.canGoUp)
            
            if inTrash {
                Divider()
                Button("清倒废纸篓", role: .destructive) {
                    blankMenuActions.emptyTrash()
                }
            } else {
                if blankMenuActions.canPaste {
                    Divider()
                    Button("粘贴") {
                        blankMenuActions.paste()
                    }
                }
                
                Divider()
                
                Button("新建文件夹") {
                    blankMenuActions.newFolder()
                }
                Button("新建文件") {
                    blankMenuActions.newFile()
                }
                
                Divider()
                
                Button("在此处打开终端") {
                    blankMenuActions.openTerminal()
                }
            }
        }
    }
    
    static func sortingKeyPath(for order: SortOrder) -> [KeyPathComparator<FileItem>] {
        switch order {
        case .nameAscending:
            return [KeyPathComparator(\.name, order: .forward)]
        case .nameDescending:
            return [KeyPathComparator(\.name, order: .reverse)]
        case .dateNewest:
            return [KeyPathComparator(\.modificationDate, order: .reverse)]
        case .dateOldest:
            return [KeyPathComparator(\.modificationDate, order: .forward)]
        case .sizeSmallest:
            return [KeyPathComparator(\.size, order: .forward)]
        case .sizeLargest:
            return [KeyPathComparator(\.size, order: .reverse)]
        }
    }
    
    static func sortOrder(from path: [KeyPathComparator<FileItem>]) -> SortOrder? {
        guard let first = path.first else { return nil }
        let direction = first.order
        
        if first.keyPath == \FileItem.name {
            return direction == .reverse ? .nameDescending : .nameAscending
        }
        if first.keyPath == \FileItem.modificationDate {
            return direction == .reverse ? .dateNewest : .dateOldest
        }
        if first.keyPath == \FileItem.size {
            return direction == .reverse ? .sizeLargest : .sizeSmallest
        }
        return nil
    }
    
    static func pathsProduceSameSortOrder(
        _ lhs: [KeyPathComparator<FileItem>],
        _ rhs: [KeyPathComparator<FileItem>]
    ) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return lhs.isEmpty && rhs.isEmpty }
        guard let mapped = sortOrder(from: lhs) else { return false }
        return mapped == sortOrder(from: rhs)
    }
}

private enum FileDragDrop {
    static func draggedItems(for item: FileItem, in items: [FileItem], selection: Set<FileItem.ID>) -> [FileItem] {
        guard !item.isParentDirectoryEntry else { return [] }
        let effectiveSelection = selection.subtracting([FileItem.parentDirectoryID])
        if effectiveSelection.contains(item.id) {
            return items.filter { effectiveSelection.contains($0.id) && !$0.isParentDirectoryEntry }
        }
        return [item]
    }
    
    static func draggedItemProviders(
        for item: FileItem,
        in items: [FileItem],
        selection: Set<FileItem.ID>
    ) -> NSItemProvider {
        let draggedItems = draggedItems(for: item, in: items, selection: selection)
        let provider = NSItemProvider()
        for draggedItem in draggedItems {
            provider.registerObject(draggedItem.url as NSURL, visibility: .all)
        }
        return provider
    }
    
    static func shouldCopyFromCurrentEvent() -> Bool {
        NSApp.currentEvent?.modifierFlags.contains(.option) == true
    }
    
    static func shouldCopyFromDropInfo(_ info: DropInfo) -> Bool {
        _ = info
        return shouldCopyFromCurrentEvent()
    }
    
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
    
    private static func loadFileURL(from provider: NSItemProvider) async -> URL? {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: URL.self) { item, _ in
                continuation.resume(returning: item?.standardizedFileURL)
            }
        }
    }
    
    static let dragIconSize: CGFloat = 32
    static let dragGhostOpacity: CGFloat = 0.72
    
    static func dragGhostImage(for url: URL) -> NSImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let size = NSSize(width: dragIconSize, height: dragIconSize)
        icon.size = size
        
        let ghost = NSImage(size: size)
        ghost.lockFocus()
        if let context = NSGraphicsContext.current {
            context.imageInterpolation = .high
        }
        icon.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: icon.size),
            operation: .sourceOver,
            fraction: dragGhostOpacity
        )
        ghost.unlockFocus()
        return ghost
    }
    
    static func dragIconFrame(anchor: NSRect, index: Int) -> NSRect {
        let offset = CGFloat(index * 6)
        return NSRect(
            x: anchor.midX - dragIconSize / 2 + offset,
            y: anchor.midY - dragIconSize / 2 - offset,
            width: dragIconSize,
            height: dragIconSize
        )
    }
}

/// 拖放目标显式提议 .move，避免 SwiftUI 默认 .copy 导致绿色加号光标。
private struct FileDropDelegate: DropDelegate {
    @Binding var isTargeted: Bool
    let onDrop: ([URL], Bool) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.fileURL])
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        isTargeted = validateDrop(info: info)
        let copy = FileDragDrop.shouldCopyFromDropInfo(info)
        return DropProposal(operation: copy ? .copy : .move)
    }
    
    func dropExited(info: DropInfo) {
        isTargeted = false
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isTargeted = false
        let copy = FileDragDrop.shouldCopyFromDropInfo(info)
        Task { @MainActor in
            let urls = await FileDragDrop.loadFileURLs(from: info.itemProviders(for: [.fileURL]))
            guard !urls.isEmpty else { return }
            onDrop(urls, copy)
        }
        return true
    }
}

private enum FileDragDebug {
    /// 调试完成后可改为 `false`
    static var isEnabled = true
    static let logPath = "/tmp/macquickfinder-filedrag.log"
    
    static func resetLogFile() {
        let header = "=== FileDrag log started \(ISO8601DateFormatter().string(from: Date())) ===\n"
        try? header.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
    
    static func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        let line = "[FileDrag] \(message())"
        appendToLogFile(line)
        // 仅当 stderr 是终端时才打印，避免管道/grep 影响 GUI 启动
        if isatty(STDERR_FILENO) != 0 {
            fputs(line + "\n", stderr)
        }
    }
    
    private static func appendToLogFile(_ line: String) {
        let url = URL(fileURLWithPath: logPath)
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logPath) {
            guard let handle = try? FileHandle(forWritingTo: url) else { return }
            defer { try? handle.close() }
            handle.seekToEndOfFile()
            handle.write(data)
        } else {
            try? data.write(to: url)
        }
    }
}

/// 标记图标+文件名区域；在此视图上直接处理文件拖拽（SwiftUIOutlineTableView 会吞掉全局 mouseDragged）。
private struct FileDragZoneAnchor: NSViewRepresentable {
    static let zoneIdentifier = NSUserInterfaceItemIdentifier("FileDragZone")
    let item: FileItem
    
    func makeNSView(context: Context) -> FileDragZoneView {
        let view = FileDragZoneView()
        view.item = item
        return view
    }
    
    func updateNSView(_ nsView: FileDragZoneView, context: Context) {
        nsView.item = item
    }
}

private final class FileDragZoneRegistry {
    static let shared = FileDragZoneRegistry()
    private var framesByItemID: [String: CGRect] = [:]
    
    func update(itemID: String, frameInWindow: CGRect) {
        framesByItemID[itemID] = frameInWindow
        FileDragDebug.log(
            "registry update item=\(itemID.suffix(24)) frame=\(NSStringFromRect(frameInWindow))"
        )
    }
    
    func contains(itemID: String, pointInWindow: NSPoint) -> Bool {
        guard let frame = framesByItemID[itemID], frame.width > 0, frame.height > 0 else {
            return false
        }
        return frame.contains(pointInWindow)
    }
    
    func frame(for itemID: String) -> CGRect? {
        framesByItemID[itemID]
    }
}

private final class FileDragZoneView: NSView {
    var item: FileItem?
    
    private var mouseDownLocation: NSPoint?
    private var dragSessionActive = false
    private let dragThreshold: CGFloat = 4
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = FileDragZoneAnchor.zoneIdentifier
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        identifier = FileDragZoneAnchor.zoneIdentifier
    }
    
    override func layout() {
        super.layout()
        guard let item, !item.id.isEmpty else { return }
        if bounds.width <= 1 || bounds.height <= 1 {
            FileDragDebug.log(
                "zone layout skip item=\(item.id.suffix(24)) bounds=\(NSStringFromRect(bounds))"
            )
            return
        }
        let frameInWindow = convert(bounds, to: nil)
        FileDragZoneRegistry.shared.update(itemID: item.id, frameInWindow: frameInWindow)
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let item else { return }
        mouseDownLocation = event.locationInWindow
        dragSessionActive = false
        
        if event.clickCount >= 2 {
            FileDragDebug.log("zone doubleClick item=\(item.name)")
            TableFileDragCoordinator.shared?.openItem(item)
            return
        }
        
        TableFileDragCoordinator.shared?.selectRow(for: item, event: event)
        FileDragDebug.log("zone mouseDown item=\(item.name)")
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let item, !dragSessionActive, let start = mouseDownLocation else { return }
        let distance = hypot(
            event.locationInWindow.x - start.x,
            event.locationInWindow.y - start.y
        )
        guard distance >= dragThreshold else { return }
        
        FileDragDebug.log(
            "zone mouseDragged START item=\(item.name) distance=\(String(format: "%.1f", distance))"
        )
        dragSessionActive = true
        TableFileDragCoordinator.shared?.beginFileDrag(for: item, event: event, dragZoneView: self)
    }
    
    override func mouseUp(with event: NSEvent) {
        mouseDownLocation = nil
        dragSessionActive = false
    }
}

/// 共享的文件拖拽协调器（热区视图 + 拖拽会话）。
private final class TableFileDragCoordinator: NSObject, NSDraggingSource {
    static weak var shared: TableFileDragCoordinator?
    
    weak var tableView: NSTableView?
    var items: [FileItem] = []
    var selection: Set<FileItem.ID> = []
    var onItemOpen: ((FileItem) -> Void)?
    var onDragEnded: (() -> Void)?
    
    func openItem(_ item: FileItem) {
        onItemOpen?(item)
    }
    
    func selectRow(for item: FileItem, event: NSEvent) {
        guard let tableView else { return }
        guard let row = items.firstIndex(where: { $0.id == item.id }) else { return }
        
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
        
        // 点击已选中的项时保留多选，便于批量拖拽
        if effectiveSelectionIDs().contains(item.id) {
            return
        }
        
        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
    }
    
    private func effectiveSelectionIDs() -> Set<FileItem.ID> {
        var ids = selection
        ids.remove(FileItem.parentDirectoryID)
        guard let tableView else { return ids }
        for row in tableView.selectedRowIndexes {
            guard row >= 0, row < items.count else { continue }
            let rowItem = items[row]
            guard !rowItem.isParentDirectoryEntry else { continue }
            ids.insert(rowItem.id)
        }
        return ids
    }
    
    func beginFileDrag(for item: FileItem, event: NSEvent, dragZoneView: NSView) {
        guard let tableView else {
            FileDragDebug.log("beginFileDrag fail no tableView item=\(item.name)")
            return
        }
        
        let selectedIDs = effectiveSelectionIDs()
        let draggedItems = FileDragDrop.draggedItems(
            for: item,
            in: items,
            selection: selectedIDs
        )
        guard !draggedItems.isEmpty else {
            FileDragDebug.log("beginFileDrag fail empty draggedItems item=\(item.name)")
            return
        }
        
        FileDragDebug.log(
            "beginFileDrag OK item=\(item.name) draggingCount=\(draggedItems.count)"
        )
        
        let anchorInTable = dragZoneView.convert(dragZoneView.bounds, to: tableView)
        var draggingItems: [NSDraggingItem] = []
        for (index, fileItem) in draggedItems.enumerated() {
            let frame = FileDragDrop.dragIconFrame(anchor: anchorInTable, index: index)
            let ghostImage = FileDragDrop.dragGhostImage(for: fileItem.url)
            let draggingItem = NSDraggingItem(pasteboardWriter: fileItem.url as NSURL)
            draggingItem.setDraggingFrame(frame, contents: nil)
            draggingItem.imageComponentsProvider = {
                let icon = NSDraggingImageComponent(key: .icon)
                icon.contents = ghostImage
                icon.frame = NSRect(origin: .zero, size: frame.size)
                return [icon]
            }
            draggingItems.append(draggingItem)
        }
        
        let session = tableView.beginDraggingSession(with: draggingItems, event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
        session.draggingFormation = draggedItems.count > 1 ? .pile : .none
    }
    
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            return .copy
        }
        switch context {
        case .withinApplication:
            return .move
        default:
            return .move
        }
    }
    
    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        FileDragDebug.log("dragSession ended operation=\(operation.rawValue)")
        if operation != [] {
            DispatchQueue.main.async { [weak self] in
                self?.onDragEnded?()
            }
        }
    }
}

/// 安装表格引用与拖拽协调器；文件拖放在 FileDragZoneView 上触发。
private struct TableFileDragDropHandler: NSViewRepresentable {
    let items: [FileItem]
    let selection: Set<FileItem.ID>
    let onItemOpen: (FileItem) -> Void
    let onDragEnded: () -> Void
    
    func makeCoordinator() -> TableFileDragCoordinator {
        let coordinator = TableFileDragCoordinator()
        TableFileDragCoordinator.shared = coordinator
        return coordinator
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        installTableView(into: context.coordinator, from: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        let coordinator = context.coordinator
        coordinator.items = items
        coordinator.selection = selection
        coordinator.onItemOpen = onItemOpen
        coordinator.onDragEnded = onDragEnded
        TableFileDragCoordinator.shared = coordinator
        installTableView(into: coordinator, from: nsView)
    }
    
    private func installTableView(into coordinator: TableFileDragCoordinator, from view: NSView) {
        guard coordinator.tableView == nil else { return }
        guard let tableView = findTableView(startingFrom: view) else {
            DispatchQueue.main.async {
                installTableView(into: coordinator, from: view)
            }
            return
        }
        coordinator.tableView = tableView
        FileDragDebug.log(
            "installed tableView=\(type(of: tableView)) columns=\(tableView.tableColumns.map(\.title))"
        )
    }
    
    private func findTableView(startingFrom view: NSView) -> NSTableView? {
        var current: NSView? = view
        while let node = current {
            if let tableView = node as? NSTableView {
                return tableView
            }
            if let tableView = findTableView(in: node.subviews) {
                return tableView
            }
            current = node.superview
        }
        return nil
    }
    
    private func findTableView(in views: [NSView]) -> NSTableView? {
        for view in views {
            if let tableView = view as? NSTableView {
                return tableView
            }
            if let tableView = findTableView(in: view.subviews) {
                return tableView
            }
        }
        return nil
    }
}

/// 在文件列表获得焦点时响应 Delete / Forward Delete，与 Finder 行为一致。
private struct TableDeleteKeyHandler: NSViewRepresentable {
    let isEnabled: Bool
    let onDelete: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDelete: onDelete)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.startMonitoring(from: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.isEnabled = isEnabled
        context.coordinator.onDelete = onDelete
    }
    
    final class Coordinator {
        var isEnabled: Bool
        var onDelete: () -> Void
        private var monitor: Any?
        private weak var tableView: NSTableView?
        
        init(isEnabled: Bool = false, onDelete: @escaping () -> Void) {
            self.isEnabled = isEnabled
            self.onDelete = onDelete
        }
        
        func startMonitoring(from view: NSView) {
            guard monitor == nil else { return }
            guard let tableView = findTableView(startingFrom: view) else {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.startMonitoring(from: view)
                }
                return
            }
            self.tableView = tableView
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self, self.isEnabled else { return event }
                guard self.isTableFocused(event) else { return event }
                guard event.keyCode == 51 || event.keyCode == 117 else { return event }
                guard !event.modifierFlags.contains(.command) else { return event }
                self.onDelete()
                return nil
            }
        }
        
        private func isTableFocused(_ event: NSEvent) -> Bool {
            guard let tableView,
                  let window = tableView.window ?? event.window else { return false }
            guard let responder = window.firstResponder as? NSView else { return false }
            return responder === tableView || responder.isDescendant(of: tableView)
        }
        
        deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }
        
        private func findTableView(startingFrom view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let node = current {
                if let tableView = node as? NSTableView {
                    return tableView
                }
                if let tableView = findTableView(in: node.subviews) {
                    return tableView
                }
                current = node.superview
            }
            return nil
        }
        
        private func findTableView(in views: [NSView]) -> NSTableView? {
            for view in views {
                if let tableView = view as? NSTableView {
                    return tableView
                }
                if let tableView = findTableView(in: view.subviews) {
                    return tableView
                }
            }
            return nil
        }
    }
}

/// 通过 NSTableView 原生 doubleAction 处理双击，避免 SwiftUI TapGesture(count: 2) 延迟单击选中。
private struct TableDoubleClickHandler: NSViewRepresentable {
    let items: [FileItem]
    let onOpen: (FileItem) -> Void
    let onBlankDoubleClick: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(items: items, onOpen: onOpen, onBlankDoubleClick: onBlankDoubleClick)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installIfNeeded(from: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.items = items
        context.coordinator.onOpen = onOpen
        context.coordinator.onBlankDoubleClick = onBlankDoubleClick
        context.coordinator.installIfNeeded(from: nsView)
    }
    
    final class Coordinator: NSObject {
        var items: [FileItem]
        var onOpen: (FileItem) -> Void
        var onBlankDoubleClick: () -> Void
        private weak var tableView: NSTableView?
        
        init(
            items: [FileItem],
            onOpen: @escaping (FileItem) -> Void,
            onBlankDoubleClick: @escaping () -> Void
        ) {
            self.items = items
            self.onOpen = onOpen
            self.onBlankDoubleClick = onBlankDoubleClick
        }
        
        func installIfNeeded(from view: NSView) {
            guard tableView == nil else { return }
            guard let tableView = findTableView(startingFrom: view) else {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.installIfNeeded(from: view)
                }
                return
            }
            tableView.target = self
            tableView.doubleAction = #selector(handleDoubleClick(_:))
            self.tableView = tableView
        }
        
        @objc func handleDoubleClick(_ sender: NSTableView) {
            let row = sender.clickedRow
            if row < 0 || FileListTableMetrics.isBlankColumnClick(in: sender, column: sender.clickedColumn) {
                onBlankDoubleClick()
                return
            }
            guard row < items.count else { return }
            onOpen(items[row])
        }
        
        private func findTableView(startingFrom view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let node = current {
                if let tableView = node as? NSTableView {
                    return tableView
                }
                if let tableView = findTableView(in: node.subviews) {
                    return tableView
                }
                current = node.superview
            }
            return nil
        }
        
        private func findTableView(in views: [NSView]) -> NSTableView? {
            for view in views {
                if let tableView = view as? NSTableView {
                    return tableView
                }
                if let tableView = findTableView(in: view.subviews) {
                    return tableView
                }
            }
            return nil
        }
    }
}

/// 文件列表空白处右键菜单（NSTableView 空白区域不一定会触发 SwiftUI contextMenu）。
private struct TableBlankContextMenuHandler: NSViewRepresentable {
    let actions: FileListBlankMenuActions
    
    func makeCoordinator() -> Coordinator {
        Coordinator(actions: actions)
    }
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.installIfNeeded(from: view)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.actions = actions
        context.coordinator.installIfNeeded(from: nsView)
    }
    
    final class Coordinator: NSObject {
        var actions: FileListBlankMenuActions
        private weak var tableView: NSTableView?
        private var eventMonitor: Any?
        
        private enum MenuAction: Int {
            case goBack = 1
            case goUp
            case paste
            case newFolder
            case newFile
            case openTerminal
            case emptyTrash
        }
        
        init(actions: FileListBlankMenuActions) {
            self.actions = actions
        }
        
        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }
        
        func installIfNeeded(from view: NSView) {
            guard tableView == nil else { return }
            guard let tableView = findTableView(startingFrom: view) else {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view else { return }
                    self.installIfNeeded(from: view)
                }
                return
            }
            self.tableView = tableView
            installEventMonitorIfNeeded()
        }
        
        private func installEventMonitorIfNeeded() {
            guard eventMonitor == nil else { return }
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
                guard let self, self.actions.isEnabled, let tableView = self.tableView,
                      event.window == tableView.window else {
                    return event
                }
                
                let point = tableView.convert(event.locationInWindow, from: nil)
                guard tableView.bounds.contains(point),
                      FileListTableMetrics.isBlankAreaClick(in: tableView, at: point) else {
                    return event
                }
                
                let menu = self.buildMenu()
                guard !menu.items.isEmpty else { return event }
                NSMenu.popUpContextMenu(menu, with: event, for: tableView)
                return nil
            }
        }
        
        private func buildMenu() -> NSMenu {
            let menu = NSMenu()
            
            menu.addItem(makeItem(
                title: "返回",
                action: .goBack,
                enabled: actions.canGoBack
            ))
            menu.addItem(makeItem(
                title: "向上",
                action: .goUp,
                enabled: actions.canGoUp
            ))
            
            if actions.isInTrash {
                menu.addItem(.separator())
                menu.addItem(makeItem(
                    title: "清倒废纸篓",
                    action: .emptyTrash,
                    enabled: true
                ))
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
            
            return menu
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
        
        @objc func handleMenuAction(_ sender: NSMenuItem) {
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
        
        private func findTableView(startingFrom view: NSView) -> NSTableView? {
            var current: NSView? = view
            while let node = current {
                if let tableView = node as? NSTableView {
                    return tableView
                }
                if let tableView = findTableView(in: node.subviews) {
                    return tableView
                }
                current = node.superview
            }
            return nil
        }
        
        private func findTableView(in views: [NSView]) -> NSTableView? {
            for view in views {
                if let tableView = view as? NSTableView {
                    return tableView
                }
                if let tableView = findTableView(in: view.subviews) {
                    return tableView
                }
            }
            return nil
        }
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
    @Binding var showPreview: Bool
    let selection: Set<FileItem.ID>
    let items: [FileItem]
    @State private var imageZoomScale: CGFloat = 1.0
    
    private var selectedItem: FileItem? {
        guard let selectedID = selection.first else { return nil }
        return items.first(where: { $0.id == selectedID })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(selectedItem?.name ?? "")
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer(minLength: 0)
                
                if let selectedItem, isImageFile(selectedItem) {
                    Button {
                        imageZoomScale = min(imageZoomScale + 0.25, 5.0)
                    } label: {
                        Image(systemName: "plus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("放大")
                    
                    Button {
                        imageZoomScale = max(imageZoomScale - 0.25, 1.0)
                    } label: {
                        Image(systemName: "minus.magnifyingglass")
                    }
                    .buttonStyle(.borderless)
                    .help("缩小")
                }
                
                Button {
                    showPreview = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .help("关闭预览")
            }
            .frame(height: PanelTopBarMetrics.contentHeight)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, PanelTopBarMetrics.verticalPadding)
            
            Divider()
            
            if let selectedItem {
                if !selectedItem.isDirectory {
                    FileContentView(item: selectedItem, imageZoomScale: $imageZoomScale)
                        .id(selectedItem.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                } else {
                    Spacer(minLength: 0)
                }
            } else {
                Text("Select a file to preview")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onChange(of: selectedItem?.id) { _ in
            imageZoomScale = 1.0
        }
    }
    
    private func isImageFile(_ item: FileItem) -> Bool {
        let ext = item.url.pathExtension.lowercased()
        return ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic", "webp"].contains(ext)
    }
}

struct FileContentView: View {
    let item: FileItem
    @Binding var imageZoomScale: CGFloat
    @State private var textContent: String = ""
    @State private var image: NSImage? = nil
    @State private var pdfDocument: PDFDocument? = nil
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    private var isImagePreview: Bool {
        image != nil && !isLoading && errorMessage == nil
    }
    
    var body: some View {
        ZStack {
            if isLoading {
                ProgressView("Loading preview...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMsg = errorMessage {
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
            } else if let image = image {
                ImagePreviewContent(image: image, zoomScale: imageZoomScale)
            } else if let pdfDoc = pdfDocument {
                PDFPreview(document: pdfDoc)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !textContent.isEmpty {
                ScrollView {
                    Text(textContent)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding()
                }
            } else {
                Text("Preview not available for this file type")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(isImagePreview ? 0 : 12)
        .task(id: item.id) {
            imageZoomScale = 1.0
            await loadContent()
        }
    }
    
    private func loadContent() async {
        let url = item.url
        let ext = url.pathExtension.lowercased()
        let itemID = item.id
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            textContent = ""
            image = nil
            pdfDocument = nil
        }
        
        func finish(
            image loadedImage: NSImage? = nil,
            pdf loadedPDF: PDFDocument? = nil,
            text content: String? = nil,
            error: String? = nil
        ) async {
            await MainActor.run {
                guard !Task.isCancelled, item.id == itemID else { return }
                image = loadedImage
                pdfDocument = loadedPDF
                if let content { textContent = content }
                errorMessage = error
                isLoading = false
            }
        }
        
        // Load image files
        if ["jpg", "jpeg", "png", "gif", "tiff", "bmp", "heic"].contains(ext) {
            let nsImage = NSImage(contentsOf: url)
            guard !Task.isCancelled else { return }
            if let loadedImage = nsImage {
                await finish(image: loadedImage)
            } else {
                await finish(error: "Unable to decode image format")
            }
            return
        }
        
        // Load PDF files
        if ext == "pdf" {
            let pdfDoc = PDFDocument(url: url)
            guard !Task.isCancelled else { return }
            if let loadedPDF = pdfDoc {
                await finish(pdf: loadedPDF)
            } else {
                await finish(error: "Unable to load PDF document")
            }
            return
        }
        
        // Load text files
        let textExtensions = ["txt", "md", "swift", "java", "py", "js", "html", "css",
                             "json", "xml", "c", "cpp", "h", "sh", "yaml", "yml",
                             "config", "ini", "gitignore", "properties", "log"]
        
        if textExtensions.contains(ext) {
            do {
                let data = try Data(contentsOf: url)
                guard !Task.isCancelled else { return }
                if let content = String(data: data, encoding: .utf8) {
                    let limitedContent = content.count > 20000
                        ? String(content.prefix(20000)) + "\n\n[Content truncated...]"
                        : content
                    await finish(text: limitedContent)
                } else {
                    await finish(error: "Unable to decode text with UTF-8 encoding")
                }
            } catch {
                guard !Task.isCancelled else { return }
                if error is CancellationError { return }
                await finish(error: error.localizedDescription)
            }
            return
        }
        
        // No preview available for other file types
        await finish()
    }
}

private struct ImagePreviewContent: View {
    let image: NSImage
    let zoomScale: CGFloat
    
    @State private var panOffset: CGSize = .zero
    @GestureState private var dragTranslation: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            let containerSize = geometry.size
            let imageSize = resolvedImageSize(image)
            let fitScale = min(
                containerSize.width / max(imageSize.width, 1),
                containerSize.height / max(imageSize.height, 1)
            )
            let displaySize = CGSize(
                width: imageSize.width * fitScale * zoomScale,
                height: imageSize.height * fitScale * zoomScale
            )
            let currentOffset = clampedPanOffset(
                proposed: CGSize(
                    width: panOffset.width + dragTranslation.width,
                    height: panOffset.height + dragTranslation.height
                ),
                containerSize: containerSize,
                displaySize: displaySize
            )
            
            ZStack {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: displaySize.width, height: displaySize.height)
                    .offset(x: currentOffset.width, y: currentOffset.height)
            }
            .frame(width: containerSize.width, height: containerSize.height)
            .clipped()
            .contentShape(Rectangle())
            .gesture(
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
                            displaySize: displaySize
                        )
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: zoomScale) { _ in
            panOffset = .zero
        }
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
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
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
    
    var comparator: (FileItem, FileItem) -> Bool {
        switch self {
        case .nameAscending:
            return { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return { $0.name.localizedStandardCompare($1.name) == .orderedDescending }
        case .dateNewest:
            return { $0.modificationDate > $1.modificationDate }
        case .dateOldest:
            return { $0.modificationDate < $1.modificationDate }
        case .sizeSmallest:
            return { $0.size < $1.size }
        case .sizeLargest:
            return { $0.size > $1.size }
        }
    }
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
            sizeDisplay: "",
            dateDisplay: ""
        )
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
    
    func addDirectory(at path: String) {
        let normalized = (path as NSString).standardizingPath
        guard !contains(path: normalized) else { return }
        let name = (normalized as NSString).lastPathComponent
        items.append(FavoriteItem(path: normalized, name: name, icon: "folder"))
        save()
    }
    
    func remove(path: String) {
        let normalized = (path as NSString).standardizingPath
        items.removeAll { Self.pathsRepresentSameLocation($0.path, normalized) }
        save()
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
    
    private static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = (lhs as NSString).standardizingPath
        let normalizedRHS = (rhs as NSString).standardizingPath
        if normalizedLHS == normalizedRHS { return true }
        
        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }
}

struct SidebarVolume: Identifiable, Equatable {
    let id: String
    let name: String
    let path: String
    let isExternal: Bool
    
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
        Explorer 需要「控制 Finder」的权限才能显示废纸篓内容。

        请在「系统设置 → 隐私与安全性 → 自动化」中，允许 Explorer 控制 Finder。
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
        resolvedTrashPaths().first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".Trash").path
    }
    
    static func resolvedTrashPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates: [String] = [
            FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first?.path,
            (home as NSString).appendingPathComponent(".Trash"),
            "/System/Volumes/Data\(home)/.Trash"
        ].compactMap { $0 }
        
        var paths: [String] = []
        var seen = Set<String>()
        for raw in candidates {
            let path = (raw as NSString).standardizingPath
            guard seen.insert(path).inserted else { continue }
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                paths.append(path)
            }
        }
        return paths
    }
    
    static func isTrashPath(_ path: String) -> Bool {
        let normalized = (path as NSString).standardizingPath
        return resolvedTrashPaths().contains {
            ( $0 as NSString).standardizingPath == normalized
        }
    }
    
    static func trashDirectoryURLs() -> [URL] {
        var urls = resolvedTrashPaths().map { URL(fileURLWithPath: $0, isDirectory: true) }
        var seenPaths = Set(urls.map(\.path))
        
        let uid = getuid()
        guard let volumeURLs = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: nil,
            options: [.skipHiddenVolumes]
        ) else {
            return urls
        }
        
        for volumeURL in volumeURLs {
            let trashURL = volumeURL.appendingPathComponent(".Trashes/\(uid)", isDirectory: true)
            let path = trashURL.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { continue }
            
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue {
                urls.append(trashURL)
            }
        }
        
        return urls
    }
    
    static func loadItems(showHiddenFiles: Bool) async -> [FileItem] {
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
                    guard let item = fileItem(from: fileURL, propertyKeys: propertyKeys) else { continue }
                    itemsByPath[item.id] = item
                }
            } catch {
                print("Error loading trash at \(trashURL.path): \(error)")
            }
        }
        
        let finderPaths = await MainActor.run { trashItemPathsViaFinder() }
        for filePath in finderPaths {
            let fileURL = URL(fileURLWithPath: filePath)
            guard let item = fileItem(from: fileURL, propertyKeys: propertyKeys) else { continue }
            if !showHiddenFiles && item.isHidden { continue }
            itemsByPath[item.id] = item
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
            sizeDisplay: isDirectory ? "--" : FileItemFormatters.formatSize(size),
            dateDisplay: FileItemFormatters.formatDate(modDate)
        )
    }
    
    @MainActor
    private static func trashItemPathsViaFinder() -> [String] {
        let scriptSource = """
        tell application "Finder"
            set output to ""
            repeat with anItem in trash
                set output to output & (POSIX path of (anItem as alias)) & linefeed
            end repeat
            return output
        end tell
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: scriptSource) else { return [] }
        let result = appleScript.executeAndReturnError(&error)
        
        if let error {
            let errorNumber = error[NSAppleScript.errorNumber] as? Int
            print("Finder trash script error (\(errorNumber ?? 0)): \(error)")
            if errorNumber == errAEEventNotPermitted {
                Task { await FinderAutomationPermission.ensureAccess() }
            }
            return []
        }
        
        guard let text = result.stringValue, !text.isEmpty else { return [] }
        return text
            .split(whereSeparator: \.isNewline)
            .map { String($0) }
            .filter { !$0.isEmpty }
    }
}

enum SidebarVolumeLoader {
    private static let propertyKeys: Set<URLResourceKey> = [
        .volumeNameKey,
        .volumeLocalizedNameKey,
        .volumeIsInternalKey,
        .volumeIsBrowsableKey
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
            
            guard isMainInternalVolume(path: volumePath, isInternal: isInternal) || isExternal else {
                continue
            }
            
            guard !seenPaths.contains(volumePath) else { continue }
            seenPaths.insert(volumePath)
            
            volumes.append(SidebarVolume(
                id: volumePath,
                name: name,
                path: volumePath,
                isExternal: isExternal
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

private enum FileOperations {
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
        
        if items.count == 1 {
            if first.isDirectory {
                onNavigate(first.url.path)
            } else {
                NSWorkspace.shared.open(first.url)
            }
            return
        }
        
        for item in items where !item.isDirectory {
            NSWorkspace.shared.open(item.url)
        }
        if let directory = items.first(where: \.isDirectory) {
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
    
    static func rename(_ item: FileItem, completion: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "重命名"
        alert.informativeText = "请输入新名称："
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = item.name
        alert.accessoryView = textField
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = textField
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty, newName != item.name else { return }
        
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            completion()
        } catch {
            NSAlert(error: error).runModal()
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