import FileList
import SwiftUI

struct FolderPreviewView: View {
    let folder: FileItem
    let showHiddenFiles: Bool
    let autoCalculateDirectorySizes: Bool
    @ObservedObject var sizeOverlay: DirectorySizeOverlay
    @ObservedObject var countOverlay: DirectoryItemCountOverlay
    let showContentsList: Bool
    let onNavigate: (String) -> Void
    let onOpenFolder: () -> Void
    let onOpenTerminal: () -> Void
    let onPreviewChild: (FileItem) -> Void
    let onOpenChild: (FileItem) -> Void

    @State private var loadGeneration: UInt = 0
    @State private var loadResult: FolderPreviewLoader.LoadResult?
    @State private var isLoadingContents = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            folderSummary
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            if showContentsList {
                Divider()
                contentsSection
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: folder.id) {
            await scheduleMetadata()
            guard showContentsList else { return }
            await loadContents()
        }
    }

    // MARK: - Phase A: Summary

    private var folderSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: folderIconName)
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
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
                Button("打开", action: onOpenFolder)
                    .controlSize(.small)

                Button("在终端中打开", action: onOpenTerminal)
                    .controlSize(.small)

                Button("复制路径") {
                    copyPathToPasteboard()
                }
                .controlSize(.small)
            }
            .buttonStyle(.bordered)
        }
    }

    private var folderIconName: String {
        let ext = folder.url.pathExtension.lowercased()
        if folder.isDirectory, ext == "app" {
            return "app"
        }
        return "folder.fill"
    }

    private var metadataLine: String {
        var parts: [String] = []
        parts.append(itemCountText)

        if !folder.dateDisplay.isEmpty {
            parts.append("修改于 \(folder.dateDisplay)")
        }

        let sizeText = directorySizeText
        if !sizeText.isEmpty {
            parts.append(sizeText)
        }

        return parts.joined(separator: " · ")
    }

    private var itemCountText: String {
        let overlayCount = countOverlay.countDisplay(for: folder.id)
        if overlayCount.count >= 0 {
            return formatItemCount(overlayCount.count)
        }
        if let total = loadResult?.totalCount, total > 0 || loadResult?.errorMessage == nil {
            return formatItemCount(total)
        }
        if isLoadingContents {
            return "正在统计…"
        }
        return "— 项"
    }

    private func formatItemCount(_ count: Int) -> String {
        "\(count) 项"
    }

    private var directorySizeText: String {
        let display = sizeOverlay.sizeDisplay(for: folder.id)
        if display.sortableSize < 0 {
            return autoCalculateDirectorySizes ? "大小计算中…" : ""
        }
        return "大小 \(display.text)"
    }

    // MARK: - Phase B: Contents

    @ViewBuilder
    private var contentsSection: some View {
        if isLoadingContents, loadResult == nil {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("正在加载内容…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(12)
        } else if let error = loadResult?.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
        } else if let result = loadResult, result.children.isEmpty {
            Text("文件夹为空")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(12)
        } else if let result = loadResult {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("内容")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if result.truncated {
                        Text("显示前 \(FolderPreviewLoader.maxChildren) / \(result.totalCount) 项")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 4)

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
                    .padding(.horizontal, 8)
                    .padding(.bottom, 10)
                }
            }
        }
    }

    private func scheduleMetadata() async {
        guard !TrashLoader.isTrashPath(folder.id) else { return }
        if !FileListApplicationBundle.isBundle(path: folder.id) {
            await DirectoryItemCountService.shared.schedule(
                paths: [folder.id],
                showHiddenFiles: showHiddenFiles,
                priority: .visible
            )
        }
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
                totalCount: 0,
                truncated: false,
                errorMessage: "废纸篓中的文件夹不支持预览内容"
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
        guard generation == loadGeneration, folder.id == folder.id else { return }
        loadResult = result
    }

    private func handlePreviewChild(_ child: FileItem) {
        if child.isDirectory, isAppBundle(child) {
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
            if isAppBundle(child) {
                onOpenChild(child)
            } else {
                onNavigate(child.id)
            }
            return
        }
        onOpenChild(child)
    }

    private func isAppBundle(_ item: FileItem) -> Bool {
        item.isDirectory && item.url.pathExtension.lowercased() == "app"
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
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.001))
        )
        .onTapGesture(perform: onPreview)
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen() })
        .instantHoverTooltip(item.isDirectory ? "双击进入" : "单击预览 · 双击打开")
    }

    private var iconName: String {
        if item.isDirectory {
            return item.url.pathExtension.lowercased() == "app" ? "app" : "folder"
        }
        return "doc"
    }
}
