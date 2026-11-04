import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// 搜索结果里数百个文件组会反复请求图标；按扩展名缓存，避免主线程反复做磁盘图标解析。
@MainActor
private enum ContentSearchFileIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL) -> NSImage {
        let ext = url.pathExtension.lowercased()
        let key = ext.isEmpty ? "<none>" : ext
        if let cached = cache[key] { return cached }

        let type = UTType(filenameExtension: ext) ?? .data
        let image = NSWorkspace.shared.icon(for: type)
        cache[key] = image
        return image
    }
}

struct DirectoryContentSearchMatchRowView: View {
    let match: ContentSearchMatch
    let query: String
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(match.lineNumber)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(minWidth: 32, alignment: .trailing)

            Text("│")
                .font(.caption.monospaced())
                .foregroundStyle(.quaternary)

            highlightedSnippet
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .contentShape(Rectangle())
    }

    private var highlightedSnippet: Text {
        let line = match.lineText
        let nsLine = line as NSString
        let range = NSRange(location: match.matchStartUTF16, length: match.matchLengthUTF16)
        guard NSMaxRange(range) <= nsLine.length,
              let stringRange = Range(range, in: line) else {
            return Text(line)
        }

        var attributed = AttributedString(line)
        if let attributedRange = Range(stringRange, in: attributed) {
            attributed[attributedRange].backgroundColor = .yellow.opacity(0.35)
        }
        return Text(attributed)
    }
}

/// 只注册一个单击手势：单击立即选中，用系统双击间隔自行判定双击。
/// 同时注册 `onTapGesture(count: 2)` 与 `count: 1` 会让单击等待双击超时（约 0.5s）。
private struct ContentSearchMatchRow: View {
    let match: ContentSearchMatch
    let query: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void

    @State private var lastClickUptime: TimeInterval = 0

    var body: some View {
        DirectoryContentSearchMatchRowView(
            match: match,
            query: query,
            isSelected: isSelected
        )
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
    }

    private func handleTap() {
        let now = ProcessInfo.processInfo.systemUptime
        let isDoubleClick = lastClickUptime > 0
            && now - lastClickUptime <= NSEvent.doubleClickInterval

        if isDoubleClick {
            lastClickUptime = 0
            onOpen()
        } else {
            lastClickUptime = now
            onSelect()
        }
    }
}

struct DirectoryContentSearchFileGroupView: View {
    let group: ContentSearchFileGroup
    let query: String
    let selectedMatchID: UUID?
    let onToggleExpansion: () -> Void
    let onSelectMatch: (ContentSearchMatch) -> Void
    let onOpenMatch: (ContentSearchMatch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpansion) {
                HStack(spacing: 8) {
                    Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(nsImage: ContentSearchFileIconCache.icon(for: group.fileURL))
                        .resizable()
                        .frame(width: 16, height: 16)

                    Text(group.fileURL.lastPathComponent)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)

                    if !group.relativePath.isEmpty, group.relativePath != group.fileURL.lastPathComponent {
                        Text(group.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    Text("\(group.matches.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if group.isExpanded {
                VStack(spacing: 0) {
                    ForEach(group.matches) { match in
                        ContentSearchMatchRow(
                            match: match,
                            query: query,
                            isSelected: selectedMatchID == match.id,
                            onSelect: { onSelectMatch(match) },
                            onOpen: { onOpenMatch(match) }
                        )
                        .id(match.id)
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
}
