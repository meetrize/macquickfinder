import SwiftUI
import FileList

struct GitPanelView: View {
    @Binding var showGit: Bool
    @ObservedObject var layout: ExplorerWindowLayoutState
    @ObservedObject var gitStatusStore: GitStatusStore

    let selection: Set<FileItem.ID>
    let items: [FileItem]
    let cwd: String
    var showsTopSeparator: Bool = false
    var onRevealPath: (String) -> Void = { _ in }

    @State private var showsAllChanges = false
    @State private var commitMessage = ""
    @State private var isOperating = false
    @State private var lastOperationError: String?
    @State private var showLargeCommitConfirm = false
    @State private var pendingOperationKind: GitPanelOperationKind?
    @FocusState private var commitFieldFocused: Bool

    private var isInRepository: Bool {
        GitRepositoryDetector.findRepoRoot(from: cwd) != nil
    }

    private var commitScope: GitCommitScope {
        .allChanges
    }

    var body: some View {
        VStack(spacing: 0) {
            if layout.isGitContentCollapsed {
                Spacer(minLength: 0)
                Divider()
                topBar
            } else {
                if showsTopSeparator {
                    Divider()
                }
                topBar
                if let displaySnapshot {
                    statusStrip(displaySnapshot)
                    Divider()
                }
                panelBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            refreshIfNeeded(force: true)
        }
        .onChange(of: cwd) { _ in
            showsAllChanges = false
            lastOperationError = nil
            if isInRepository {
                Task { await gitStatusStore.refresh(cwd: cwd) }
            } else {
                gitStatusStore.clear()
            }
        }
        .onChange(of: layout.showGit) { isVisible in
            guard isVisible else { return }
            refreshIfNeeded(force: true)
        }
        .alert(
            L10n.Git.Commit.largeCommitTitle(pendingLargeCommitCount),
            isPresented: $showLargeCommitConfirm
        ) {
            Button(L10n.Action.cancel, role: .cancel) {
                pendingOperationKind = nil
            }
            Button(L10n.Action.ok) {
                guard let kind = pendingOperationKind else { return }
                pendingOperationKind = nil
                Task { await runOperation(kind) }
            }
        } message: {
            Text(L10n.Git.Commit.largeCommitMessage)
        }
    }

    private var pendingLargeCommitCount: Int {
        displaySnapshot?.changeCount ?? 0
    }

    private var topBar: some View {
        HStack(spacing: 6) {
            Button {
                layout.isGitContentCollapsed.toggle()
            } label: {
                Image(systemName: layout.isGitContentCollapsed ? "chevron.up" : "chevron.down")
            }
            .buttonStyle(.borderless)
            .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
            .contentShape(Rectangle())
            .instantHoverTooltip(
                layout.isGitContentCollapsed ? L10n.Git.Panel.expand : L10n.Git.Panel.collapse
            )

            Text(L10n.Git.Panel.title)
                .font(.callout)
                .fontWeight(.medium)

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button {
                    Task { await gitStatusStore.refresh(cwd: cwd) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(gitStatusStore.isRefreshing ? 360 : 0))
                        .animation(
                            gitStatusStore.isRefreshing
                                ? .linear(duration: 1).repeatForever(autoreverses: false)
                                : .default,
                            value: gitStatusStore.isRefreshing
                        )
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(L10n.Git.Panel.refresh)
                .disabled(gitStatusStore.isRefreshing || isOperating)

                Button { showGit = false } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .frame(width: 22, height: PanelTopBarMetrics.contentHeight)
                .contentShape(Rectangle())
                .instantHoverTooltip(L10n.Git.Panel.close)
            }
        }
        .frame(height: PanelTopBarMetrics.contentHeight)
        .padding(.horizontal, 10)
        .padding(.vertical, PanelTopBarMetrics.verticalPadding)
    }

    private func statusStrip(_ snapshot: GitWorkspaceSnapshot) -> some View {
        Text(GitStatusPresentation.statusStrip(snapshot: snapshot))
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }

    @ViewBuilder
    private var panelBody: some View {
        if !isInRepository {
            notRepositoryBody
        } else if gitStatusStore.isRefreshing, displaySnapshot == nil {
            loadingBody
        } else if let error = gitStatusStore.lastError, displaySnapshot == nil {
            errorBody(error)
        } else if let displaySnapshot {
            snapshotBody(displaySnapshot)
        } else if isInRepository {
            retryBody
        } else {
            loadingBody
        }
    }

    private var displaySnapshot: GitWorkspaceSnapshot? {
        guard let snapshot = gitStatusStore.snapshot else { return nil }
        guard snapshotBelongsToCurrentRepository(snapshot) else { return nil }
        return snapshot
    }

    private var retryBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.Git.Panel.placeholder)
                .font(.callout)
                .foregroundStyle(.secondary)
            Button {
                Task { await gitStatusStore.refresh(cwd: cwd) }
            } label: {
                Text(L10n.Git.Panel.refresh)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            Task { await gitStatusStore.refresh(cwd: cwd) }
        }
    }

    private var notRepositoryBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Git.Empty.notRepo)
                .foregroundStyle(.secondary)
                .font(.callout)

            Button {
                Task { await runInitRepository() }
            } label: {
                if isOperating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(L10n.Git.Empty.initRepository)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isOperating)

            if let lastOperationError {
                Text(lastOperationError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var loadingBody: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text(L10n.Git.Panel.refresh)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(12)
    }

    private func errorBody(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func snapshotBody(_ snapshot: GitWorkspaceSnapshot) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    statusCard(snapshot)
                    if !snapshot.entries.isEmpty {
                        changeList(snapshot)
                    }
                    commitHistory(snapshot)
                    if let lastOperationError {
                        Text(lastOperationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            actionFooter(snapshot)
        }
    }

    private func statusCard(_ snapshot: GitWorkspaceSnapshot) -> some View {
        let phase = snapshot.workspacePhase
        return HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(GitStatusPresentation.cardColor(for: phase))
                .frame(width: 10, height: 10)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(GitStatusPresentation.cardTitle(for: phase, snapshot: snapshot))
                    .font(.callout)
                    .fontWeight(.medium)
                if phase == .cleanSynced, let refreshedAt = formattedRefreshTime(snapshot.lastRefreshedAt) {
                    Text(refreshedAt)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 1)
        }
    }

    private func changeList(_ snapshot: GitWorkspaceSnapshot) -> some View {
        let listing = GitStatusPresentation.visibleEntries(
            from: snapshot.entries,
            showsAll: showsAllChanges
        )

        return VStack(alignment: .leading, spacing: 6) {
            Text(L10n.Git.Status.pendingCommit)
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(listing.visible) { entry in
                GitChangeRowView(entry: entry) {
                    let absolute = GitStatusPresentation.absolutePath(for: entry, repoRoot: snapshot.repoRoot)
                    onRevealPath(absolute)
                }
            }

            if listing.remainingCount > 0 {
                Button {
                    showsAllChanges = true
                } label: {
                    Text(L10n.Git.Status.moreChanges(listing.remainingCount))
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func commitHistory(_ snapshot: GitWorkspaceSnapshot) -> some View {
        GitCommitHistoryView(commits: snapshot.recentCommits)
    }

    private func actionFooter(_ snapshot: GitWorkspaceSnapshot) -> some View {
        let primary = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: isOperating)
        let showCommitField = snapshot.changeCount > 0

        return VStack(alignment: .leading, spacing: 10) {
            if showCommitField {
                Text(L10n.Git.Commit.scopeAll)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    TextField(L10n.Git.Commit.placeholder, text: $commitMessage)
                        .textFieldStyle(.roundedBorder)
                        .focused($commitFieldFocused)

                    Button {} label: {
                        Image(systemName: "sparkles")
                    }
                    .buttonStyle(.borderless)
                    .disabled(true)
                    .instantHoverTooltip(L10n.Git.Commit.aiTooltip)
                }
            }

            if let primary {
                Button {
                    handlePrimaryAction(primary)
                } label: {
                    if isOperating {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.Git.Action.working)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Text(primary.title)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!primary.isEnabled || isOperating)
                .instantHoverTooltip(primary.disabledReason ?? "")
            }

            HStack(spacing: 16) {
                Button {
                    Task { await runOperation(.pull) }
                } label: {
                    Text(L10n.Git.Action.pull)
                }
                .buttonStyle(.plain)
                .disabled(!GitPanelActionPlanner.canPull(snapshot: snapshot) || isOperating)
                .instantHoverTooltip(GitPanelActionPlanner.pullDisabledReason(snapshot: snapshot) ?? "")

                Button {
                    requestOperation(.commit)
                } label: {
                    Text(L10n.Git.Action.commitOnly)
                }
                .buttonStyle(.plain)
                .disabled(!GitPanelActionPlanner.canCommitOnly(snapshot: snapshot, isOperating: isOperating))
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func handlePrimaryAction(_ action: GitPanelPrimaryAction) {
        requestOperation(action.kind)
    }

    private func requestOperation(_ kind: GitPanelOperationKind) {
        guard let displaySnapshot else { return }

        if kind == .commit || kind == .commitAndSync,
           GitPanelActionPlanner.shouldConfirmLargeCommit(changeCount: displaySnapshot.changeCount) {
            pendingOperationKind = kind
            showLargeCommitConfirm = true
            return
        }

        Task { await runOperation(kind) }
    }

    @MainActor
    private func runOperation(_ kind: GitPanelOperationKind) async {
        guard let displaySnapshot else { return }
        guard !isOperating else { return }

        isOperating = true
        lastOperationError = nil
        defer { isOperating = false }

        let error: String?
        switch kind {
        case .sync:
            error = await GitService.sync(
                snapshot: displaySnapshot,
                cwd: cwd,
                layout: layout,
                statusStore: gitStatusStore
            )
        case .pull:
            error = await GitService.pull(
                snapshot: displaySnapshot,
                cwd: cwd,
                layout: layout,
                statusStore: gitStatusStore
            )
        case .commit:
            error = await GitService.commit(
                snapshot: displaySnapshot,
                cwd: cwd,
                commitMessage: commitMessage,
                scope: commitScope,
                layout: layout,
                statusStore: gitStatusStore
            )
            if error == nil {
                commitMessage = ""
            }
        case .push:
            error = await GitService.push(
                snapshot: displaySnapshot,
                cwd: cwd,
                layout: layout,
                statusStore: gitStatusStore
            )
        case .commitAndSync:
            error = await GitService.commitAndSync(
                snapshot: displaySnapshot,
                cwd: cwd,
                commitMessage: commitMessage,
                scope: commitScope,
                layout: layout,
                statusStore: gitStatusStore
            )
            if error == nil {
                commitMessage = ""
            }
        case .initRepository:
            error = await GitService.initRepository(
                cwd: cwd,
                layout: layout,
                statusStore: gitStatusStore
            )
        }

        if let error {
            lastOperationError = error
            if error == L10n.Git.Error.emptyCommitMessage {
                commitFieldFocused = true
            }
        } else {
            showsAllChanges = false
        }
    }

    @MainActor
    private func runInitRepository() async {
        isOperating = true
        lastOperationError = nil
        defer { isOperating = false }

        if let error = await GitService.initRepository(
            cwd: cwd,
            layout: layout,
            statusStore: gitStatusStore
        ) {
            lastOperationError = error
        }
    }

    private func refreshIfNeeded(force: Bool) {
        guard isInRepository || force else {
            gitStatusStore.clear()
            return
        }
        if force {
            Task { await gitStatusStore.refresh(cwd: cwd) }
        } else {
            gitStatusStore.scheduleRefresh(cwd: cwd)
        }
    }

    private func snapshotBelongsToCurrentRepository(_ snapshot: GitWorkspaceSnapshot) -> Bool {
        guard let repoRoot = GitRepositoryDetector.findRepoRoot(from: cwd) else { return false }
        return GitRepositoryDetector.rootsEqual(snapshot.repoRoot, repoRoot)
    }

    private func formattedRefreshTime(_ date: Date) -> String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
