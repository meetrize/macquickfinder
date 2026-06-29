import AppKit
import SwiftUI

struct ArchiveListPreview: View {
    let entries: [ArchiveEntryPreview]
    let truncated: Bool
    let expanded: Bool
    @Binding var selectedEntryPaths: Set<String>
    @Binding var copyAction: ArchivePreviewAction?

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()

    private var displayedEntries: [ArchiveEntryPreview] {
        if expanded { return entries }

        var map: [String: Bool] = [:]
        for entry in entries {
            let comps = entry.path.split(separator: "/")
            guard let first = comps.first else { continue }
            let name = String(first)
            let isDirAtTop = entry.isDirectory || comps.count > 1
            map[name] = (map[name] ?? false) || isDirAtTop
        }

        let dirs = map.keys.filter { map[$0] == true }.sorted()
        let files = map.keys.filter { map[$0] == false }.sorted()
        return dirs.map { ArchiveEntryPreview(path: $0, isDirectory: true, size: nil) }
            + files.map { ArchiveEntryPreview(path: $0, isDirectory: false, size: nil) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !selectedEntryPaths.isEmpty {
                Text(L10n.Preview.Archive.selectionCount(selectedEntryPaths.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.bottom, 6)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(displayedEntries) { entry in
                        archiveRow(entry)
                    }

                    if truncated && expanded {
                        Text(L10n.Preview.archiveTruncated)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 6)
                    }
                }
            }
        }
        .onChange(of: copyAction) { action in
            guard case .copyList? = action else { return }
            let lines = displayedEntries.map { entry in
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
    private func archiveRow(_ entry: ArchiveEntryPreview) -> some View {
        let comps = entry.path.split(separator: "/")
        let depth = expanded ? max(0, comps.count - 1) : 0
        let isSelected = selectedEntryPaths.contains(entry.path)

        HStack(alignment: .top, spacing: 8) {
            Color.clear.frame(width: CGFloat(depth) * 10)
            Image(systemName: entry.isDirectory ? "folder" : "doc")
                .foregroundColor(entry.isDirectory ? .accentColor : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.path)
                    .font(.system(size: 12, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let size = entry.size, !entry.isDirectory {
                    Text(Self.sizeFormatter.string(fromByteCount: size))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            toggleSelection(for: entry.path)
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
