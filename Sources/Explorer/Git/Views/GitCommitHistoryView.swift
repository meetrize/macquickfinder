import SwiftUI

struct GitCommitHistoryView: View {
    let commits: [GitCommitEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Git.History.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            if commits.isEmpty {
                Text(L10n.Git.History.empty)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(commits) { commit in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(commit.shortHash)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .leading)

                        Text(commit.subject)
                            .font(.callout)
                            .lineLimit(2)
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
