import Foundation
import FileList

enum DirectoryMetadataSchedulePriority: Int, Comparable, Sendable {
    case visible = 0
    case normal = 1

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

typealias DirectorySizeSchedulePriority = DirectoryMetadataSchedulePriority
typealias DirectoryItemCountSchedulePriority = DirectoryMetadataSchedulePriority

/// 目录大小与子项数量的统一调度入口，避免各处成对调用两个 Service。
enum DirectoryMetadataScheduler {
    static func resetSession(generation: UInt) async {
        await DirectorySizeService.shared.resetSession(generation: generation)
        await DirectoryItemCountService.shared.resetSession(generation: generation)
    }

    /// 系统内存压力时裁剪目录元数据 Actor 缓存。
    static func trimCachesOnMemoryPressure() async {
        await DirectorySizeService.shared.trimCache(retainingAtMost: 50)
        await DirectoryItemCountService.shared.trimCache(retainingAtMost: 50)
    }

    /// critical 压力下暂停元数据队列；warning 或会话重置后恢复。
    static func setSchedulingPaused(_ paused: Bool) async {
        await DirectorySizeService.shared.setSchedulingPaused(paused)
        await DirectoryItemCountService.shared.setSchedulingPaused(paused)
    }

    static func invalidate(paths: [String]) async {
        guard !paths.isEmpty else { return }
        await DirectorySizeService.shared.invalidate(paths: paths)
        await DirectoryItemCountService.shared.invalidate(paths: paths)
    }

    static func scheduleDirectorySizes(
        paths: [String],
        showHiddenFiles: Bool,
        priority: DirectoryMetadataSchedulePriority = .normal
    ) async {
        guard !paths.isEmpty else { return }
        await DirectorySizeService.shared.schedule(
            paths: paths,
            showHiddenFiles: showHiddenFiles,
            priority: priority
        )
    }

    static func scheduleDirectoryItemCounts(
        paths: [String],
        showHiddenFiles: Bool,
        priority: DirectoryMetadataSchedulePriority = .normal
    ) async {
        let filtered = paths.filter { !FileListApplicationBundle.isBundle(path: $0) }
        guard !filtered.isEmpty else { return }
        await DirectoryItemCountService.shared.schedule(
            paths: filtered,
            showHiddenFiles: showHiddenFiles,
            priority: priority
        )
    }

    /// 列举完成后不再全量调度元数据；目录大小 / 子项数量改由可见区
    /// `scheduleVisibleMetadata` 驱动，避免大目录 I/O 风暴。
    static func scheduleAfterListingLoad(
        folderPaths: [String],
        showHiddenFiles: Bool,
        includeSizes: Bool
    ) async {
        _ = folderPaths
        _ = showHiddenFiles
        _ = includeSizes
    }

    static func scheduleVisibleMetadata(
        visiblePaths: [String],
        showHiddenFiles: Bool,
        includeSizes: Bool,
        includeItemCounts: Bool
    ) async {
        if includeSizes {
            await scheduleDirectorySizes(
                paths: visiblePaths,
                showHiddenFiles: showHiddenFiles,
                priority: .visible
            )
        }
        if includeItemCounts {
            await scheduleDirectoryItemCounts(
                paths: visiblePaths,
                showHiddenFiles: showHiddenFiles,
                priority: .visible
            )
        }
    }

    static func rescheduleAfterFSEventsInvalidation(
        paths: [String],
        showHiddenFiles: Bool
    ) async {
        await invalidate(paths: paths)
        await MainActor.run {
            DirectoryMetadataOverlay.shared.removeSizes(paths: paths)
        }
        guard DirectorySizePreferences.autoCalculateDirectorySizes else {
            await scheduleDirectoryItemCounts(
                paths: paths,
                showHiddenFiles: showHiddenFiles,
                priority: .visible
            )
            return
        }
        await scheduleDirectorySizes(
            paths: paths,
            showHiddenFiles: showHiddenFiles,
            priority: .visible
        )
        await scheduleDirectoryItemCounts(
            paths: paths,
            showHiddenFiles: showHiddenFiles,
            priority: .visible
        )
    }
}
