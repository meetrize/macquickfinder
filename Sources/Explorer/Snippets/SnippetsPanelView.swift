import SwiftUI
import AppKit
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

    @State private var searchText = ""
    @State private var selectedSnippetID: UUID?
    @State private var editorSnippet: Snippet?
    @State private var isCreating = false
    @State private var importConflictItems: [SnippetImportItem]?
    @State private var importConflictStrategy: SnippetImportStrategy = .skip
    @FocusState private var searchFocused: Bool

    private var selectedItems: [FileItem] {
        FileItem.resolveSelection(ids: selection, from: items)
            .filter { !$0.isParentDirectoryEntry }
    }

    private var visibilityContext: SnippetVisibilityContext {
        SnippetVisibilityContext(
            cwd: cwd,
            selectedItems: selectedItems,
            showHiddenFiles: showHiddenFiles
        )
    }

    private var visibleSnippets: [Snippet] {
        store.sortedVisible(
            context: visibilityContext,
            searchQuery: searchText,
            pinRecentlyExecuted: SnippetsSettings.shared.pinRecentlyExecutedSnippets
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
        .sheet(item: $editorSnippet) { snippet in
            SnippetEditorSheet(
                snippet: snippet,
                onSave: { store.update($0) },
                onDelete: { store.delete(id: $0) },
                onExport: { exportSingle($0) }
            )
        }
        .sheet(isPresented: $isCreating) {
            SnippetEditorSheet(snippet: nil) { store.add($0) }
        }
        .sheet(isPresented: Binding(
            get: { importConflictItems != nil },
            set: { if !$0 { importConflictItems = nil } }
        )) {
            importConflictSheet
        }
        .alert("危险命令确认", isPresented: Binding(
            get: { executor.pendingDestructiveSnippet != nil },
            set: { if !$0 { executor.cancelDestructiveExecution() } }
        )) {
            Button("取消", role: .cancel) { executor.cancelDestructiveExecution() }
            Button("仍要执行", role: .destructive) { executor.confirmDestructiveExecution() }
        } message: {
            Text("此 Snippet 可能删除或移动文件，确定执行？")
        }
        .onReceive(NotificationCenter.default.publisher(for: .snippetsImportRequested)) { _ in
            importSnippets()
        }
        .onReceive(NotificationCenter.default.publisher(for: .snippetsExportAllRequested)) { _ in
            exportAll()
        }
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
            .help(layout.isSnippetsContentCollapsed ? "展开 Snippets" : "折叠 Snippets")

            Text("Snippets")
                .font(.callout)
                .fontWeight(.medium)
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button { isCreating = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .help("新建")

                Menu {
                    Button("导入…") { importSnippets() }
                    Button("导出全部…") { exportAll() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .help("导入 / 导出")

                Button { showSnippets = false } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .help("关闭 Snippets")
            }
        }
        .frame(height: PanelTopBarMetrics.contentHeight)
        .padding(.horizontal, 10)
        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
    }

    private var snippetGrid: some View {
        ScrollView {
            if visibleSnippets.isEmpty {
                Text(searchText.isEmpty ? "当前上下文无匹配 Snippet" : "无搜索结果")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
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
                        .contextMenu {
                            Button("编辑") { editorSnippet = snippet }
                            Button("执行") { execute(snippet) }
                            if !snippet.useSystemTerminal, snippet.scriptType == .shell || snippet.scriptType == .python3 {
                                Button("在终端中执行") { execute(snippet, inSystemTerminal: true) }
                            }
                            Button("导出…") { exportSingle(snippet) }
                            Divider()
                            Button("删除", role: .destructive) { store.delete(id: snippet.id) }
                        }
                    }
                }
                .padding(8)
            }
        }
        .frame(maxHeight: .infinity)
        .onChange(of: visibleSnippets.map(\.id)) { _ in
            if selectedSnippetID == nil || !visibleSnippets.contains(where: { $0.id == selectedSnippetID }) {
                selectedSnippetID = visibleSnippets.first?.id
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("搜索名称或脚本内容…", text: $searchText)
                .textFieldStyle(.plain)
                .focused($searchFocused)
                .onSubmit {
                    if let id = selectedSnippetID, let s = visibleSnippets.first(where: { $0.id == id }) {
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
            Text("导入冲突")
                .font(.headline)
            Text("有 \(importConflictItems?.filter { $0.conflict != nil }.count ?? 0) 条与现有 Snippet 冲突")
            Picker("处理方式", selection: $importConflictStrategy) {
                ForEach(SnippetImportStrategy.allCases) { s in
                    Text(s.displayName).tag(s)
                }
            }
            HStack {
                Spacer()
                Button("取消") { importConflictItems = nil }
                Button("导入") { finishImport() }
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
        alert.messageText = "导入完成"
        alert.informativeText = "已导入 \(imported) 条，跳过 \(skipped) 条"
        alert.runModal()
    }

    private func presentError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "导入失败"
        alert.informativeText = message
        alert.runModal()
    }

    private func formattedDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        return f.string(from: Date())
    }
}
