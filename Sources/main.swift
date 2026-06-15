import SwiftUI
import AppKit
import PDFKit

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

private struct LucideIcon: View {
    let svgData: Data
    var size: CGFloat = 16

    static let folderPlus = LucideIcon(
        svgData: Data(
            """
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 10v6"/><path d="M9 13h6"/><path d="M20 20a2 2 0 0 0 2-2V8a2 2 0 0 0-2-2h-7.9a2 2 0 0 1-1.69-.9L9.6 3.9A2 2 0 0 0 7.93 3H4a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2Z"/></svg>
            """.utf8
        )
    )

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
    @State private var showPreview = true
    
    var body: some Scene {
        WindowGroup {
            ContentView(showPreview: $showPreview)
                .frame(minWidth: 800, minHeight: 600)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
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
    
    var body: some View {
        NavigationSplitView {
            SidebarView(path: $path)
        } detail: {
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
                            onItemOpen: openItem,
                            onBlankDoubleClick: handleBlankDoubleClick
                        )
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
                    Divider()
                    FilePreviewView(
                        showPreview: $showPreview,
                        selection: selection,
                        items: items
                    )
                        .frame(minWidth: 240, idealWidth: 320)
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
        if item.isDirectory {
            path = item.url.path
        } else {
            NSWorkspace.shared.open(item.url)
        }
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
    @State private var devices: [SidebarVolume] = []
    
    private let favoriteLocations = [
        SidebarItem(name: "Home", path: FileManager.default.homeDirectoryForCurrentUser.path, icon: "house"),
        SidebarItem(name: "Desktop", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop").path, icon: "desktopcomputer"),
        SidebarItem(name: "Documents", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents").path, icon: "doc"),
        SidebarItem(name: "Downloads", path: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path, icon: "arrow.down.circle")
    ]
    
    var body: some View {
        List {
            Section("Favorites") {
                ForEach(favoriteLocations) { location in
                    SidebarRow(
                        title: location.name,
                        icon: location.icon,
                        isSelected: isSelected(location.path)
                    ) {
                        path = location.path
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

struct FileListView: View {
    let items: [FileItem]
    @Binding var selection: Set<FileItem.ID>
    @Binding var tableSortOrder: [KeyPathComparator<FileItem>]
    let onItemOpen: (FileItem) -> Void
    let onBlankDoubleClick: () -> Void
    
    var body: some View {
        Table(items, selection: $selection, sortOrder: $tableSortOrder) {
            TableColumn("Name", value: \.name) { (item: FileItem) in
                HStack {
                    Image(systemName: item.isDirectory ? "folder" : "doc")
                        .foregroundColor(item.isDirectory ? .blue : .gray)
                        .opacity(item.isHidden ? 0.6 : 1.0)
                    Text(item.name)
                        .fontWeight(item.isDirectory ? .medium : .regular)
                        .opacity(item.isHidden ? 0.6 : 1.0)
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
        .transaction { transaction in
            transaction.animation = nil
        }
        .tableStyle(.inset)
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

struct SidebarItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let icon: String
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