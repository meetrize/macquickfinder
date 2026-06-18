import AppKit
import FileList

@MainActor
enum SnippetsContextMenuBuilder {
    static func appendSnippetsMenu(
        to menu: NSMenu,
        cwd: String,
        selectedItems: [FileItem],
        showHiddenFiles: Bool
    ) {
        let snippets = visibleSnippets(
            cwd: cwd,
            selectedItems: selectedItems,
            showHiddenFiles: showHiddenFiles
        )
        guard !snippets.isEmpty else { return }

        let context = SnippetExecutionContext(
            cwd: cwd,
            selectedItems: selectedItems.filter { !$0.isParentDirectoryEntry }
        )
        let submenu = makeSubmenu(snippets: snippets, context: context)
        let item = NSMenuItem(title: "Snippets", action: nil, keyEquivalent: "")
        item.submenu = submenu
        menu.addItem(.separator())
        menu.addItem(item)
    }

    private static func visibleSnippets(
        cwd: String,
        selectedItems: [FileItem],
        showHiddenFiles: Bool
    ) -> [Snippet] {
        let visibilityContext = SnippetVisibilityContext(
            cwd: cwd,
            selectedItems: selectedItems.filter { !$0.isParentDirectoryEntry },
            showHiddenFiles: showHiddenFiles
        )
        return SnippetStore.shared.sortedVisible(
            context: visibilityContext,
            searchQuery: "",
            pinRecentlyExecuted: SnippetsSettings.shared.pinRecentlyExecutedSnippets
        )
    }

    private static func makeSubmenu(
        snippets: [Snippet],
        context: SnippetExecutionContext
    ) -> NSMenu {
        let submenu = NSMenu()
        for snippet in snippets {
            let item = SnippetMenuCallbackItem(title: snippet.name) {
                Task { @MainActor in
                    SnippetExecutor.shared.executeFromMenu(snippet, context: context)
                }
            }
            submenu.addItem(item)
        }
        return submenu
    }
}

private final class SnippetMenuCallbackItem: NSMenuItem {
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
