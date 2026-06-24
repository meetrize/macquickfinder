import Foundation
import FileList

typealias DirectoryItemCountService = DirectoryMetadataService<Int>

extension DirectoryMetadataService where Entry == Int {
    static let shared = DirectoryMetadataService(configuration: .directoryItemCount)
}

extension DirectoryMetadataServiceConfiguration where Entry == Int {
    static let directoryItemCount = DirectoryMetadataServiceConfiguration(
        maxConcurrent: 3,
        maxCacheEntries: 500,
        clearsEntireCacheWhenFull: false,
        invalidateDescendants: false,
        sessionResetCacheRetention: 100,
        scheduleEnabled: { true },
        shouldSchedulePath: { path in
            DirectorySizeVolumeFilter.shouldAutoCalculate(path: path)
                && !FileListApplicationBundle.isBundle(path: path)
        },
        isCacheValid: { cached, path in
            DirectoryMetadataCache.isFuzzyMTimeValid(cached: cached, path: path)
        },
        compute: { path, showHiddenFiles in
            try await DirectoryItemCountComputer.compute(path: path, showHiddenFiles: showHiddenFiles)
        },
        apply: { path, count, generation in
            DirectoryMetadataOverlay.shared.apply(
                path: path,
                count: count,
                generation: generation
            )
        },
        remove: { paths in
            DirectoryMetadataOverlay.shared.removeCounts(paths: paths)
        }
    )
}

enum DirectoryItemCountComputer {
    static func compute(path: String, showHiddenFiles: Bool) async throws -> Int {
        await countImmediateChildren(at: path, showHiddenFiles: showHiddenFiles)
    }

    private static func countImmediateChildren(
        at path: String,
        showHiddenFiles: Bool
    ) async -> Int {
        await Task.detached(priority: .utility) {
            let url = URL(fileURLWithPath: path)
            guard let names = try? FileManager.default.contentsOfDirectory(atPath: path) else {
                return 0
            }
            if showHiddenFiles {
                return names.count
            }
            var count = 0
            for name in names {
                let childURL = url.appendingPathComponent(name)
                let values = try? childURL.resourceValues(forKeys: [.isHiddenKey])
                if values?.isHidden != true {
                    count += 1
                }
            }
            return count
        }.value
    }
}
