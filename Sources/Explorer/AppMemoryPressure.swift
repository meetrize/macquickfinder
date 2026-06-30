import AppKit
import FileList
import Foundation

/// 系统内存压力时集中清理可重建缓存，不影响用户数据与持久化设置。
enum AppMemoryPressure {
    private static var memoryPressureSource: DispatchSourceMemoryPressure?

    static func installHandler() {
        guard memoryPressureSource == nil else { return }
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.warning, .critical],
            queue: .main
        )
        source.setEventHandler {
            Task { @MainActor in
                respond()
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    @MainActor
    static func respond() {
        TextSyntaxHighlighter.clearCache()
        FileListWorkspaceIconCache.clearAll()
        PreviewSessionStore.shared.respondToMemoryPressure()
        ThumbnailGenerator.shared.clearMemoryCache()
        ThumbnailGenerator.shared.trimDiskCache()
        Task {
            await DirectoryMetadataScheduler.trimCachesOnMemoryPressure()
        }
        NotificationCenter.default.post(name: .meoFindMemoryPressure, object: nil)
    }
}
