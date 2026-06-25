import SwiftUI
import AppKit
import FileList

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

private struct FavoritesSidebarRows: View {
    @ObservedObject var favoritesStore: FavoritesStore
    @Binding var path: String
    var showsTitle: Bool
    var isSelected: (String) -> Bool
    var onDropURLs: ([URL], String, Bool, Int?) -> Void
    
    private var listHeight: CGFloat {
        CGFloat(favoritesStore.items.count) * FavoriteSidebarRailLayout.rowHeight
    }
    
    var body: some View {
        Group {
            if showsTitle {
                GeometryReader { geometry in
                    favoritesHost(availableWidth: geometry.size.width)
                        .frame(
                            width: geometry.size.width,
                            height: listHeight,
                            alignment: .topLeading
                        )
                }
                .frame(height: listHeight)
            } else {
                favoritesHost(availableWidth: FavoriteSidebarRailLayout.contentWidth)
                    .frame(width: FavoriteSidebarRailLayout.contentWidth)
                    .frame(
                        maxWidth: FavoriteSidebarRailLayout.contentWidth,
                        alignment: .center
                    )
            }
        }
    }
    
    private func favoritesHost(availableWidth: CGFloat) -> some View {
        FavoritesSidebarHost(
            favoritesStore: favoritesStore,
            path: $path,
            showsTitle: showsTitle,
            availableWidth: availableWidth,
            isSelected: isSelected,
            onDropURLs: onDropURLs
        )
        .id(showsTitle)
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
                sidebarSection(L10n.Sidebar.favorites) {
                    FavoritesSidebarRows(
                        favoritesStore: favoritesStore,
                        path: $path,
                        showsTitle: true,
                        isSelected: isSelected,
                        onDropURLs: handleFavoriteDrop
                    )
                }
                
                sidebarSection(L10n.Sidebar.devices) {
                    if devices.isEmpty {
                        Text(L10n.Sidebar.noDevices)
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
                                        .instantHoverTooltip(L10n.Sidebar.ejectDevice(device.name))
                                    }
                                }
                            )
                        }
                    }
                }
                
                sidebarSection(L10n.Sidebar.locations) {
                    SidebarRow(
                        title: TrashLoader.displayName,
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
        FavoritesSidebarDropHandler.handle(
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
                    title: TrashLoader.displayName,
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
        FavoritesSidebarDropHandler.handle(
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
                        .lineLimit(1)
                        .truncationMode(.tail)
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
