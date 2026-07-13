import SwiftUI

struct DirectoryContentSearchSummaryBar: View {
    let progress: ContentSearchProgress
    let fileCount: Int
    let currentIndex: Int?
    let onNextMatch: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if progress.isComplete {
                Text(summaryText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                ProgressView()
                    .controlSize(.small)
                Text(progressText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if progress.matchCount > 0 {
                Button(L10n.Search.contentNextMatch, action: onNextMatch)
                    .buttonStyle(.borderless)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var summaryText: String {
        if progress.matchCount == 0 {
            return L10n.Search.contentNoResults
        }

        var parts = [
            L10n.Search.contentSummaryFiles(fileCount),
            L10n.Search.contentSummaryMatches(progress.matchCount),
            L10n.Search.contentSummaryElapsed(progress.elapsed),
        ]
        if let currentIndex, progress.matchCount > 1 {
            parts.append(L10n.Search.contentSummaryPosition(currentIndex + 1, progress.matchCount))
        }
        if progress.wasTruncated {
            parts.append(L10n.Search.contentTruncated)
        }
        if progress.wasCancelled {
            parts.append(L10n.Search.contentCancelled)
        }
        return parts.joined(separator: " · ")
    }

    private var progressText: String {
        if let total = progress.totalFileCount {
            return L10n.Search.contentProgress(
                scanned: progress.scannedFileCount,
                total: total,
                matches: progress.matchCount
            )
        }
        return L10n.Search.contentSearchingMatches(progress.matchCount)
    }
}
