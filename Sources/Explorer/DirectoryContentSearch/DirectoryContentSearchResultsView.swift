import SwiftUI

struct DirectoryContentSearchResultsView: View {
    @ObservedObject var session: DirectoryContentSearchSession
    let onSelectMatch: (ContentSearchMatch) -> Void
    let onShowPreview: () -> Void
    let onDismiss: () -> Void

    @FocusState private var isResultsFocused: Bool

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
        .focusable()
        .focused($isResultsFocused)
        .onAppear {
            DirectoryContentSearchKeyboardPriority.setResultsNavigationActive(true)
            isResultsFocused = true
        }
        .onDisappear {
            DirectoryContentSearchKeyboardPriority.setResultsNavigationActive(false)
        }
        .background {
            DirectoryContentSearchKeyboardMonitor(
                isActive: isResultsFocused,
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
            onShowPreview: {},
            onDismiss: {}
        )
        .frame(width: 640, height: 480)
    }
}
#endif
