import SwiftUI

struct GitCommitHistoryView: View {
    let commits: [GitCommitEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Git.History.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if commits.isEmpty {
                Text(L10n.Git.History.empty)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(commits) { commit in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(commit.shortHash)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 48, alignment: .leading)

                        Text(commit.subject)
                            .font(.caption)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(commit.relativeDate)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}
