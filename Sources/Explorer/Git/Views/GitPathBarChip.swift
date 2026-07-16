import SwiftUI

struct GitPathBarChip: View {
    @ObservedObject var gitStatusStore: GitStatusStore
    @Binding var showGit: Bool

    let cwd: String

    private var isInRepository: Bool {
        GitRepositoryDetector.findRepoRoot(from: cwd) != nil
    }

    private var label: String? {
        guard let snapshot = gitStatusStore.snapshot else {
            // 面板未打开时不预刷 git status；仓库内仍显示可点入口。
            guard isInRepository else { return nil }
            if gitStatusStore.isRefreshing { return "…" }
            return "Git"
        }
        guard snapshotBelongsToCurrentRepository(snapshot) else {
            return isInRepository ? "Git" : nil
        }
        return GitStatusPresentation.chipLabel(snapshot: snapshot)
    }

    var body: some View {
        if let label {
            Button {
                showGit = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 10, weight: .semibold))
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background {
                    Capsule(style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .instantHoverTooltip(L10n.Git.Panel.title)
        }
    }

    private func snapshotBelongsToCurrentRepository(_ snapshot: GitWorkspaceSnapshot) -> Bool {
        guard let repoRoot = GitRepositoryDetector.findRepoRoot(from: cwd) else { return false }
        return GitRepositoryDetector.rootsEqual(snapshot.repoRoot, repoRoot)
    }
}
