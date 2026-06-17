import SwiftUI

struct SnippetListItemView: View {
    let snippet: Snippet
    let isSelected: Bool
    let onExecute: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onSelect) {
                HStack(spacing: 6) {
                    Text(snippet.name)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    if let badge = snippet.scope.shortBadge {
                        Text(badge)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(snippetContentPreview(snippet.content))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button(action: onExecute) {
                Image(systemName: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("执行")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
    }
}
