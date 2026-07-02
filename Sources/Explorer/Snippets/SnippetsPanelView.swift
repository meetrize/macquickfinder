import SwiftUI
import AppKit
import FileList
import UniformTypeIdentifiers

struct SnippetsPanelView: View {
    @Binding var showSnippets: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState
    let selection: Set<FileItem.ID>
    let items: [FileItem]
    let cwd: String
    let showHiddenFiles: Bool
    let panelWidth: CGFloat

    @ObservedObject private var store = SnippetStore.shared
    @ObservedObject private var executor = SnippetExecutor.shared
    @ObservedObject private var settings = SnippetsSettings.shared

    @State private var searchText = ""
    @State private var selectedSnippetID: UUID?
    @State private var importConflictItems: [SnippetImportItem]?
    @State private var importConflictStrategy: SnippetImportStrategy = .skip
    @FocusState private var searchFocused: Bool

    private var selectedItems: [FileItem] {
        FileItem.resolveSelection(ids: selection, from: items)
            .filter { !$0.isParentDirectoryEntry }
    }

    private var visibleSnippets: [Snippet] {
        store.visibleSnippets(
            cwd: cwd,
            selectedItems: selectedItems,
            showHiddenFiles: showHiddenFiles,
            searchQuery: searchText
        )
    }

    private var columnCount: Int {
        snippetColumnCount(for: panelWidth)
    }

    var body: some View {
        VStack(spacing: 0) {
            if layout.isSnippetsContentCollapsed {
                Spacer(minLength: 0)
                Divider()
                topBar
            } else {
                topBar
                Divider()
                snippetGrid
                Divider()
                searchBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: Binding(
            get: { importConflictItems != nil },
            set: { if !$0 { importConflictItems = nil } }
        )) {
            importConflictSheet
        }
        .alert(L10n.Snippets.Confirm.destructiveTitle, isPresented: Binding(
            get: { executor.pendingDestructiveSnippet != nil },
            set: { if !$0 { executor.cancelDestructiveExecution() } }
        )) {
            Button(L10n.Action.cancel, role: .cancel) { executor.cancelDestructiveExecution() }
            Button(L10n.Snippets.Confirm.proceed, role: .destructive) { executor.confirmDestructiveExecution() }
        } message: {
            Text(L10n.Snippets.Confirm.destructiveMessage)
        }
        .onReceive(NotificationCenter.default.publisher(for: .snippetsImportRequested)) { _ in
            importSnippets()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snippetsExportAllRequested)) { _ in
            exportAll()
        }
        .onAppear {
            store.ensureLoaded()
        }
        .focusedValue(\.textFieldEditing, searchFocused)
        .background(TextEditingKeyMonitor(isActive: searchFocused))
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            Button {
                layout.isSnippetsContentCollapsed.toggle()
            } label: {
                Image(systemName: layout.isSnippetsContentCollapsed ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
            .contentShape(Rectangle())
            .instantHoverTooltip(layout.isSnippetsContentCollapsed ? L10n.Snippets.Panel.expand : L10n.Snippets.Panel.collapse)

            Text(L10n.Snippets.title)
                .font(.callout)
                .fontWeight(.medium)
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button { presentNewSnippetEditor() } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(L10n.Snippets.Panel.new)

                Menu {
                    Button(L10n.Snippets.Panel.importAction) { importSnippets() }
                    Button(L10n.Snippets.Panel.exportAll) { exportAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(L10n.Snippets.Panel.importExport)

                Button { showSnippets = false } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(L10n.Snippets.Panel.close)
            }
        }
        .frame(height: PanelTopBarMetrics.contentHeight)
        .padding(.horizontal, 10)
        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
    }

    private var snippetGrid: some View {
        ScrollView {
            if visibleSnippets.isEmpty {
                Text(searchText.isEmpty ? L10n.Snippets.Panel.noMatch : L10n.Snippets.Panel.noResults)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if settings.displayMode == .minimal {
                SnippetFlowLayout(horizontalSpacing: 6, verticalSpacing: 4) {
                    ForEach(visibleSnippets) { snippet in
                        SnippetMinimalButtonView(snippet: snippet) {
                            execute(snippet)
                        }
                        .contextMenu { snippetContextMenu(for: snippet) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columnCount),
                    spacing: 8
                ) {
                    ForEach(visibleSnippets) { snippet in
                        SnippetListItemView(
                            snippet: snippet,
                            isSelected: selectedSnippetID == snippet.id,
                            onExecute: { execute(snippet) },
                            onSelect: { selectedSnippetID = snippet.id }
                        )
                        .onTapGesture(count: 2) { execute(snippet) }
                        .contextMenu { snippetContextMenu(for: snippet) }
                    }
                }
                .padding(8)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: visibleSnippets.map(\.id)) { _ in
            guard settings.displayMode == .standard else { return }
            if selectedSnippetID == nil || !visibleSnippets.contains(where: { $0.id == selectedSnippetID }) {
                selectedSnippetID = visibleSnippets.first?.id
            }
        }
    }

    @ViewBuilder
    private func snippetContextMenu(for snippet: Snippet) -> some View {
        Button(L10n.Action.edit) { presentSnippetEditor(snippet) }
        Button(L10n.Snippets.Panel.execute) { execute(snippet) }
        if !snippet.useSystemTerminal, snippet.scriptType == .shell || snippet.scriptType == .python3 {
            Button(L10n.Snippets.Panel.executeInTerminal) { execute(snippet, inSystemTerminal: true) }
        }
        Button(L10n.Snippets.Panel.exportSingle) { exportSingle(snippet) }
        Divider()
        Button(L10n.Action.delete, role: .destructive) { store.delete(id: snippet.id) }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(L10n.Snippets.Panel.searchPrompt, text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    if settings.displayMode == .minimal {
                        if let first = visibleSnippets.first {
                            execute(first)
                        }
                    } else if let id = selectedSnippetID, let s = visibleSnippets.first(where: { $0.id == id }) {
                        execute(s)
                    } else if let first = visibleSnippets.first {
                        execute(first)
                    }
                }
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private var importConflictSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Snippets.Panel.importConflictTitle)
                .font(.headline)
            Text(L10n.Snippets.Panel.importConflictMessage(importConflictItems?.filter { $0.conflict != nil }.count ?? 0))
            Picker(L10n.Snippets.Panel.importStrategyLabel, selection: $importConflictStrategy) {
                ForEach(SnippetImportStrategy.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            HStack {
                Spacer()
                Button(L10n.Action.cancel) { importConflictItems = nil }
                Button(L10n.Snippets.Panel.importButton) { finishImport() }
            }
        }
        .padding(20)
        .frame(width: 360)
    }

    private func executionContext() -> SnippetExecutionContext {
        SnippetExecutionContext(cwd: cwd, selectedItems: selectedItems)
    }

    private func execute(_ snippet: Snippet, inSystemTerminal: Bool? = nil) {
        executor.execute(snippet, context: executionContext(), inSystemTerminal: inSystemTerminal)
    }

    private func exportAll() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "snippets-\(formattedDate()).json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? SnippetImportExport.exportAll(store.snippets, to: url)
    }

    private func exportSingle(_ snippet: Snippet) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(snippet.name).mqf-snippets.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? SnippetImportExport.exportSingle(snippet, to: url)
    }

    private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let items = try SnippetImportExport.parseImportItems(from: url, existing: store.snippets)
            if items.contains(where: { $0.conflict != nil }) {
                importConflictItems = items
            } else {
                let result = store.importItems(items, strategy: .skip)
                showImportToast(imported: result.imported, skipped: result.skipped)
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func finishImport() {
        guard let items = importConflictItems else { return }
        let result = store.importItems(items, strategy: importConflictStrategy)
        importConflictItems = nil
        showImportToast(imported: result.imported, skipped: result.skipped)
    }

    private func showImportToast(imported: Int, skipped: Int) {
        // Simple alert for now
        let alert = NSAlert()
        alert.messageText = L10n.Snippets.Panel.importDoneTitle
        alert.informativeText = L10n.Snippets.Panel.importDoneMessage(imported: imported, skipped: skipped)
        alert.runModal()
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.Snippets.Panel.importFailedTitle
        alert.informativeText = message
        alert.runModal()
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }

    private func presentNewSnippetEditor() {
        SnippetEditorWindowController.present(
            snippet: nil,
            parentWindow: NSApp.keyWindow,
            onSave: { store.add($0) }
        )
    }

    private func presentSnippetEditor(_ snippet: Snippet) {
        SnippetEditorWindowController.present(
            snippet: snippet,
            parentWindow: NSApp.keyWindow,
            onSave: { store.update($0) },
            onDelete: { store.delete(id: $0) },
            onExport: { exportSingle($0) }
        )
    }
}
