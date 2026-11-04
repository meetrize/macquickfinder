import Foundation

struct ContentSearchRequest: Sendable {
    let root: URL
    let query: String
    let filter: ContentSearchFilter
    let showHiddenFiles: Bool
    let generation: UInt64
}

actor DirectoryContentSearchEngine {
    private let scanBatchSize = 4
    /// 渐进结果节流间隔：让结果列表在扫描过程中就开始出现，而不是等全部扫完。
    private let partialUpdateInterval: Duration = .milliseconds(250)

    /// 只允许最新一次搜索继续消耗资源；旧搜索在下一个检查点尽快退出。
    private var latestSearchToken: UInt64 = 0

    func runSearch(
        request: ContentSearchRequest,
        isCancelled: @Sendable () -> Bool,
        onPartial: (@Sendable (ContentSearchScanResult) -> Void)? = nil
    ) async -> ContentSearchScanResult {
        latestSearchToken &+= 1
        let searchToken = latestSearchToken
        let started = ContinuousClock.now
        let trimmedQuery = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return ContentSearchScanResult(matches: [], progress: .idle)
        }

        let globSet = ContentSearchGlobMatcher.Compiled(
            includePatterns: request.filter.normalizedIncludePatterns,
            excludePatterns: request.filter.normalizedExcludePatterns
        )
        let workerCount = scanWorkerCount(for: request.root)
        let rootPath = request.root.standardizedFileURL.path

        var matches: [ContentSearchMatch] = []
        var scannedCount = 0
        var discoveredCount = 0
        var wasTruncated = false
        var lastPartialEmission = ContinuousClock.now

        func shouldStop() -> Bool {
            isCancelled() || searchToken != latestSearchToken
        }

        func makeResult(wasCancelled: Bool, includeTotal: Bool = true) -> ContentSearchScanResult {
            makeScanResult(
                matches: matches,
                scannedCount: scannedCount,
                totalFileCount: includeTotal ? (discoveredCount > 0 ? discoveredCount : nil) : nil,
                started: started,
                wasCancelled: wasCancelled,
                wasTruncated: wasTruncated
            )
        }

        guard let enumerator = makeEnumerator(
            root: request.root,
            filter: request.filter,
            showHiddenFiles: request.showHiddenFiles
        ) else {
            return makeResult(wasCancelled: false)
        }

        func relativePath(for url: URL) -> String {
            // root 只标准化一次；逐个文件再 standardizedFileURL 在深目录下开销明显。
            let path = url.path
            if path.hasPrefix(rootPath + "/") {
                return String(path.dropFirst(rootPath.count + 1))
            }
            return url.lastPathComponent
        }

        func nextCandidate() -> (url: URL, relativePath: String)? {
            // 单次遍历：目录和文件都只枚举一遍，并在排除目录处剪枝。
            while let item = enumerator.nextObject() as? URL {
                if shouldStop() { return nil }

                let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
                if values?.isHidden == true, !request.showHiddenFiles { continue }

                if values?.isDirectory == true {
                    if globSet.excludesDirectory(relativePath: relativePath(for: item)) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard ContentSearchFileEligibility.isSearchableExtension(item.pathExtension) else {
                    continue
                }

                let fileRelativePath = relativePath(for: item)
                guard globSet.matches(
                    relativePath: fileRelativePath,
                    fileName: item.lastPathComponent
                ) else {
                    continue
                }

                discoveredCount += 1
                return (item, fileRelativePath)
            }
            return nil
        }

        await withTaskGroup(of: [ContentSearchMatch].self) { group in
            var runningTasks = 0
            var enumerationFinished = false

            func fillWorkerPool() {
                while runningTasks < workerCount, !enumerationFinished {
                    guard let candidate = nextCandidate() else {
                        enumerationFinished = true
                        return
                    }
                    let url = candidate.url
                    let relativePath = candidate.relativePath
                    runningTasks += 1
                    group.addTask {
                        ContentSearchFileScanner.scanFileContents(
                            url: url,
                            relativePath: relativePath,
                            query: trimmedQuery,
                            filter: request.filter
                        )
                    }
                }
            }

            fillWorkerPool()

            while runningTasks > 0 {
                guard let fileMatches = await group.next() else { break }
                runningTasks -= 1
                scannedCount += 1

                if shouldStop() {
                    group.cancelAll()
                    break
                }

                if !fileMatches.isEmpty {
                    matches.append(contentsOf: fileMatches)
                    if matches.count >= request.filter.maxMatchCount {
                        matches = Array(matches.prefix(request.filter.maxMatchCount))
                        wasTruncated = true
                        group.cancelAll()
                        break
                    }
                }

                fillWorkerPool()

                guard let onPartial else { continue }
                let now = ContinuousClock.now
                guard now - lastPartialEmission >= partialUpdateInterval else { continue }
                lastPartialEmission = now
                onPartial(makeResult(wasCancelled: false, includeTotal: false))
            }
        }

        return makeResult(wasCancelled: shouldStop() && !wasTruncated)
    }

    private func makeEnumerator(
        root: URL,
        filter: ContentSearchFilter,
        showHiddenFiles: Bool
    ) -> FileManager.DirectoryEnumerator? {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !filter.includesSubdirectories {
            options.insert(.skipsSubdirectoryDescendants)
        }
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        return FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: options,
            errorHandler: { _, _ in true }
        )
    }

    private func makeScanResult(
        matches: [ContentSearchMatch],
        scannedCount: Int,
        totalFileCount: Int?,
        started: ContinuousClock.Instant,
        wasCancelled: Bool,
        wasTruncated: Bool
    ) -> ContentSearchScanResult {
        ContentSearchScanResult(
            matches: matches,
            progress: ContentSearchProgress(
                scannedFileCount: scannedCount,
                totalFileCount: totalFileCount,
                matchCount: matches.count,
                elapsed: elapsedSeconds(since: started),
                isComplete: !wasCancelled,
                wasCancelled: wasCancelled,
                wasTruncated: wasTruncated
            )
        )
    }

    private func scanWorkerCount(for root: URL) -> Int {
        if DirectorySizeVolumeFilter.isNetworkVolume(path: root.path) {
            return 2
        }
        return min(scanBatchSize, max(2, ProcessInfo.processInfo.activeProcessorCount))
    }

    func scanFile(
        url: URL,
        relativePath: String,
        query: String,
        filter: ContentSearchFilter
    ) -> [ContentSearchMatch] {
        ContentSearchFileScanner.scanFileContents(
            url: url,
            relativePath: relativePath,
            query: query,
            filter: filter
        )
    }

    private func elapsedSeconds(since start: ContinuousClock.Instant) -> TimeInterval {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
