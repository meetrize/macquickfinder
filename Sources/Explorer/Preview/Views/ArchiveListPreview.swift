import AppKit
import SwiftUI

struct ArchiveListPreview: View {
    let entries: [ArchiveEntryPreview]
    let truncated: Bool
    let isLoadingMore: Bool
    @Binding var expandedDirectoryPaths: Set<String>
    @Binding var selectedEntryPaths: Set<String>
    @Binding var copyAction: ArchivePreviewAction?

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()

    private var treeRoots: [ArchiveTreeNode] {
        ArchiveTreeBuilder.build(from: entries)
    }

    private var visibleRows: [ArchiveFlatRow] {
        ArchiveTreeBuilder.visibleRows(
            roots: treeRoots,
            expandedDirectoryPaths: expandedDirectoryPaths
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleRows) { row in
                        archiveRow(row)
                    }

                    if isLoadingMore {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.Preview.Archive.loadingMore)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 6)
                    } else if truncated {
                        Text(L10n.Preview.archiveTruncated)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .onChange(of: copyAction) { action in
            guard case .copyList? = action else { return }
            let lines = entries.map { entry in
                if let size = entry.size, !entry.isDirectory {
                    return "\(entry.path)\t\(Self.sizeFormatter.string(fromByteCount: size))"
                }
                return entry.path
            }
            let text = lines.joined(separator: "\n")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            DispatchQueue.main.async { copyAction = nil }
        }
    }

    @ViewBuilder
    private func archiveRow(_ row: ArchiveFlatRow) -> some View {
        let node = row.node
        let selectionPath = selectionPath(for: node)
        let isSelected = selectedEntryPaths.contains(selectionPath)

        HStack(alignment: .top, spacing: 4) {
            Color.clear.frame(width: CGFloat(row.depth) * 12)

            disclosureControl(for: row)

            Image(systemName: node.isDirectory ? "folder" : "doc")
                .foregroundColor(node.isDirectory ? .accentColor : .secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.name)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let size = node.size, !node.isDirectory {
                    Text(Self.sizeFormatter.string(fromByteCount: size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: selectionPath)
        }
    }

    @ViewBuilder
    private func disclosureControl(for row: ArchiveFlatRow) -> some View {
        if row.hasChildren {
            Button {
                toggleExpansion(for: row.node.fullPath)
            } label: {
                Image(systemName: row.isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help(row.isExpanded ? L10n.Preview.Toolbar.archiveCollapse : L10n.Preview.Toolbar.archiveExpand)
        } else {
            Color.clear.frame(width: 14, height: 14)
        }
    }

    private func selectionPath(for node: ArchiveTreeNode) -> String {
        if node.isDirectory {
            return node.fullPath + "/"
        }
        return node.fullPath
    }

    private func toggleExpansion(for path: String) {
        if expandedDirectoryPaths.contains(path) {
            expandedDirectoryPaths.remove(path)
        } else {
            expandedDirectoryPaths.insert(path)
        }
    }

    private func toggleSelection(for path: String) {
        let commandDown = NSEvent.modifierFlags.contains(.command)
        if commandDown {
            if selectedEntryPaths.contains(path) {
                selectedEntryPaths.remove(path)
            } else {
                selectedEntryPaths.insert(path)
            }
        } else {
            if selectedEntryPaths == [path] {
                selectedEntryPaths.removeAll()
            } else {
                selectedEntryPaths = [path]
            }
        }
    }
}
