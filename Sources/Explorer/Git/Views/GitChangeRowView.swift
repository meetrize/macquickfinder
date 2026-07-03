import SwiftUI

struct GitChangeRowView: View {
    let entry: GitPorcelainEntry
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(GitStatusPresentation.statusBadge(for: entry.status))
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(GitStatusPresentation.statusBadgeColor(for: entry.status))
                    .frame(width: 14, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(GitStatusPresentation.displayName(for: entry))
                        .font(.callout)
                        .lineLimit(1)
                    if entry.status == .renamed, let oldPath = entry.oldPath {
                        Text(oldPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else if entry.path.contains("/") {
                        Text(entry.path)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
