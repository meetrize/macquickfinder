import Combine
import Foundation

@MainActor
final class DirectoryContentSearchSession: ObservableObject {
    @Published var query: String = "" {
        didSet { scheduleSearchIfNeeded() }
    }
    @Published var filter: ContentSearchFilter = .default {
        didSet { scheduleSearchIfNeeded() }
    }
    @Published private(set) var groups: [ContentSearchFileGroup] = []
    @Published private(set) var flattenedMatches: [ContentSearchMatch] = []
    @Published private(set) var progress: ContentSearchProgress = .idle
    @Published var selectedMatchID: UUID?

    private let engine = DirectoryContentSearchEngine()
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private var searchGeneration: UInt64 = 0
    private var currentRoot: URL?
    private var currentShowHiddenFiles = false
    private var userExpansionOverrides: [String: Bool] = [:]

    func updateSearchContext(root: URL, showHiddenFiles: Bool) {
        currentRoot = root
        currentShowHiddenFiles = showHiddenFiles
        scheduleSearchIfNeeded()
    }

    func cancel() {
        searchGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        debounceTask?.cancel()
        debounceTask = nil
        groups = []
        flattenedMatches = []
        selectedMatchID = nil
        progress = .idle
        userExpansionOverrides = [:]
    }

    func toggleGroupExpansion(fileID: String) {
        guard let index = groups.firstIndex(where: { $0.id == fileID }) else { return }
        let newValue = !groups[index].isExpanded
        groups[index].isExpanded = newValue
        userExpansionOverrides[fileID] = newValue
    }

    func selectNextMatch(forward: Bool) {
        guard !flattenedMatches.isEmpty else {
            selectedMatchID = nil
            return
        }

        guard let selectedMatchID,
              let currentIndex = flattenedMatches.firstIndex(where: { $0.id == selectedMatchID }) else {
            self.selectedMatchID = forward ? flattenedMatches.first?.id : flattenedMatches.last?.id
            expandGroupContaining(matchID: self.selectedMatchID)
            return
        }

        let nextIndex: Int
        if forward {
            nextIndex = (currentIndex + 1) % flattenedMatches.count
        } else {
            nextIndex = (currentIndex - 1 + flattenedMatches.count) % flattenedMatches.count
        }
        self.selectedMatchID = flattenedMatches[nextIndex].id
        expandGroupContaining(matchID: self.selectedMatchID)
    }

    func selectedMatch() -> ContentSearchMatch? {
        guard let selectedMatchID else { return nil }
        return flattenedMatches.first { $0.id == selectedMatchID }
    }

    var currentGlobalIndex: Int? {
        guard let selectedMatchID else { return nil }
        return flattenedMatches.firstIndex { $0.id == selectedMatchID }
    }

    var matchCount: Int { flattenedMatches.count }

    func toggleExpansionForSelectedMatch() {
        guard let match = selectedMatch() else { return }
        toggleGroupExpansion(fileID: match.fileURL.path)
    }

    func cancelInFlightSearch() {
        searchGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        if progress.isComplete == false {
            progress = ContentSearchProgress(
                scannedFileCount: progress.scannedFileCount,
                totalFileCount: progress.totalFileCount,
                matchCount: flattenedMatches.count,
                elapsed: progress.elapsed,
                isComplete: true,
                wasCancelled: true,
                wasTruncated: progress.wasTruncated
            )
        }
    }

    private func scheduleSearchIfNeeded() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearch()
        }
    }

    private func performSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let root = currentRoot else {
            groups = []
            flattenedMatches = []
            selectedMatchID = nil
            progress = .idle
            return
        }

        searchGeneration &+= 1
        let generation = searchGeneration
        searchTask?.cancel()

        progress = ContentSearchProgress(
            scannedFileCount: 0,
            totalFileCount: nil,
            matchCount: 0,
            elapsed: 0,
            isComplete: false,
            wasCancelled: false,
            wasTruncated: false
        )

        searchTask = Task { @MainActor in
            let request = ContentSearchRequest(
                root: root,
                query: trimmed,
                filter: filter,
                showHiddenFiles: currentShowHiddenFiles,
                generation: generation
            )

            let result = await engine.runSearch(request: request) {
                Task.isCancelled
            }

            guard !Task.isCancelled, generation == self.searchGeneration else { return }

            flattenedMatches = result.matches
            groups = Self.makeGroups(
                from: result.matches,
                userExpansionOverrides: userExpansionOverrides,
                defaultExpandedCount: 5
            )
            progress = result.progress
            selectedMatchID = result.matches.first?.id
            if let selectedMatchID {
                expandGroupContaining(matchID: selectedMatchID)
            }
        }
    }

    static func makeGroups(
        from matches: [ContentSearchMatch],
        userExpansionOverrides: [String: Bool],
        defaultExpandedCount: Int
    ) -> [ContentSearchFileGroup] {
        var grouped: [String: [ContentSearchMatch]] = [:]
        var fileURLs: [String: URL] = [:]
        var relativePaths: [String: String] = [:]

        for match in matches {
            let key = match.fileURL.path
            grouped[key, default: []].append(match)
            fileURLs[key] = match.fileURL
            relativePaths[key] = match.relativePath
        }

        let sortedKeys = grouped.keys.sorted {
            ($0 as NSString).localizedStandardCompare($1) == .orderedAscending
        }

        return sortedKeys.enumerated().map { index, key in
            let defaultExpanded = index < defaultExpandedCount
            let isExpanded = userExpansionOverrides[key] ?? defaultExpanded
            return ContentSearchFileGroup(
                fileURL: fileURLs[key]!,
                relativePath: relativePaths[key] ?? fileURLs[key]!.lastPathComponent,
                matches: grouped[key] ?? [],
                isExpanded: isExpanded
            )
        }
    }

    private func expandGroupContaining(matchID: UUID?) {
        guard let matchID,
              let match = flattenedMatches.first(where: { $0.id == matchID }),
              let index = groups.firstIndex(where: { $0.fileURL == match.fileURL }) else {
            return
        }
        groups[index].isExpanded = true
        userExpansionOverrides[groups[index].id] = true
    }
}
