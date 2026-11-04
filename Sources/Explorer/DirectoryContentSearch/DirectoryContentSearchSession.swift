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
        let changed = currentRoot != root || currentShowHiddenFiles != showHiddenFiles
        currentRoot = root
        currentShowHiddenFiles = showHiddenFiles
        // 路径/隐藏选项未变化时不要重复触发整轮搜索。
        guard changed else { return }
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

    /// 标签页重新可见时，续跑被切走时中断的搜索。
    func resumeSearchIfNeeded() {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard progress.wasCancelled, currentRoot != nil else { return }
        scheduleSearchIfNeeded()
    }

    func cancelInFlightSearch() {
        searchGeneration &+= 1
        searchTask?.cancel()
        searchTask = nil
        // 同时取消尚未触发的防抖，避免标签页隐藏后 300ms 又重新起一轮扫描。
        debounceTask?.cancel()
        debounceTask = nil
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

            let result = await engine.runSearch(
                request: request,
                isCancelled: { Task.isCancelled },
                onPartial: { partial in
                    // 引擎在后台线程回调；把快照交给主线程，apply 内部会丢弃过期结果。
                    Task { @MainActor in
                        self.apply(result: partial, isFinal: false, generation: generation)
                    }
                }
            )

            guard !Task.isCancelled, generation == self.searchGeneration else { return }
            apply(result: result, isFinal: true, generation: generation)
        }
    }

    private func apply(result: ContentSearchScanResult, isFinal: Bool, generation: UInt64) {
        guard generation == searchGeneration else { return }
        // 最终结果可能先于后台 partial 的 MainActor 任务落地；不要让旧 partial 覆盖完整结果。
        guard isFinal || !progress.isComplete else { return }
        guard isFinal || result.progress.scannedFileCount >= progress.scannedFileCount else { return }

        if isFinal || result.matches.count != flattenedMatches.count {
            flattenedMatches = result.matches
            groups = Self.makeGroups(
                from: result.matches,
                userExpansionOverrides: userExpansionOverrides,
                defaultExpandedCount: 5
            )
        }
        progress = result.progress

        if isFinal {
            // 只保留当前命中文件的手动展开状态，避免多次搜索后字典无限增长。
            let liveFileIDs = Set(result.matches.map(\.fileURL.path))
            userExpansionOverrides = userExpansionOverrides.filter { liveFileIDs.contains($0.key) }

            if selectedMatchID == nil || !result.matches.contains(where: { $0.id == selectedMatchID }) {
                selectedMatchID = result.matches.first?.id
            }
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
