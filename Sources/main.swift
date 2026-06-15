import SwiftUI
import AppKit
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

struct FileCommands: Commands {
    @FocusedValue(\.fileCommandHandlers) private var handlers
    
    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
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
        
        CommandGroup(after: .pasteboard) {
            Button("删除") {
                handlers?.delete?()
            }
            .keyboardShortcut(.delete)
            .disabled(!(handlers?.canDelete ?? false))
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
}

private struct LucideIcon: View {
    let svgData: Data
    var size: CGFloat = 16

    static let folderPlus = LucideIcon(svgData: LucideSVG.folderPlus)

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
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
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
    @AppStorage(AppSettings.previewPanelWidthKey) private var storedPreviewPanelWidth = 320.0
    @State private var livePreviewPanelWidth: CGFloat = 320
    
    private let minPreviewPanelWidth: CGFloat = 200
    private let minMainPanelWidth: CGFloat = 360
    
    var body: some View {
        NavigationSplitView {
            SidebarView(path: $path)
        } detail: {
            GeometryReader { geometry in
                let maxPreviewWidth = max(
                    minPreviewPanelWidth,
                    geometry.size.width - minMainPanelWidth
                )
                
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: navigateUp) {
                                Image(systemName: "arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                            
                            TextField("Path", text: $path)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit(loadItems)
                            
                            Button(action: loadItems) {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .disabled(isLoading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        
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
                                onItemOpen: openItem,
                                onBlankDoubleClick: handleBlankDoubleClick,
                                contextActions: fileContextActions
                            )
                            .focusedValue(\.fileCommandHandlers, fileCommandHandlers)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .searchable(text: $searchText, prompt: "Search files")
                    .navigationTitle("Explorer")
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
                                Picker("Sort By", selection: $sortOrder) {
                                    ForEach(SortOrder.allCases) { order in
                                        Text(order.rawValue).tag(order)
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                            .menuStyle(.borderlessButton)
                        }
                        .hideSharedBackgroundIfAvailable()
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
        .onAppear(perform: loadItems)
        .onChange(of: path) { _ in
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
                    
                    let resourceValues = try fileURL.resourceValues(forKeys: propertyKeys)
                    let isDirectory = resourceValues.isDirectory ?? false
                    let modDate = resourceValues.contentModificationDate ?? Date.distantPast
                    let size = Int64(resourceValues.fileSize ?? 0)
                    let isHidden = resourceValues.isHidden ?? false
                    
                    loadedItems.append(FileItem(
                        id: fileURL.path,
                        url: fileURL,
                        name: fileURL.lastPathComponent,
                        isDirectory: isDirectory,
                        modificationDate: modDate,
                        size: size,
                        isHidden: isHidden,
                        sizeDisplay: isDirectory ? "--" : FileItemFormatters.formatSize(size),
                        dateDisplay: FileItemFormatters.formatDate(modDate)
                    ))
                }
            } catch is CancellationError {
                return
            } catch {
                print("Error loading directory: \(error)")
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
    
    private func navigateUp() {
        let url = URL(fileURLWithPath: path)
        let parent = url.deletingLastPathComponent().path
        if parent != path {
            path = parent
        }
    }
    
    private func openItem(_ item: FileItem) {
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
            addToFavorites: { FavoritesStore.shared.addDirectory(at: $0.url.path) }
        )
    }
    
    private func createNewFolder() {
        let alert = NSAlert()
        alert.messageText = "Create New Folder"
        alert.informativeText = "Enter a name for the new folder:"
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "Folder Name"
        alert.accessoryView = textField
        
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        
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
}

struct SidebarView: View {
    @Binding var path: String
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @State private var devices: [SidebarVolume] = []
    
    var body: some View {
        List {
            Section("Favorites") {
                ForEach(favoritesStore.items) { location in
                    SidebarRow(
                        title: location.name,
                        icon: location.icon,
                        isSelected: isSelected(location.path)
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
                            isSelected: isSelected(device.path)
                        ) {
                            path = device.path
                        }
                    }
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
    
    private func isSelected(_ sidebarPath: String) -> Bool {
        Self.pathsRepresentSameLocation(path, sidebarPath)
    }
    
    private static func pathsRepresentSameLocation(_ lhs: String, _ rhs: String) -> Bool {
        let normalizedLHS = (lhs as NSString).standardizingPath
        let normalizedRHS = (rhs as NSString).standardizingPath
        if normalizedLHS == normalizedRHS { return true }
        
        let systemVolumeRoots: Set<String> = ["/", "/System/Volumes/Data"]
        return systemVolumeRoots.contains(normalizedLHS) && systemVolumeRoots.contains(normalizedRHS)
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
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
                    .fill(isSelected ? Color(nsColor: .unemphasizedSelectedContentBackgroundColor) : .clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
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
}

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    @Binding var tableSortOrder: [KeyPathComparator<FileItem>]
    let searchText: String
    let currentDirectoryPath: String
    let onItemOpen: (FileItem) -> Void
    let onBlankDoubleClick: () -> Void
    let contextActions: FileContextActions
    
    var body: some View {
        Table(items, selection: $selection, sortOrder: $tableSortOrder) {
            TableColumn("Name", value: \.name) { (item: FileItem) in
                HStack {
                    FileItemIcon(item: item)
                    HighlightedText(
                        text: item.name,
                        searchText: searchText,
                        fontWeight: item.isDirectory ? .medium : .regular,
                        opacity: item.isHidden ? 0.6 : 1.0
                    )
                }
            }
            .width(min: 220, ideal: 300)
            
            TableColumn("Size") { item in
                Text(item.sizeDisplay)
                    .foregroundColor(.secondary)
            }
            .width(min: 80, ideal: 100)
            
            TableColumn("Date Modified", value: \.modificationDate) { item in
                Text(item.dateDisplay)
            }
            .width(min: 150, ideal: 180)
        }
        .background(TableDoubleClickHandler(
            items: items,
            onOpen: onItemOpen,
            onBlankDoubleClick: onBlankDoubleClick
        ))
        .background(TableDeleteKeyHandler(
            isEnabled: !selection.isEmpty,
            onDelete: {
                contextActions.delete(items(for: selection))
            }
        ))
        .contextMenu(forSelectionType: FileItem.ID.self) { ids in
            let selected = items(for: ids)
            let destination = FileOperations.pasteDestination(
                selectedItems: selected,
                currentDirectoryPath: currentDirectoryPath
            )
            let showPaste = contextActions.canPaste(destination)
            
            if showPaste {
                Button("粘贴") {
                    contextActions.paste(destination)
                }
            }
            
            if !selected.isEmpty {
                if showPaste {
                    Divider()
                }
                
                if selected.count == 1, let item = selected.first {
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
                        for item in selected {
                            contextActions.open(item)
                        }
                    }
                    Divider()
                }
                
                Button("剪切") {
                    contextActions.cut(selected)
                }
                Button("复制") {
                    contextActions.copy(selected)
                }
                
                Divider()
                
                if selected.count == 1, let item = selected.first {
                    Button("复制文件名") {
                        contextActions.copyFilename(item)
                    }
                }
                Button("复制完整路径") {
                    contextActions.copyPaths(selected)
                }
                
                Divider()
                
                Button("删除", role: .destructive) {
                    contextActions.delete(selected)
                }
                
                if selected.count == 1, let item = selected.first {
                    Button("重命名") {
                        contextActions.rename(item)
                    }
                }
                
                Divider()
                
                Button("属性") {
                    contextActions.showInfo(selected)
                }
            }
        } primaryAction: { ids in
            guard let item = items(for: ids).first else { return }
            contextActions.open(item)
        }
        .transaction { transaction in
            transaction.animation = nil
        }
        .tableStyle(.inset)
    }
    
    private func items(for ids: Set<FileItem.ID>) -> [FileItem] {
        items.filter { ids.contains($0.id) }
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
        default:
            return []
        }
    }
    
    static func sortOrder(from path: [KeyPathComparator<FileItem>]) -> SortOrder? {
        guard let first = path.first else { return nil }
        let direction = first.order
        
        var byPath = sortProbeItems
        byPath.sort(using: path)
        
        var byName = sortProbeItems
        byName.sort(using: [KeyPathComparator(\.name, order: direction)])
        if byPath.map(\.id) == byName.map(\.id) {
            return direction == .reverse ? .nameDescending : .nameAscending
        }
        
        var byDate = sortProbeItems
        byDate.sort(using: [KeyPathComparator(\.modificationDate, order: direction)])
        if byPath.map(\.id) == byDate.map(\.id) {
            return direction == .reverse ? .dateNewest : .dateOldest
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
    
    private static let sortProbeItems: [FileItem] = [
        FileItem(
            id: "sort-probe-m",
            url: URL(fileURLWithPath: "/m"),
            name: "Middle",
            isDirectory: false,
            modificationDate: Date(timeIntervalSince1970: 200),
            size: 200,
            isHidden: false,
            sizeDisplay: "200",
            dateDisplay: ""
        ),
        FileItem(
            id: "sort-probe-a",
            url: URL(fileURLWithPath: "/a"),
            name: "Alpha",
            isDirectory: false,
            modificationDate: Date(timeIntervalSince1970: 300),
            size: 300,
            isHidden: false,
            sizeDisplay: "300",
            dateDisplay: ""
        ),
        FileItem(
            id: "sort-probe-z",
            url: URL(fileURLWithPath: "/z"),
            name: "Zulu",
            isDirectory: false,
            modificationDate: Date(timeIntervalSince1970: 100),
            size: 100,
            isHidden: false,
            sizeDisplay: "100",
            dateDisplay: ""
        )
    ]
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
            if row < 0 {
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
    
    var body: some View {
        if let selectedID = selection.first, let selectedItem = items.first(where: { $0.id == selectedID }) {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Text(selectedItem.name)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    
                    Spacer(minLength: 0)
                    
                    if isImageFile(selectedItem) {
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
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                
                Divider()
                
                if !selectedItem.isDirectory {
                    FileContentView(item: selectedItem, imageZoomScale: $imageZoomScale)
                        .id(selectedItem.id)
                } else {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onChange(of: selectedItem.id) { _ in
                imageZoomScale = 1.0
            }
        } else {
            Text("Select a file to preview")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            }
        }
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
    let id: String
    let url: URL
    let name: String
    let isDirectory: Bool
    let modificationDate: Date
    let size: Int64
    let isHidden: Bool
    let sizeDisplay: String
    let dateDisplay: String
    
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
        
        let destURL = destinationDirectory.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: destURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return false
        }
        
        let destPath = destURL.path
        for sourceURL in state.urls {
            let srcURL = sourceURL.standardizedFileURL
            guard FileManager.default.fileExists(atPath: srcURL.path) else { return false }
            
            let srcPath = srcURL.path
            if state.isCut {
                if srcPath == destPath { return false }
                if destPath.hasPrefix(srcPath + "/") { return false }
                if srcURL.deletingLastPathComponent().standardizedFileURL.path == destPath {
                    return false
                }
            }
        }
        return true
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
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
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