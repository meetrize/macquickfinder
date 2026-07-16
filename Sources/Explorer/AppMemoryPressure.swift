import AppKit
import FileList
import Foundation

/// 系统内存压力时集中清理可重建缓存，不影响用户数据与持久化设置。
enum AppMemoryPressure {
    enum Level {
        case warning
        case critical
    }

    private static var memoryPressureSource: DispatchSourceMemoryPressure?
    private static var resumeBudgetTask: Task<Void, Never>?

    static func installHandler() {
        guard memoryPressureSource == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler {
            let data = source.data
            let level: Level = data.contains(.critical) ? .critical : .warning
            Task { @MainActor in
                respond(level: level)
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    @MainActor
    static func respond(level: Level = .warning) {
        TextSyntaxHighlighter.clearCache()
        FileListWorkspaceIconCache.clearAll()
        PreviewSessionStore.shared.respondToMemoryPressure(clearInline: level == .critical)
        MarkdownPreviewMermaidRenderer.shared.clearCachesOnMemoryPressure()

        switch level {
        case .warning:
            ThumbnailGenerator.shared.clearMemoryCache()
            ThumbnailGenerator.shared.trimDiskCache()
            Task {
                await DirectoryMetadataScheduler.trimCachesOnMemoryPressure()
            }
        case .critical:
            ThumbnailGenerator.shared.setMemoryBudget(ThumbnailGenerator.criticalMemoryBudgetBytes)
            ThumbnailGenerator.shared.clearMemoryCache()
            ThumbnailGenerator.shared.trimDiskCache()
            ThumbnailGenerator.shared.cancelInFlightRequests()
            Task {
                await DirectoryMetadataScheduler.trimCachesOnMemoryPressure()
                await DirectoryMetadataScheduler.setSchedulingPaused(true)
            }
            scheduleBudgetRestore()
        }

        NotificationCenter.default.post(name: .meoFindMemoryPressure, object: nil)
    }

    /// critical 下调预算后，一段时间无新压力则恢复默认 LRU 与元数据调度。
    @MainActor
    private static func scheduleBudgetRestore() {
        resumeBudgetTask?.cancel()
        resumeBudgetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard !Task.isCancelled else { return }
            ThumbnailGenerator.shared.restoreDefaultMemoryBudget()
            await DirectoryMetadataScheduler.setSchedulingPaused(false)
        }
    }
}
