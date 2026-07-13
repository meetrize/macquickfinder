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

    func runSearch(
        request: ContentSearchRequest,
        isCancelled: @Sendable () -> Bool
    ) async -> ContentSearchScanResult {
        let started = ContinuousClock.now
        let trimmedQuery = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return ContentSearchScanResult(matches: [], progress: .idle)
        }

        let fileURLs = enumerateFiles(
            root: request.root,
            filter: request.filter,
            showHiddenFiles: request.showHiddenFiles
        )

        var matches: [ContentSearchMatch] = []
        var scannedCount = 0
        var wasTruncated = false
        let workerCount = scanWorkerCount(for: request.root)

        var index = 0
        while index < fileURLs.count {
            if isCancelled() {
                return makeScanResult(
                    matches: matches,
                    scannedCount: scannedCount,
                    totalFileCount: fileURLs.count,
                    started: started,
                    wasCancelled: true,
                    wasTruncated: wasTruncated
                )
            }

            let end = min(index + workerCount, fileURLs.count)
            let batch = Array(fileURLs[index..<end])
            index = end

            await withTaskGroup(of: (URL, [ContentSearchMatch]).self) { group in
                for fileURL in batch {
                    group.addTask {
                        ContentSearchFileScanner.scanFile(
                            url: fileURL,
                            root: request.root,
                            query: trimmedQuery,
                            filter: request.filter
                        )
                    }
                }

                for await (_, fileMatches) in group {
                    if isCancelled() { break }
                    scannedCount += 1
                    if !fileMatches.isEmpty {
                        matches.append(contentsOf: fileMatches)
                        if matches.count >= request.filter.maxMatchCount {
                            matches = Array(matches.prefix(request.filter.maxMatchCount))
                            wasTruncated = true
                            group.cancelAll()
                            break
                        }
                    }
                }
            }

            if wasTruncated || isCancelled() {
                break
            }
        }

        return makeScanResult(
            matches: matches,
            scannedCount: scannedCount,
            totalFileCount: fileURLs.count,
            started: started,
            wasCancelled: isCancelled(),
            wasTruncated: wasTruncated
        )
    }

    private func makeScanResult(
        matches: [ContentSearchMatch],
        scannedCount: Int,
        totalFileCount: Int,
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
        return scanBatchSize
    }

    func enumerateFiles(
        root: URL,
        filter: ContentSearchFilter,
        showHiddenFiles: Bool
    ) -> [URL] {
        var results: [URL] = []
        let includePatterns = filter.normalizedIncludePatterns
        let excludePatterns = filter.normalizedExcludePatterns

        if filter.includesSubdirectories {
            collectFilesRecursively(
                at: root,
                root: root,
                includePatterns: includePatterns,
                excludePatterns: excludePatterns,
                showHiddenFiles: showHiddenFiles,
                into: &results
            )
        } else {
            collectFilesInDirectory(
                at: root,
                root: root,
                includePatterns: includePatterns,
                excludePatterns: excludePatterns,
                showHiddenFiles: showHiddenFiles,
                into: &results
            )
        }

        return results.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    private func collectFilesRecursively(
        at directory: URL,
        root: URL,
        includePatterns: [String],
        excludePatterns: [String],
        showHiddenFiles: Bool,
        into results: inout [URL]
    ) {
        collectFilesInDirectory(
            at: directory,
            root: root,
            includePatterns: includePatterns,
            excludePatterns: excludePatterns,
            showHiddenFiles: showHiddenFiles,
            into: &results
        )

        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsPackageDescendants]
        ) else {
            return
        }

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            if values?.isHidden == true, !showHiddenFiles { continue }
            if values?.isDirectory == true {
                collectFilesRecursively(
                    at: child,
                    root: root,
                    includePatterns: includePatterns,
                    excludePatterns: excludePatterns,
                    showHiddenFiles: showHiddenFiles,
                    into: &results
                )
            }
        }
    }

    private func collectFilesInDirectory(
        at directory: URL,
        root: URL,
        includePatterns: [String],
        excludePatterns: [String],
        showHiddenFiles: Bool,
        into results: inout [URL]
    ) {
        guard let children = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey, .fileSizeKey],
            options: [.skipsPackageDescendants]
        ) else {
            return
        }

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey, .isHiddenKey])
            if values?.isHidden == true, !showHiddenFiles { continue }
            if values?.isDirectory == true { continue }

            let ext = child.pathExtension
            guard ContentSearchFileEligibility.isSearchableExtension(ext) else { continue }

            let relativePath = relativePath(for: child, root: root)
            let fileName = child.lastPathComponent
            guard ContentSearchGlobMatcher.matches(
                relativePath: relativePath,
                fileName: fileName,
                includePatterns: includePatterns,
                excludePatterns: excludePatterns
            ) else {
                continue
            }

            results.append(child)
        }
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

    private func relativePath(for fileURL: URL, root: URL) -> String {
        ContentSearchFileScanner.relativePath(for: fileURL, root: root)
    }

    private func elapsedSeconds(since start: ContinuousClock.Instant) -> TimeInterval {
        let duration = start.duration(to: ContinuousClock.now)
        return Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
}
