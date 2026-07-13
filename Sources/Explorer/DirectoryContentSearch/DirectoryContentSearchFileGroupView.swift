import AppKit
import SwiftUI

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

struct DirectoryContentSearchFileGroupView: View {
    let group: ContentSearchFileGroup
    let query: String
    let selectedMatchID: UUID?
    let onToggleExpansion: () -> Void
    let onSelectMatch: (ContentSearchMatch) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggleExpansion) {
                HStack(spacing: 8) {
                    Image(systemName: group.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 12)

                    Image(nsImage: NSWorkspace.shared.icon(forFile: group.fileURL.path))
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
                        DirectoryContentSearchMatchRowView(
                            match: match,
                            query: query,
                            isSelected: selectedMatchID == match.id
                        )
                        .id(match.id)
                        .onTapGesture {
                            onSelectMatch(match)
                        }
                    }
                }
                .padding(.leading, 20)
            }
        }
    }
}
