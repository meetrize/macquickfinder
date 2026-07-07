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

    @State private var showsPendingChanges = true
    @State private var showsCommitHistory = false
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
                topBar(snapshot: displaySnapshot)
            } else {
                if showsTopSeparator {
                    Divider()
                }
                topBar(snapshot: displaySnapshot)
                panelBody
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            refreshIfNeeded(force: true)
        }
        .onChange(of: cwd) { _ in
            showsPendingChanges = true
            showsCommitHistory = false
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
        .onReceive(NotificationCenter.default.publisher(for: .gitSettingsDidChange)) { _ in
            guard layout.showGit else { return }
            Task { await gitStatusStore.refresh(cwd: cwd) }
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

    private func topBar(snapshot: GitWorkspaceSnapshot?) -> some View {
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

            if let snapshot {
                Text(GitStatusPresentation.statusStrip(snapshot: snapshot))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
            }

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

    @ViewBuilder
    private var panelBody: some View {
        if !GitCLI.isAvailable {
            gitNotFoundBody
        } else if !isInRepository {
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

    private var gitNotFoundBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Git.Error.executableNotFound)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(L10n.Git.Panel.configureGitHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                openGitSettings()
            } label: {
                Text(L10n.Git.Panel.configureGit)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                VStack(alignment: .leading, spacing: 8) {
                    if !snapshot.entries.isEmpty {
                        pendingChangesSection(snapshot)
                    }
                    commitHistory(snapshot)
                    if let lastOperationError {
                        Text(lastOperationError)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            actionFooter(snapshot)
        }
    }

    private func pendingChangesSection(_ snapshot: GitWorkspaceSnapshot) -> some View {
        DisclosureGroup(isExpanded: $showsPendingChanges) {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(snapshot.entries) { entry in
                    GitChangeRowView(entry: entry) {
                        let absolute = GitStatusPresentation.absolutePath(for: entry, repoRoot: snapshot.repoRoot)
                        onRevealPath(absolute)
                    }
                }
            }
            .padding(.top, 4)
        } label: {
            Text(L10n.Git.Status.dirty(snapshot.changeCount))
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func commitHistory(_ snapshot: GitWorkspaceSnapshot) -> some View {
        DisclosureGroup(isExpanded: $showsCommitHistory) {
            GitCommitHistoryView(commits: snapshot.recentCommits)
                .padding(.top, 4)
        } label: {
            Text(L10n.Git.History.title)
                .font(.caption)
                .foregroundStyle(.primary)
        }
    }

    private func actionFooter(_ snapshot: GitWorkspaceSnapshot) -> some View {
        let primary = GitPanelActionPlanner.primaryAction(snapshot: snapshot, isOperating: isOperating)
        let showCommitField = snapshot.changeCount > 0
        let showsSecondaryPull = primary?.kind != .pull

        return VStack(alignment: .leading, spacing: 8) {
            if showCommitField {
                HStack(spacing: 6) {
                    commitMessageField

                    Button {} label: {
                        Image(systemName: "sparkles")
                    }
                    .buttonStyle(.borderless)
                    .disabled(true)
                    .instantHoverTooltip(L10n.Git.Commit.aiTooltip)
                }
            }

            actionButtonGroup(
                snapshot: snapshot,
                primary: primary,
                showsSecondaryPull: showsSecondaryPull
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var commitMessageField: some View {
        TextField(L10n.Git.Commit.placeholder, text: $commitMessage)
            .textFieldStyle(.plain)
            .focused($commitFieldFocused)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        commitFieldFocused
                            ? Color.accentColor
                            : Color(nsColor: .separatorColor).opacity(0.85),
                        lineWidth: commitFieldFocused ? 1.5 : 1.25
                    )
            )
    }

    private func actionButtonGroup(
        snapshot: GitWorkspaceSnapshot,
        primary: GitPanelPrimaryAction?,
        showsSecondaryPull: Bool
    ) -> some View {
        HStack(spacing: 6) {
            if showsSecondaryPull {
                Button {
                    Task { await runOperation(.pull) }
                } label: {
                    Text(L10n.Git.Action.pull)
                }
                .buttonStyle(.bordered)
                .disabled(!GitPanelActionPlanner.canPull(snapshot: snapshot) || isOperating)
                .instantHoverTooltip(GitPanelActionPlanner.pullDisabledReason(snapshot: snapshot) ?? "")
            }

            if snapshot.changeCount > 0 {
                Button {
                    requestOperation(.commit)
                } label: {
                    Text(L10n.Git.Action.commitOnly)
                }
                .buttonStyle(.bordered)
                .disabled(!GitPanelActionPlanner.canCommitOnly(snapshot: snapshot, isOperating: isOperating))
            }

            if let primary {
                Button {
                    handlePrimaryAction(primary)
                } label: {
                    if isOperating {
                        HStack(spacing: 4) {
                            ProgressView()
                                .controlSize(.small)
                            Text(L10n.Git.Action.working)
                        }
                    } else {
                        Text(primary.title)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!primary.isEnabled || isOperating)
                .instantHoverTooltip(primary.disabledReason ?? "")
            }
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .leading)
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
            showsPendingChanges = true
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
        guard GitCLI.isAvailable else { return }
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
}
