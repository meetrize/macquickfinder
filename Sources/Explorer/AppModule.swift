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
    @FocusedValue(\.previewTextEditActive) private var previewTextEditActive
    @FocusedValue(\.previewTextEditSave) private var previewTextEditSave
    
    private var isTextFieldEditing: Bool { textFieldEditing == true }
    private var isPreviewTextSelectionActive: Bool { previewTextSelectionActive == true }
    private var isPreviewTextEditing: Bool { previewTextEditActive == true }
    
    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            if isTextFieldEditing {
                TextEditingCommands.pasteboardButtons()
            } else if isPreviewTextEditing {
                Button(L10n.Preview.TextEdit.save) {
                    previewTextEditSave?()
                }
                .keyboardShortcut("s", modifiers: .command)
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

extension CustomizableToolbarContent {
    @ToolbarContentBuilder
    func hideSharedBackgroundIfAvailable() -> some CustomizableToolbarContent {
        if #available(macOS 26.0, *) {
            self.sharedBackgroundVisibility(.hidden)
        } else {
            self
        }
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

/// 隐藏 unified 工具栏背景与系统底部分隔/阴影，改由内容区 overlay 绘制单像素线。
struct HiddenToolbarChromeSeparatorModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
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
    static let squarePlus = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M8 12h8"/><path d="M12 8v8"/></svg>
""")
    static let galleryHorizontalEnd = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 7v10"/><path d="M6 5v14"/><rect width="12" height="18" x="10" y="3" rx="2"/></svg>
""")
    static let panelTop = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M3 9h18"/></svg>
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
    static let filePlus = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M6 22a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h8a2.4 2.4 0 0 1 1.704.706l3.588 3.588A2.4 2.4 0 0 1 20 8v12a2 2 0 0 1-2 2z"/><path d="M14 2v5a1 1 0 0 0 1 1h5"/><path d="M12 18v-6"/><path d="M9 15h6"/></svg>
""")
    static let folderUp = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/><path d="M12 10v6"/><path d="m9 13 3-3 3 3"/></svg>
""")
    static let panelLeft = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M9 3v18"/></svg>
""")
    static let panelRight = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2"/><path d="M15 3v18"/></svg>
""")
    static let braces = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M8 3H7a2 2 0 0 0-2 2v5a2 2 0 0 1-2 2 2 2 0 0 1 2 2v5c0 1.1.9 2 2 2h1"/><path d="M16 21h1a2 2 0 0 0 2-2v-5a2 2 0 0 1 2-2 2 2 0 0 1-2-2V5a2 2 0 0 0-2-2h-1"/></svg>
""")
    static let gitBranch = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="6" x2="6" y1="3" y2="15"/><circle cx="18" cy="6" r="3"/><circle cx="6" cy="18" r="3"/><path d="M18 9a9 9 0 0 1-9 9"/></svg>
""")
    static let trash2 = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10 11v6"/><path d="M14 11v6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M3 6h18"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>
""")
    static let eye = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0"/><circle cx="12" cy="12" r="3"/></svg>
""")
    static let eyeOff = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49"/><path d="M14.084 14.158a3 3 0 0 1-4.242-4.242"/><path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143"/><path d="m2 2 20 20"/></svg>
""")
    static let list = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 5h.01"/><path d="M3 12h.01"/><path d="M3 19h.01"/><path d="M8 5h13"/><path d="M8 12h13"/><path d="M8 19h13"/></svg>
""")
    static let layoutGrid = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="7" height="7" x="3" y="3" rx="1"/><rect width="7" height="7" x="14" y="3" rx="1"/><rect width="7" height="7" x="14" y="14" rx="1"/><rect width="7" height="7" x="3" y="14" rx="1"/></svg>
""")
    static let image = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect width="18" height="18" x="3" y="3" rx="2" ry="2"/><circle cx="9" cy="9" r="2"/><path d="m21 15-3.086-3.086a2 2 0 0 0-2.828 0L6 21"/></svg>
""")
    static let arrowUpDown = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m21 16-4 4-4-4"/><path d="M17 20V4"/><path d="m3 8 4-4 4 4"/><path d="M7 4v16"/></svg>
""")
    static let chevronRight = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m9 18 6-6-6-6"/></svg>
""")
    static let chevronDown = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m6 9 6 6 6-6"/></svg>
""")
    static let circle = make("""
<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/></svg>
""")
}

struct LucideIcon: View {
    let svgData: Data
    var size: CGFloat = ExplorerToolbarMetrics.iconSize
    var isActive: Bool = false
    var isSecondary: Bool = false
    var isRecording: Bool = false

    static let panelLeft = LucideIcon(svgData: LucideSVG.panelLeft)
    static let panelRight = LucideIcon(svgData: LucideSVG.panelRight)
    static let panelTop = LucideIcon(svgData: LucideSVG.panelTop)

    static func panelTop(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.panelTop, isActive: isActive)
    }
    static let folderPlus = LucideIcon(svgData: LucideSVG.folderPlus)
    static let filePlus = LucideIcon(svgData: LucideSVG.filePlus)
    static let folderUp = LucideIcon(svgData: LucideSVG.folderUp)
    static let trash2 = LucideIcon(svgData: LucideSVG.trash2)
    static let eye = LucideIcon(svgData: LucideSVG.eye)
    static let eyeOff = LucideIcon(svgData: LucideSVG.eyeOff)
    static let arrowUpDown = LucideIcon(svgData: LucideSVG.arrowUpDown)
    static let settings = LucideIcon(svgData: LucideSVG.settings)

    static func chevronRight(size: CGFloat = ExplorerToolbarMetrics.iconSize, isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.chevronRight, size: size, isActive: isActive)
    }

    static func chevronDown(size: CGFloat = ExplorerToolbarMetrics.iconSize, isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.chevronDown, size: size, isActive: isActive)
    }

    static func fileImage(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.fileImage, isActive: isActive)
    }

    static func braces(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.braces, isActive: isActive)
    }

    static func gitBranch(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.gitBranch, isActive: isActive)
    }

    static func terminal(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.terminal, isActive: isActive)
    }

    static func list(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.list, isActive: isActive)
    }

    static func layoutGrid(isActive: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.layoutGrid, isActive: isActive)
    }

    static func record(isRecording: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.circle, isRecording: isRecording)
    }

    static let appWindow = LucideIcon(svgData: LucideSVG.appWindow)
    static let squarePlus = LucideIcon(svgData: LucideSVG.squarePlus)
    static let galleryHorizontalEnd = LucideIcon(svgData: LucideSVG.galleryHorizontalEnd)

    static func image(isSecondary: Bool = false) -> LucideIcon {
        LucideIcon(svgData: LucideSVG.image, isSecondary: isSecondary)
    }

    var body: some View {
        if let image = NSImage(data: svgData) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
                .foregroundStyle(foregroundColor)
        }
    }

    private var foregroundColor: Color {
        if isRecording { return .red }
        if isActive { return .accentColor }
        if isSecondary { return .secondary }
        return .primary
    }
}

enum ExplorerToolbarMetrics {
    static let iconSize: CGFloat = 16
    static let iconHitSize: CGFloat = 18
    static let iconSpacing: CGFloat = 8
}

struct ExplorerToolbarMenuAction {
    let title: String
    var isSelected: Bool = false
    var isOn: Bool? = nil
    let handler: () -> Void
}

struct ExplorerToolbarPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: ExplorerToolbarMetrics.iconSize, height: ExplorerToolbarMetrics.iconSize)
            .frame(width: ExplorerToolbarMetrics.iconHitSize, height: ExplorerToolbarMetrics.iconHitSize)
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

struct ExplorerToolbarIconButton: View {
    let icon: LucideIcon
    let action: () -> Void
    var tooltip: String? = nil
    var isDisabled: Bool = false

    var body: some View {
        let button = Button(action: action) { icon }
            .buttonStyle(ExplorerToolbarPlainButtonStyle())
            .disabled(isDisabled)

        if let tooltip {
            button.instantHoverTooltip(tooltip)
        } else {
            button
        }
    }
}

struct ExplorerToolbarLucideMenuButton: NSViewRepresentable {
    let icon: LucideIcon
    let menuActions: [ExplorerToolbarMenuAction]
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ExplorerToolbarLucideMenuNSView {
        let view = ExplorerToolbarLucideMenuNSView()
        view.onMenuAction = { index in
            guard menuActions.indices.contains(index) else { return }
            menuActions[index].handler()
        }
        updateMenuView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: ExplorerToolbarLucideMenuNSView, context: Context) {
        context.coordinator.menuActions = menuActions
        nsView.onMenuAction = { index in
            guard menuActions.indices.contains(index) else { return }
            menuActions[index].handler()
        }
        updateMenuView(nsView, context: context)
    }

    private func updateMenuView(_ view: ExplorerToolbarLucideMenuNSView, context: Context) {
        view.update(
            svgData: icon.svgData,
            menuActions: menuActions,
            isActive: icon.isActive,
            isSecondary: icon.isSecondary,
            isEnabled: isEnabled
        )
    }

    final class Coordinator {
        var menuActions: [ExplorerToolbarMenuAction] = []
    }
}

struct ExplorerToolbarSFSymbolMenuButton: NSViewRepresentable {
    let systemSymbolName: String
    let menuActions: [ExplorerToolbarMenuAction]
    @Environment(\.isEnabled) private var isEnabled

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> ExplorerToolbarLucideMenuNSView {
        let view = ExplorerToolbarLucideMenuNSView()
        view.onMenuAction = { index in
            guard menuActions.indices.contains(index) else { return }
            menuActions[index].handler()
        }
        updateMenuView(view, context: context)
        return view
    }

    func updateNSView(_ nsView: ExplorerToolbarLucideMenuNSView, context: Context) {
        context.coordinator.menuActions = menuActions
        nsView.onMenuAction = { index in
            guard menuActions.indices.contains(index) else { return }
            menuActions[index].handler()
        }
        updateMenuView(nsView, context: context)
    }

    private func updateMenuView(_ view: ExplorerToolbarLucideMenuNSView, context: Context) {
        view.update(
            systemSymbolName: systemSymbolName,
            menuActions: menuActions,
            isActive: false,
            isSecondary: false,
            isEnabled: isEnabled
        )
    }

    final class Coordinator {
        var menuActions: [ExplorerToolbarMenuAction] = []
    }
}

final class ExplorerToolbarLucideMenuNSView: NSView {
    private let imageView = NSImageView()
    private var menuActions: [ExplorerToolbarMenuAction] = []
    var onMenuAction: ((Int) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        focusRingType = .none

        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: ExplorerToolbarMetrics.iconHitSize),
            heightAnchor.constraint(equalToConstant: ExplorerToolbarMetrics.iconHitSize),
            imageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            imageView.widthAnchor.constraint(equalToConstant: ExplorerToolbarMetrics.iconSize),
            imageView.heightAnchor.constraint(equalToConstant: ExplorerToolbarMetrics.iconSize)
        ])

        let click = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        addGestureRecognizer(click)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        svgData: Data? = nil,
        systemSymbolName: String? = nil,
        menuActions: [ExplorerToolbarMenuAction],
        isActive: Bool,
        isSecondary: Bool,
        isEnabled: Bool
    ) {
        self.menuActions = menuActions

        if let systemSymbolName {
            let config = NSImage.SymbolConfiguration(
                pointSize: ExplorerToolbarMetrics.iconSize,
                weight: .medium
            )
            if let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(config) {
                image.isTemplate = true
                imageView.image = image
            }
        } else if let svgData, let image = NSImage(data: svgData) {
            image.isTemplate = true
            imageView.image = image
        }

        if !isEnabled {
            imageView.contentTintColor = .disabledControlTextColor
            alphaValue = 0.6
        } else if isActive {
            imageView.contentTintColor = .controlAccentColor
            alphaValue = 1
        } else if isSecondary {
            imageView.contentTintColor = .secondaryLabelColor
            alphaValue = 1
        } else {
            imageView.contentTintColor = .labelColor
            alphaValue = 1
        }
    }

    @objc private func handleClick() {
        guard !menuActions.isEmpty else { return }
        let menu = NSMenu()
        for (index, action) in menuActions.enumerated() {
            let item = NSMenuItem(title: action.title, action: #selector(menuItemSelected(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            if let isOn = action.isOn {
                item.state = isOn ? .on : .off
            } else if action.isSelected {
                item.state = .on
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: bounds.height + 2), in: self)
    }

    @objc private func menuItemSelected(_ sender: NSMenuItem) {
        onMenuAction?(sender.tag)
    }

    override var acceptsFirstResponder: Bool { false }
    override var canBecomeKeyView: Bool { false }
}

struct ExplorerToolbarSFSymbolMenu: View {
    let systemSymbolName: String
    var tooltip: String? = nil
    let menuActions: [ExplorerToolbarMenuAction]

    var body: some View {
        let button = ExplorerToolbarSFSymbolMenuButton(
            systemSymbolName: systemSymbolName,
            menuActions: menuActions
        )
        if let tooltip {
            button.instantHoverTooltip(tooltip)
        } else {
            button
        }
    }
}

struct ExplorerToolbarLucideMenu: View {
    let icon: LucideIcon
    var tooltip: String? = nil
    let menuActions: [ExplorerToolbarMenuAction]

    var body: some View {
        let button = ExplorerToolbarLucideMenuButton(icon: icon, menuActions: menuActions)
        if let tooltip {
            button.instantHoverTooltip(tooltip)
        } else {
            button
        }
    }
}

struct ExplorerToolbarThumbnailSizeSlider: View {
    @Binding var cellSize: CGFloat

    private let trackHeight: CGFloat = 4
    private let thumbSize: CGFloat = 11
    private let sliderWidth: CGFloat = 104

    private var range: ClosedRange<CGFloat> {
        FileListThumbnailMetrics.minCellSize...FileListThumbnailMetrics.maxCellSize
    }

    private var progress: CGFloat {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (FileListThumbnailMetrics.steppedCellSize(from: cellSize) - range.lowerBound) / span
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width, 1)
            let fillWidth = max(trackHeight, width * progress)
            let thumbOffset = max(0, min(width - thumbSize, (width - thumbSize) * progress))

            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.18))
                    .frame(height: trackHeight)

                Capsule(style: .continuous)
                    .fill(Color.accentColor.opacity(0.95))
                    .frame(width: fillWidth, height: trackHeight)

                Circle()
                    .fill(Color.accentColor)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                    }
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.18), radius: 1, y: 0.5)
                    .offset(x: thumbOffset)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        updateCellSize(forLocationX: value.location.x, width: width)
                    }
            )
        }
        .frame(width: sliderWidth, height: ExplorerToolbarMetrics.iconHitSize)
    }

    private func updateCellSize(forLocationX locationX: CGFloat, width: CGFloat) {
        let fraction = min(max(locationX / width, 0), 1)
        let rawValue = range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        cellSize = FileListThumbnailMetrics.steppedCellSize(from: rawValue)
    }
}

@main
struct ExplorerApp: App {
    @NSApplicationDelegateAdaptor(ExplorerAppDelegate.self) private var appDelegate
    @StateObject private var languageSettings = InterfaceLanguageSettings.shared
    @ObservedObject private var activeWindowLayout = ActiveWindowLayoutCenter.shared
    @FocusedValue(\.windowLayoutCommands) private var windowLayoutCommands
    @FocusedValue(\.previewDetachCommands) private var previewDetachCommands
    @FocusedValue(\.previewBrowseCommands) private var previewBrowseCommands
    
    var body: some Scene {
        WindowGroup(id: ExplorerWindowScene.main) {
            FullDiskAccessGate {
                ContentView(windowSceneKind: .main)
                    // 文件打开由 AppDelegate → ExternalOpenRouter 处理；勿用 allowing:"*"，
                    // 否则外部 Reveal 会再弹一个主窗口，与现有窗叠成两个 tab。
                    .handlesExternalEvents(
                        preferring: Set(arrayLiteral: "meofind-main"),
                        allowing: Set(arrayLiteral: "meofind-main")
                    )
            }
            .frame(minWidth: 267, minHeight: 200)
            .applyInterfaceLanguageEnvironment()
            .background(ExternalFolderOpenBridge())
            .background(ExplorerBrowserWindowSuppressor())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button(L10n.Settings.menuItem) {
                    SettingsWindowPresenter.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            explorerCommands
        }

        WindowGroup(id: ExplorerWindowScene.folder, for: ExplorerFolderWindowValue.self) { $request in
            FullDiskAccessGate {
                ContentView(
                    initialPath: request?.path,
                    initialSelectionPath: request?.selectionPath,
                    windowSceneKind: .folder
                )
            }
            .frame(minWidth: 267, minHeight: 200)
            .applyInterfaceLanguageEnvironment()
            .background(ExternalFolderOpenBridge())
            .background(ExplorerBrowserWindowSuppressor())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .handlesExternalEvents(matching: Set())

        WindowGroup(id: ExplorerWindowScene.preview, for: PreviewWindowValue.self) { $value in
            Group {
                if let value {
                    DetachedPreviewWindowView(
                        sessionID: value.sessionID,
                        fitImageToScreen: value.fitImageToScreen,
                        initialWindowSize: value.initialWindowSize
                    )
                } else {
                    EmptyView()
                }
            }
            .applyInterfaceLanguageEnvironment()
            .background(ExternalFolderOpenBridge())
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: true))
        .defaultSize(width: 640, height: 480)
    }

    @CommandsBuilder
    private var explorerCommands: some Commands {
        let _ = languageSettings.revision
        let keyLayout = activeWindowLayout.keyWindowLayout
        FileCommands()
        CommandGroup(replacing: .newItem) {
            Button(L10n.Toolbar.newWindow) {
                ExplorerWindowTabCenter.shared.openNewWindowFromActiveExplorer()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.newWindow)
        }
        CommandMenu(L10n.Menu.go) {
            Button(L10n.RemoteServer.connectServerMenu) {
                ConnectServerCenter.shared.requestPresentSheet()
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.connectServer)
        }
        CommandGroup(replacing: .help) {
            Button {
                HelpWindowPresenter.shared.show()
            } label: {
                Label(L10n.Help.cheatSheetMenu, systemImage: "questionmark.circle")
            }
            .keyboardShortcut("?", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button(L10n.CommandPalette.menuTitle) {
                NotificationCenter.default.post(name: .commandPaletteToggleRequested, object: nil)
            }
        }
        CommandGroup(after: .sidebar) {
            Button(L10n.Search.findInFolder) {
                NotificationCenter.default.post(name: .findInFolderRequested, object: nil)
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button(L10n.Menu.toggleLeftPanel) {
                performWindowLayoutAction(
                    onKeyLayout: { $0.toggleLeftPanelVisibility() },
                    fallback: { windowLayoutCommands?.toggleLeftPanel() }
                )
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleLeftPanel)

            Button(L10n.Menu.toggleRightPanel) {
                performWindowLayoutAction(
                    onKeyLayout: { $0.toggleRightPanel() },
                    fallback: { windowLayoutCommands?.toggleRightPanel() }
                )
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleRightPanel)

            Divider()
            Button((keyLayout?.showPreview ?? true) ? L10n.Menu.hidePreview : L10n.Menu.showPreview) {
                performWindowLayoutAction(
                    onKeyLayout: { $0.showPreview.toggle() },
                    fallback: { windowLayoutCommands?.togglePreview() }
                )
            }
            Button((keyLayout?.showSnippets ?? true) ? L10n.Menu.hideSnippets : L10n.Menu.showSnippets) {
                performWindowLayoutAction(
                    onKeyLayout: { $0.showSnippets.toggle() },
                    fallback: { windowLayoutCommands?.toggleSnippets() }
                )
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleSnippets)
            Button((keyLayout?.showGit ?? false) ? L10n.Menu.hideGit : L10n.Menu.showGit) {
                performWindowLayoutAction(
                    onKeyLayout: { $0.toggleGitPanel() },
                    fallback: { windowLayoutCommands?.toggleGit() }
                )
            }
            .keyboardShortcut(ExplorerKeyboardShortcuts.toggleGit)
            Button((keyLayout?.isOutputPanelVisible ?? false) ? L10n.Menu.hideOutputPanel : L10n.Menu.showOutputPanel) {
                performWindowLayoutAction(
                    onKeyLayout: { $0.toggleOutputPanel() },
                    fallback: { windowLayoutCommands?.toggleOutputPanel() }
                )
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

    private func performWindowLayoutAction(
        onKeyLayout action: (ExplorerWindowLayoutState) -> Void,
        fallback: () -> Void
    ) {
        if let layout = activeWindowLayout.keyWindowLayout {
            action(layout)
        } else {
            fallback()
        }
    }
}

extension Notification.Name {
    static let snippetsImportRequested = Notification.Name("snippetsImportRequested")
    static let snippetsExportAllRequested = Notification.Name("snippetsExportAllRequested")
    static let outputCommandFocusRequested = Notification.Name("outputCommandFocusRequested")
    static let commandPaletteToggleRequested = Notification.Name("commandPaletteToggleRequested")
}

@MainActor
final class ExternalFolderOpenCenter: ObservableObject {
    static let shared = ExternalFolderOpenCenter()

    struct OpenRequest: Equatable {
        let directoryPath: String
        let selectionPath: String?
    }

    @Published private(set) var targetRequest: OpenRequest?
    @Published private(set) var openRequestGeneration: UInt = 0
    private(set) var isSessionEstablished = false
    private(set) var launchedFromExternalEvent = false
    private var pendingRequest: OpenRequest?
    /// 温启动复用时限定由哪个 NSWindow 的 ContentView 消费 pending（避免背后幽灵窗抢走选中）。
    private(set) var pendingDeliveryWindowID: ObjectIdentifier?
    private var openFolderWindow: ((OpenRequest) -> Void)?
    private var recentlyHandledRequestKeys: [String: Date] = [:]
    private let requestDedupeWindow: TimeInterval = 1.0

    private init() {}

    func markSessionEstablished() {
        let wasEstablished = isSessionEstablished
        isSessionEstablished = true
        if !wasEstablished {
            ExternalOpenDiagnostic.logRaw("session established")
        }
        // 冷启动外部 Reveal：窗刚就绪时再抢一次前台（此前 bring 时窗可能尚未创建）。
        if !wasEstablished, launchedFromExternalEvent {
            scheduleColdLaunchFrontActivation()
        }
    }

    func markLaunchedFromExternalEvent() {
        launchedFromExternalEvent = true
    }

    var shouldAllowUntitledWindow: Bool {
        !launchedFromExternalEvent || isSessionEstablished
    }

    func setOpenFolderWindowHandler(_ handler: @escaping (OpenRequest) -> Void) {
        openFolderWindow = handler
    }

    func requestOpen(urls: [URL]) {
        guard let resolved = ExternalFolderOpenRequestResolver.resolve(from: urls) else { return }
        let resolvedRequest = OpenRequest(
            directoryPath: resolved.directoryPath,
            selectionPath: resolved.selectionPath
        )
        if consumeDuplicateRequest(resolvedRequest) {
            return
        }
        recordHandledRequest(resolvedRequest)

        let app = NSApplication.shared
        app.unhide(nil)
        app.activate(ignoringOtherApps: true)
        let opts = NSApplication.ActivationOptions([.activateAllWindows, .activateIgnoringOtherApps])
        _ = NSRunningApplication.current.activate(options: opts)

        let targetDir = ExternalSelectionPathMatcher.standardizedPath(resolvedRequest.directoryPath)
        let tabs = ExplorerWindowTabCenter.shared
        tabs.clearStalePendingOpen(reason: "requestOpen")
        tabs.beginExternalDocumentOpenSuppression(duration: 1.2)
        ExternalOpenDiagnostic.logWindowSnapshot("requestOpen-enter dir=\(targetDir)")
        ExternalOpenDiagnostic.logRaw(
            "requestOpen resolved selection=\(resolvedRequest.selectionPath ?? "nil") session=\(isSessionEstablished)"
        )

        let anchor = preferredExplorerAnchorWindow()
        ExternalOpenDiagnostic.logRaw(
            "requestOpen anchor path=\(anchor.flatMap { tabs.path(for: $0) } ?? "nil") key=\(anchor?.isKeyWindow ?? false) session=\(isSessionEstablished) registered=\(tabs.hasRegisteredWindows)"
        )

        // 温启动（有会话或已登记窗）：每次 Reveal 都新开标签并激活选中（同目录亦然）。
        // 保留微信路径：无锚点时 openFolderWindow，避免「完全无响应」。
        // 不单靠 isSessionEstablished：冷启动后若 mark 漏掉，二次 Reveal 会误走 cold-pending。
        let warm = isSessionEstablished || tabs.hasRegisteredWindows
        if warm {
            if let anchor {
                let currentDir = tabs.path(for: anchor).map {
                    ExternalSelectionPathMatcher.standardizedPath($0)
                }
                ExternalOpenDiagnostic.logRaw(
                    "requestOpen warm-new-tab ALWAYS from=\(currentDir ?? "nil") to=\(targetDir) selection=\(resolvedRequest.selectionPath ?? "nil")"
                )
                if !isSessionEstablished {
                    markSessionEstablished()
                }
                deliverOpenRequestInNewTab(resolvedRequest, anchor: anchor)
                return
            }

            ExternalOpenDiagnostic.logRaw(
                "requestOpen warm-no-anchor → try any browser or openFolderWindow"
            )
            if let anyBrowser = NSApp.windows.first(where: {
                !$0.isMiniaturized && $0.canBecomeKey
                    && tabs.path(for: $0) != nil
                    && (tabs.sceneKind(for: $0) == .main || tabs.sceneKind(for: $0) == .folder)
            }) {
                if !isSessionEstablished { markSessionEstablished() }
                deliverOpenRequestInNewTab(resolvedRequest, anchor: anyBrowser)
                return
            }
            if let key = NSApp.keyWindow {
                if !isSessionEstablished { markSessionEstablished() }
                deliverOpenRequestInNewTab(resolvedRequest, anchor: key)
                return
            }
            // 会话已建立但暂无可用宿主窗：回退新建文件夹窗，禁止静默吞掉请求
            // （微信/系统「在访达中显示」在此路径上会表现为完全无响应）。
            if !isSessionEstablished { markSessionEstablished() }
            ExternalOpenDiagnostic.logRaw(
                "requestOpen warm-no-anchor → openFolderWindow dir=\(resolvedRequest.directoryPath)"
            )
            openFolderWindow?(resolvedRequest)
            return
        }

        // 冷启动 I1：单窗 + pendingRequest。
        ExternalOpenDiagnostic.logRaw(
            "requestOpen cold-pending dir=\(resolvedRequest.directoryPath) selection=\(resolvedRequest.selectionPath ?? "nil")"
        )
        markLaunchedFromExternalEvent()
        targetRequest = resolvedRequest
        pendingRequest = resolvedRequest
        pendingDeliveryWindowID = nil
        bringExplorerWindowsToFront()
        scheduleColdLaunchFrontActivation()
        openRequestGeneration &+= 1
        schedulePendingApplyRetries()
        DuplicateExplorerWindowCloser.scheduleCoalesce(keeping: resolvedRequest)
    }

    /// 窥视尚未消费的 pending（不清除），供 ContentView 判断是否应由本窗处理。
    func peekPendingRequest() -> OpenRequest? {
        pendingRequest
    }

    /// 温启动复用时限定消费窗；无限定则任何匹配窗可消费。
    func pendingDeliveryMatches(window: NSWindow?) -> Bool {
        guard let pendingDeliveryWindowID else { return true }
        guard let window else { return false }
        return ObjectIdentifier(window) == pendingDeliveryWindowID
    }

    /// 仅由 frontmost 浏览标签消费；消费后清除 sticky `targetRequest`。
    func consumePendingRequest() -> OpenRequest? {
        let request = pendingRequest
        pendingRequest = nil
        pendingDeliveryWindowID = nil
        if request != nil {
            targetRequest = nil
        }
        return request
    }

    /// 供测试重置进程内状态。
    func resetForTesting() {
        isSessionEstablished = false
        launchedFromExternalEvent = false
        targetRequest = nil
        pendingRequest = nil
        pendingDeliveryWindowID = nil
        openRequestGeneration = 0
        recentlyHandledRequestKeys.removeAll()
    }

    /// 同目录复用入口（含 `openExternalRevealTab` 双保险 abort）。
    func deliverReuseSelection(directoryPath: String, selectionPath: String?, window: NSWindow) {
        deliverOpenRequestToWindow(
            OpenRequest(directoryPath: directoryPath, selectionPath: selectionPath),
            window: window
        )
    }

    /// 投递给指定窗；激活竞态下多次 bump generation，避免 pending 因单次 !isKey 永丢。
    private func deliverOpenRequestToWindow(_ request: OpenRequest, window: NSWindow) {
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)
        // 关掉同路径的其它窗（背后幽灵独立窗），只留 keeper 所在标签组。
        closeDetachedDuplicateWindows(of: window, directoryPath: request.directoryPath)
        // 只关「与 keeper 同路径」的游离窗；勿在 suppression 下误关前台其它目录标签组。
        closeOrphanDuplicatesOnly(of: window, directoryPath: request.directoryPath)
        ExplorerWindowTabCenter.shared.activateExplorerWindow(window, forceFrontmost: true)
        ExternalOpenDiagnostic.logWindowSnapshot("after-reuse-activate")
        pendingRequest = request
        pendingDeliveryWindowID = ObjectIdentifier(window)
        targetRequest = nil
        openRequestGeneration &+= 1
        schedulePendingApplyRetries()
        // 勿再 forceFrontmost：activate 内部已合并重试；重复 force 会打满主线程、卡死微信 AE。
        for delay in [0.15, 0.5] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.closeOrphanDuplicatesOnly(of: window, directoryPath: request.directoryPath)
                ExplorerWindowTabCenter.shared.activateExplorerWindow(window, forceFrontmost: false)
                if self.pendingRequest != nil,
                   self.pendingDeliveryWindowID == ObjectIdentifier(window) {
                    self.openRequestGeneration &+= 1
                }
            }
        }
    }

    /// 仅关闭与目标目录同路径、且不在 keeper 标签组内的窗（比全面 closeDetachedBrowserWindows 更安全）。
    private func closeOrphanDuplicatesOnly(of keeper: NSWindow, directoryPath: String) {
        closeDetachedDuplicateWindows(of: keeper, directoryPath: directoryPath)
    }

    /// 关闭与目标目录同路径、但不在 keeper 标签组内的窗（含误拆出的独立窗）。
    private func closeDetachedDuplicateWindows(of keeper: NSWindow, directoryPath: String) {
        let target = ExternalSelectionPathMatcher.standardizedPath(directoryPath)
        let keeperGroup = keeper.tabGroup
        for window in NSApp.windows {
            guard window !== keeper else { continue }
            let kind = ExplorerWindowTabCenter.shared.sceneKind(for: window)
            guard kind == .main || kind == .folder else { continue }
            guard let path = ExplorerWindowTabCenter.shared.path(for: window) else { continue }
            guard ExternalSelectionPathMatcher.standardizedPath(path) == target else { continue }
            let sameGroup = (keeperGroup != nil && window.tabGroup === keeperGroup)
            if sameGroup { continue }
            ExternalOpenDiagnostic.logRaw(
                "close detached duplicate window path=\(path)"
            )
            window.close()
        }
    }

    /// 外部 Reveal 到不同/相同目录：folder WindowValue 开标签并合并，禁止无参 main 叠 Desktop。
    private func deliverOpenRequestInNewTab(_ request: OpenRequest, anchor: NSWindow) {
        pendingRequest = nil
        targetRequest = nil
        pendingDeliveryWindowID = nil
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)
        ExplorerWindowTabCenter.shared.clearStalePendingOpen(reason: "deliverOpenRequestInNewTab")
        ExternalOpenDiagnostic.logRaw(
            "deliverOpenRequestInNewTab dir=\(request.directoryPath) selection=\(request.selectionPath ?? "nil")"
        )
        ExplorerWindowTabCenter.shared.openExternalRevealTab(
            path: request.directoryPath,
            selectionPath: request.selectionPath,
            from: anchor,
            activatesTab: true
        )
        let revealDir = request.directoryPath
        let selection = request.selectionPath
        let activateNewTab: (Bool) -> Void = { force in
            // 同目录多标签：必须激活「刚合并」的那一页，不能 windowShowingDirectory（会命中旧 Excel 标签）。
            let newTab = ExplorerWindowTabCenter.shared.lastMergedRevealTab()
                ?? ExplorerWindowTabCenter.shared.windowShowingDirectory(
                    revealDir,
                    preferringGroupOf: anchor
                )
            if let newTab {
                ExplorerWindowTabCenter.shared.activateExplorerWindow(newTab, forceFrontmost: force)
                ExternalOpenDiagnostic.logRaw(
                    "deliverOpenRequestInNewTab activate win path=\(ExplorerWindowTabCenter.shared.path(for: newTab) ?? "nil") selection=\(selection ?? "nil")"
                )
            } else {
                ExplorerWindowTabCenter.shared.activateExplorerWindow(anchor, forceFrontmost: force)
                ExternalOpenDiagnostic.logRaw("deliverOpenRequestInNewTab activate fallback=anchor")
            }
            ExternalOpenDiagnostic.logWindowSnapshot("after-new-tab-activate")
        }
        activateNewTab(true)
        // tabsOnly：只收壳/游离窗，不要 coalesce 掉同目录的旧业务标签。
        DuplicateExplorerWindowCloser.scheduleCoalesce(keeping: request, tabsOnly: true)
        let anchorRef = anchor
        // 后续只做轻量确认；force 重试已在 activateExplorerWindow 内合并。
        for delay in [0.25, 0.7] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                activateNewTab(false)
                if let newTab = ExplorerWindowTabCenter.shared.lastMergedRevealTab() {
                    DuplicateExplorerWindowCloser.closeDetachedBrowserWindows(
                        keepingTabGroupOf: newTab
                    )
                    ExplorerWindowTabCenter.shared.pruneDuplicateAnchorTabsForReveal(
                        anchor: anchorRef,
                        newTab: newTab
                    )
                }
            }
        }
    }

    private func schedulePendingApplyRetries() {
        guard pendingRequest != nil else { return }
        for delay in [0.05, 0.2, 0.5] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.pendingRequest != nil else { return }
                self.openRequestGeneration &+= 1
            }
        }
    }

    private func preferredExplorerAnchorWindow() -> NSWindow? {
        let browserCandidates = NSApplication.shared.windows.filter { window in
            guard !window.isMiniaturized, window.canBecomeKey else { return false }
            // 独立预览等禁止标签的窗不作为 Reveal 锚点；但允许已注册 path 的 folder 标签。
            let kind = ExplorerWindowTabCenter.shared.sceneKind(for: window)
            guard kind == .main || kind == .folder else { return false }
            if window.tabbingMode == .disallowed,
               ExplorerWindowTabCenter.shared.path(for: window) == nil {
                return false
            }
            return true
        }
        // 优先已注册 path 的宿主窗。
        let registered = browserCandidates.filter {
            ExplorerWindowTabCenter.shared.path(for: $0) != nil
        }
        let candidates = registered.isEmpty
            ? browserCandidates.filter { $0.isVisible || $0.isKeyWindow }
            : registered
        guard !candidates.isEmpty else { return nil }
        if let key = NSApp.keyWindow, candidates.contains(where: { $0 === key }) {
            return key
        }
        if let selected = candidates.first(where: { $0.tabGroup?.selectedWindow === $0 }) {
            return selected
        }
        return candidates.first
    }

    func requestOpenInNewWindow(directoryPath: String) {
        let standardized = (directoryPath as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        openFolderWindow?(
            OpenRequest(directoryPath: standardized, selectionPath: nil)
        )
    }

    private var hasVisibleExplorerWindow: Bool {
        NSApplication.shared.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeKey
        }
    }

    private func bringExplorerWindowsToFront() {
        let app = NSApplication.shared
        app.unhide(nil)
        app.activate(ignoringOtherApps: true)

        let browser = app.windows.first { window in
            guard !window.isMiniaturized, window.canBecomeKey else { return false }
            guard window.tabbingMode != .disallowed else { return false }
            let kind = ExplorerWindowTabCenter.shared.sceneKind(for: window)
            return kind == .main || kind == .folder
        }
        if let browser {
            ExplorerWindowTabCenter.shared.activateExplorerWindow(browser, forceFrontmost: true)
            return
        }
        if let keyWindow = app.keyWindow {
            keyWindow.deminiaturize(nil)
            keyWindow.makeKeyAndOrderFront(nil)
            return
        }
        if let window = app.windows.first(where: { $0.canBecomeKey }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// 冷启动时窗尚未就绪；多拍激活，避免停在 MeoLaunch / 其它应用后面。
    private func scheduleColdLaunchFrontActivation() {
        for delay in [0.0, 0.35, 1.0] as [TimeInterval] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self else { return }
                if NSApp.isActive, NSApp.keyWindow != nil {
                    return
                }
                ExternalOpenDiagnostic.logRaw("cold-launch front activation delay=\(delay)")
                self.bringExplorerWindowsToFront()
            }
        }
    }

    private func dedupeKey(for request: OpenRequest) -> String {
        let directory = (request.directoryPath as NSString).standardizingPath
        if let selectionPath = request.selectionPath {
            let selection = (selectionPath as NSString).standardizingPath
            return "\(directory)|\(selection)"
        }
        return directory
    }

    private func consumeDuplicateRequest(_ request: OpenRequest) -> Bool {
        pruneHandledRequests()
        let key = dedupeKey(for: request)
        guard let handledAt = recentlyHandledRequestKeys[key] else { return false }
        return Date().timeIntervalSince(handledAt) < requestDedupeWindow
    }

    private func recordHandledRequest(_ request: OpenRequest) {
        let now = Date()
        recentlyHandledRequestKeys[dedupeKey(for: request)] = now
        pruneHandledRequests(now: now)
    }

    private func pruneHandledRequests(now: Date = Date()) {
        recentlyHandledRequestKeys = recentlyHandledRequestKeys.filter {
            now.timeIntervalSince($0.value) < requestDedupeWindow
        }
    }
}

struct ExternalNavigationTarget: Equatable {
    let directoryPath: String
    let selectionPath: String?
}

private final class ExplorerAppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        ModuleLocalization.applyAppleLanguagesOverride()
        if ExternalOpenIntentDetector.currentIntentFromCurrentEvent() == .revealInFileViewer {
            ExternalFolderOpenCenter.shared.markLaunchedFromExternalEvent()
        }
        DefaultFileViewerManager.registerWithLaunchServicesIfNeeded()
        DefaultPreviewHandlerManager.registerWithLaunchServicesIfNeeded()
        MeoFindDocumentOpenerBundle.registerWithLaunchServicesIfNeeded()
        ExternalFileViewerRevealSupport.installIfNeeded()
        ExternalPreviewOpenForwarder.installIfNeeded()
        Task {
            await DefaultPreviewHandlerManager.syncDocumentOpenerRegistrationIfNeeded()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 兜底：即便尚无窗口创建 layout，也尽早标脏 / 必要时清全景偏好。
        ExplorerSessionRecovery.prepareLaunchIfNeeded()
        FileServicesMenuSupport.registerIfNeeded()
        AppMemoryPressure.installHandler()
        PasteboardPasteAvailability.shared.install()
        GlobalHotkeyService.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        ExplorerSessionRecovery.markCleanExit()
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        // open -R / odoc 会先问「要不要空白窗」再投递 URL。温启动若返回 true，
        // 系统会再开一个 main 窗并落到 restoredLaunchPath（常为 Desktop），
        // 随后我们的 Reveal 再开目标标签 → Desktop + Desktop + 目标 三标签。
        // 冷启动（尚无任何浏览窗）必须允许空白窗，否则 pending 无人消费 → 完全无响应。
        ExternalOpenDiagnostic.logRaw("shouldOpenUntitledFile invoked")
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)

        let hasBrowser =
            ExplorerWindowTabCenter.shared.hasRegisteredWindows
            || ExplorerWindowTabCenter.shared.hasVisibleBrowserWindows
            || ExternalFolderOpenCenter.shared.isSessionEstablished

        if hasBrowser {
            ExternalOpenDiagnostic.logRaw("shouldOpenUntitledFile=false (existing browser/session)")
            return false
        }

        // 冷启动：必须有一扇窗承接 pending（含 srev/odoc）。
        // 勿再读 shouldAllowUntitledWindow：willFinishLaunching 可能已 markLaunchedFromExternalEvent
        // 导致其返回 false，窗永远不出现 → 微信/系统 Reveal 完全无响应。
        ExternalOpenDiagnostic.logRaw("shouldOpenUntitledFile=true (cold — need window for pending)")
        return true
    }

    @MainActor
    @objc func newWindowForTab(_ sender: Any?) {
        ExternalOpenDiagnostic.logRaw(
            "AppDelegate newWindowForTab sender=\(sender as? NSWindow != nil ? "window" : String(describing: sender))"
        )
        let center = ExplorerWindowTabCenter.shared

        // Window swizzle 可能已写入 pending。仅用户「+」且无外部抑制时保留壳；
        // 微信/odoc 抑制期内绝不能 keep，否则空标签抢走 Reveal。
        if center.hasPendingNewTab {
            if center.shouldRetainSystemNewTabShell {
                if sender is NSWindow {
                    ExternalOpenDiagnostic.logRaw("AppDelegate newWindowForTab — pending set, keep shell")
                    return
                }
                center.openBridgeWindowForPendingNewTabIfNeeded()
                return
            }
            if let tabShell = sender as? NSWindow {
                ExternalOpenDiagnostic.logRaw("AppDelegate newWindowForTab — swallow shell under reveal/suppression")
                center.closeSurplusWindow(tabShell, reason: "newWindowForTab-reveal-swallow")
            }
            return
        }

        var anchorWindow = NSApp.keyWindow
        if let tabShell = sender as? NSWindow {
            if let tabGroup = tabShell.tabGroup {
                anchorWindow = tabGroup.windows.first {
                    $0 !== tabShell && center.path(for: $0) != nil
                } ?? tabGroup.windows.first { $0 !== tabShell && $0.isVisible } ?? anchorWindow
            }
        }

        switch center.systemNewTabAction(from: anchorWindow) {
        case .createWithOriginal:
            if sender is NSWindow {
                ExternalOpenDiagnostic.logRaw("AppDelegate newWindowForTab — reuse system shell")
                return
            }
            center.scheduleSystemPlusBridgeFallbackIfNeeded()
        case .swallow:
            if let tabShell = sender as? NSWindow {
                center.closeSurplusWindow(tabShell, reason: "newWindowForTab-swallow")
            }
        case .passThrough:
            break
        }
    }

    @MainActor
    func application(_ application: NSApplication, open urls: [URL]) {
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)
        ExternalOpenDiagnostic.logRaw("application(open:) urls=\(urls.map(\.path))")
        ExternalOpenRouter.handleOpen(urls: urls)
    }

    @MainActor
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)
        ExternalOpenDiagnostic.logRaw("application(openFiles:) files=\(filenames)")
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        ExternalOpenRouter.handleOpen(urls: urls)
        sender.reply(toOpenOrPrint: .success)
    }

    @MainActor
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        ExplorerWindowTabCenter.shared.beginExternalDocumentOpenSuppression(duration: 1.2)
        ExternalOpenDiagnostic.logRaw("application(openFile:) file=\(filename)")
        ExternalOpenRouter.handleOpen(urls: [URL(fileURLWithPath: filename)])
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                NSApp.unhide(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
        return true
    }
}