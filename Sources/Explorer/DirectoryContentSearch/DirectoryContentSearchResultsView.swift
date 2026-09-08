import SwiftUI

struct DirectoryContentSearchResultsView: View {
    @ObservedObject var session: DirectoryContentSearchSession
    let onSelectMatch: (ContentSearchMatch) -> Void
    let onOpenMatch: (ContentSearchMatch) -> Void
    let onShowPreview: () -> Void
    let onDismiss: () -> Void

    /// 仅用于启用本地键盘导航，不使用 SwiftUI `.focusable()`，避免系统蓝色焦点框。
    @State private var isKeyboardNavigationActive = false

    var body: some View {
        VStack(spacing: 0) {
            if !session.progress.isComplete, !session.query.isEmpty {
                ProgressView()
                    .controlSize(.regular)
                    .padding(.vertical, 8)
            }

            Group {
                if session.flattenedMatches.isEmpty, session.progress.isComplete {
                    emptyState
                } else {
                    resultsList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DirectoryContentSearchSummaryBar(
                progress: session.progress,
                fileCount: session.groups.count,
                currentIndex: session.currentGlobalIndex,
                onNextMatch: { session.selectNextMatch(forward: true) }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // 不抢顶栏搜索框焦点；用本地 key monitor 处理结果列表快捷键。
            isKeyboardNavigationActive = true
            DirectoryContentSearchKeyboardPriority.setResultsNavigationActive(true)
        }
        .onDisappear {
            isKeyboardNavigationActive = false
            DirectoryContentSearchKeyboardPriority.setResultsNavigationActive(false)
        }
        .background {
            DirectoryContentSearchKeyboardMonitor(
                isActive: isKeyboardNavigationActive,
                onMoveSelection: { forward in
                    session.selectNextMatch(forward: forward)
                },
                onActivateMatch: {
                    guard let match = session.selectedMatch() else { return }
                    onSelectMatch(match)
                },
                onFindNext: {
                    session.selectNextMatch(forward: true)
                },
                onFindPrevious: {
                    session.selectNextMatch(forward: false)
                },
                onToggleGroupExpansion: {
                    session.toggleExpansionForSelectedMatch()
                },
                onShowPreview: onShowPreview,
                onDismiss: onDismiss
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text(L10n.Search.contentNoResults)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(session.groups) { group in
                        DirectoryContentSearchFileGroupView(
                            group: group,
                            query: session.query,
                            selectedMatchID: session.selectedMatchID,
                            onToggleExpansion: {
                                session.toggleGroupExpansion(fileID: group.id)
                            },
                            onSelectMatch: { match in
                                session.selectedMatchID = match.id
                                onSelectMatch(match)
                            },
                            onOpenMatch: { match in
                                session.selectedMatchID = match.id
                                onOpenMatch(match)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
            }
            .onChange(of: session.selectedMatchID) { matchID in
                guard let matchID else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(matchID, anchor: .center)
                }
            }
        }
    }
}

#if DEBUG
struct DirectoryContentSearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        let session = DirectoryContentSearchSession()
        session.query = "TODO"
        return DirectoryContentSearchResultsView(
            session: session,
            onSelectMatch: { _ in },
            onOpenMatch: { _ in },
            onShowPreview: {},
            onDismiss: {}
        )
        .frame(width: 640, height: 480)
    }
}
#endif
