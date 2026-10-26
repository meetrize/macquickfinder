import AppKit
import FileList
import SwiftUI

struct FolderPreviewView: View {
    let folder: FileItem
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    @ObservedObject var metadataOverlay: DirectoryMetadataOverlay
    let showContentsList: Bool
    let onNavigate: (String) -> Void
    let onOpenFolder: () -> Void
    let onOpenTerminal: () -> Void
    let onPreviewChild: (FileItem) -> Void
    let onOpenChild: (FileItem) -> Void

    @State private var loadGeneration: UInt = 0
    @State private var loadResult: FolderPreviewLoader.LoadResult?
    @State private var isLoadingContents = false
    @State private var appIcon: NSImage?
    @State private var appSnapshot: AppBundlePreviewInfo.Snapshot?

    private var isApplicationBundle: Bool {
        FileListApplicationBundle.isBundle(path: folder.id)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderSummary

            if showContentsList, !isApplicationBundle {
                Divider()
                contentsSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: folder.id) {
            await prepareLightweightChrome()
            await scheduleMetadata()
            guard showContentsList, !isApplicationBundle else { return }
            await loadContents()
        }
    }

    // MARK: - Phase A: Summary

    private var folderSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                folderGlyph
                    .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(folder.name)
                        .font(.headline)
                        .lineLimit(2)

                    Text(metadataLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            HStack(spacing: 8) {
                Button(L10n.Preview.Folder.open, action: onOpenFolder)
                    .controlSize(.small)

                Button(L10n.Preview.Folder.openTerminal, action: onOpenTerminal)
                    .controlSize(.small)

                Button(L10n.Preview.Folder.copyPath) {
                    copyPathToPasteboard()
                }
                .controlSize(.small)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var folderGlyph: some View {
        if let appIcon {
            Image(nsImage: appIcon)
                .resizable()
                .interpolation(.high)
                .frame(width: 44, height: 44)
        } else {
            Image(systemName: folderIconName)
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
        }
    }

    private var folderIconName: String {
        if isApplicationBundle {
            return "app"
        }
        return "folder.fill"
    }

    private var metadataLine: String {
        var parts: [String] = []
        parts.append(itemCountText)

        if isApplicationBundle, let versionLabel = appVersionLabel {
            parts.append(versionLabel)
        }

        if !folder.dateDisplay.isEmpty {
            parts.append(L10n.Preview.Folder.modified(folder.dateDisplay))
        }

        let sizeText = directorySizeText
        if !sizeText.isEmpty {
            parts.append(sizeText)
        }

        return parts.joined(separator: " · ")
    }

    private var appVersionLabel: String? {
        guard let snapshot = appSnapshot else { return nil }
        if let short = snapshot.shortVersion {
            return L10n.Preview.Folder.appVersion(short)
        }
        if let version = snapshot.version {
            return L10n.Preview.Folder.appVersion(version)
        }
        return nil
    }

    private var resolvedItemCount: Int? {
        FolderPreviewItemCountDisplay.resolvedCount(from: metadataOverlay, path: folder.id)
    }

    private var itemCountText: String {
        FolderPreviewItemCountDisplay.summaryText(
            count: resolvedItemCount,
            isApplicationBundle: isApplicationBundle
        )
    }

    private var directorySizeText: String {
        // 文件包不再自动算大小，避免 /Applications 下预览卡顿。
        guard !isApplicationBundle else { return "" }
        let display = metadataOverlay.sizeDisplay(for: folder.id)
        if display.sortableSize < 0 {
            return autoCalculateDirectorySizes ? L10n.Preview.Folder.sizeCalculating : ""
        }
        return L10n.Preview.Folder.size(display.text)
    }

    // MARK: - Phase B: Contents

    @ViewBuilder
    private var contentsSection: some View {
        if isLoadingContents, loadResult == nil {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.Preview.Folder.loadingContents)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let error = loadResult?.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let result = loadResult, result.children.isEmpty {
            Text(L10n.Preview.Folder.empty)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else if let result = loadResult {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(L10n.Preview.Folder.contents)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if result.truncated {
                        Text(
                            FolderPreviewItemCountDisplay.truncationCaption(
                                maxChildren: FolderPreviewLoader.maxChildren,
                                totalCount: resolvedItemCount
                            )
                        )
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(result.children) { child in
                            FolderPreviewChildRow(item: child) {
                                handlePreviewChild(child)
                            } onOpen: {
                                handleOpenChild(child)
                            }
                        }
                    }
                }
            }
        }
    }

    private func prepareLightweightChrome() async {
        appIcon = nil
        appSnapshot = nil
        guard isApplicationBundle else { return }
        let path = folder.id
        let prepared = await Task.detached(priority: .userInitiated) {
            let icon = AppBundlePreviewInfo.workspaceIcon(at: path)
            let snapshot = AppBundlePreviewInfo.loadSnapshot(at: path)
            return (icon, snapshot)
        }.value
        guard path == folder.id else { return }
        appIcon = prepared.0
        appSnapshot = prepared.1
    }

    private func scheduleMetadata() async {
        guard !TrashLoader.isTrashPath(folder.id) else { return }
        // 文件包：不算子项数、不算递归大小（与主列表 visibleDirectoryPaths 策略一致）。
        guard !isApplicationBundle else { return }
        await DirectoryItemCountService.shared.schedule(
            paths: [folder.id],
            showHiddenFiles: showHiddenFiles,
            priority: .visible
        )
        if autoCalculateDirectorySizes {
            await DirectorySizeService.shared.schedule(
                paths: [folder.id],
                showHiddenFiles: showHiddenFiles,
                priority: .visible
            )
        }
    }

    private func loadContents() async {
        guard !TrashLoader.isTrashPath(folder.id) else {
            loadResult = FolderPreviewLoader.LoadResult(
                children: [],
                truncated: false,
                errorMessage: L10n.Preview.Folder.trashUnsupported
            )
            return
        }

        let generation = loadGeneration &+ 1
        loadGeneration = generation
        isLoadingContents = true
        defer {
            if generation == loadGeneration {
                isLoadingContents = false
            }
        }

        let result = await FolderPreviewLoader.load(
            at: folder.id,
            showHiddenFiles: showHiddenFiles
        )
        guard generation == loadGeneration else { return }
        loadResult = result
    }

    private func handlePreviewChild(_ child: FileItem) {
        if child.isDirectory, child.isApplicationBundle {
            onOpenChild(child)
            return
        }
        if child.isDirectory {
            return
        }
        onPreviewChild(child)
    }

    private func handleOpenChild(_ child: FileItem) {
        if child.isDirectory {
            if child.isApplicationBundle {
                onOpenChild(child)
            } else {
                onNavigate(child.id)
            }
            return
        }
        onOpenChild(child)
    }

    private func copyPathToPasteboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(folder.id, forType: .string)
    }
}

private struct FolderPreviewChildRow: View {
    let item: FileItem
    let onPreview: () -> Void
    let onOpen: () -> Void

    @State private var isHovered = false
    @Environment(\.colorScheme) private var colorScheme

    private var rowBackground: Color {
        if isHovered {
            return Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05)
        }
        return .clear
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(item.isDirectory ? Color.accentColor : .secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 6) {
                    if !item.isDirectory, !item.sizeDisplay.isEmpty {
                        Text(item.sizeDisplay)
                    }
                    if !item.dateDisplay.isEmpty {
                        Text(item.dateDisplay)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(rowBackground)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture(perform: onPreview)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
        .instantHoverTooltip(item.isDirectory ? L10n.Preview.FolderInlineChild.openDirectory : L10n.Preview.FolderInlineChild.previewFile)
        .animation(.easeOut(duration: 0.12), value: isHovered)
    }

    private var iconName: String {
        if item.isDirectory {
            return item.url.pathExtension.lowercased() == "app" ? "app" : "folder"
        }
        return "doc"
    }
}
