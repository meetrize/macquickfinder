import SwiftUI

struct ArchiveListPreview: View {
    let entries: [ArchiveEntryPreview]
    let truncated: Bool
    let expanded: Bool
    @Binding var copyAction: ArchivePreviewAction?

    private static let sizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .file
        return formatter
    }()

    private var displayedEntries: [ArchiveEntryPreview] {
        if expanded { return entries }

        var map: [String: Bool] = [:] // name -> isDirectory
        for e in entries {
            let comps = e.path.split(separator: "/")
            guard let first = comps.first else { continue }
            let name = String(first)
            let isDirAtTop = e.isDirectory || comps.count > 1
            map[name] = (map[name] ?? false) || isDirAtTop
        }

        let dirs = map.keys.filter { map[$0] == true }.sorted()
        let files = map.keys.filter { map[$0] == false }.sorted()
        return dirs.map { ArchiveEntryPreview(path: $0, isDirectory: true, size: nil) }
            + files.map { ArchiveEntryPreview(path: $0, isDirectory: false, size: nil) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(displayedEntries) { entry in
                    let comps = entry.path.split(separator: "/")
                    let depth = expanded ? max(0, comps.count - 1) : 0

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
                }

                if truncated && expanded {
                    Text(L10n.Preview.archiveTruncated)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 6)
                }
            }
        }
        .onChange(of: copyAction) { action in
            guard case .copyList? = action else { return }
            let lines = displayedEntries.map { e in
                if let size = e.size, !e.isDirectory {
                    return "\(e.path)\t\(Self.sizeFormatter.string(fromByteCount: size))"
                }
                return e.path
            }
            let text = lines.joined(separator: "\n")
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            DispatchQueue.main.async { copyAction = nil }
        }
    }
}
