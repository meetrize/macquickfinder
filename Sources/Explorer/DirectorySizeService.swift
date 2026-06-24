import Foundation
import FileList

typealias DirectorySizeService = DirectoryMetadataService<DirectorySizeComputeResult>

extension DirectoryMetadataService where Entry == DirectorySizeComputeResult {
    static let shared = DirectoryMetadataService(configuration: .directorySize)
}

extension DirectoryMetadataServiceConfiguration where Entry == DirectorySizeComputeResult {
    static let directorySize = DirectoryMetadataServiceConfiguration(
        maxConcurrent: 2,
        maxCacheEntries: 300,
        clearsEntireCacheWhenFull: true,
        invalidateDescendants: true,
        scheduleEnabled: {
            DirectorySizePreferences.autoCalculateDirectorySizes
        },
        shouldSchedulePath: { path in
            DirectorySizeVolumeFilter.shouldAutoCalculate(path: path)
        },
        isCacheValid: { cached, path in
            DirectoryMetadataCache.isExactMTimeValid(cached: cached, path: path)
        },
        compute: { path, showHiddenFiles in
            try await DirectorySizeComputer.compute(path: path, showHiddenFiles: showHiddenFiles)
        },
        apply: { path, result, generation in
            DirectoryMetadataOverlay.shared.apply(
                path: path,
                result: result,
                generation: generation
            )
        },
        remove: { paths in
            DirectoryMetadataOverlay.shared.removeSizes(paths: paths)
        }
    )
}

enum DirectorySizeComputer {
    static func compute(path: String, showHiddenFiles: Bool) async throws -> DirectorySizeComputeResult {
        try await computeDirectorySize(
            at: URL(fileURLWithPath: path),
            showHiddenFiles: showHiddenFiles
        )
    }

    private static func computeDirectorySize(
        at url: URL,
        showHiddenFiles: Bool
    ) async throws -> DirectorySizeComputeResult {
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: url.path) {
            let visible = showHiddenFiles
                ? contents
                : contents.filter { !$0.hasPrefix(".") }
            if visible.isEmpty { return .complete(0) }
        }

        var options: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [
                .totalFileAllocatedSizeKey,
                .fileSizeKey,
                .isRegularFileKey
            ],
            options: options
        ) else {
            return .complete(0)
        }

        let propertyKeys: Set<URLResourceKey> = [
            .totalFileAllocatedSizeKey,
            .fileSizeKey,
            .isRegularFileKey
        ]

        var total: Int64 = 0
        var fileCount = 0
        let startedAt = ContinuousClock.now

        while let fileURL = enumerator.nextObject() as? URL {
            try Task.checkCancellation()

            if DirectorySizeComputePolicy.shouldStopEnumerating(
                fileCount: fileCount,
                startedAt: startedAt,
                now: ContinuousClock.now
            ) {
                return .lowerBound(total)
            }

            guard let values = try? fileURL.resourceValues(forKeys: propertyKeys),
                  values.isRegularFile == true else { continue }

            let fileSize = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            total += fileSize

            fileCount += 1
            if fileCount % 800 == 0 {
                await Task.yield()
            }
        }

        return .complete(total)
    }
}
