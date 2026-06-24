import Combine
import FileList
import Foundation

/// 目录大小与子项数量的主线程覆盖层（单一 ObservableObject，供列表/缩略图/预览共用）。
@MainActor
final class DirectoryMetadataOverlay: ObservableObject {
    static let shared = DirectoryMetadataOverlay()

    @Published private(set) var sizes: [String: Int64] = [:]
    @Published private(set) var lowerBoundPaths: Set<String> = []
    @Published private(set) var counts: [String: Int] = [:]
    /// 大小列 / 缩略图尺寸角标刷新世代。
    @Published private(set) var sizeRevision: UInt = 0
    /// 子项数量角标刷新世代。
    @Published private(set) var countRevision: UInt = 0

    private(set) var sizeSessionGeneration: UInt = 0
    private(set) var countSessionGeneration: UInt = 0

    private init() {}

    /// 路径切换等场景：同时重置大小与子项数量会话。
    func beginSession(generation: UInt) {
        sizeSessionGeneration = generation
        countSessionGeneration = generation
        clearSizes()
        clearCounts()
    }

    /// 关闭「自动计算目录大小」等场景：仅重置大小会话，保留子项数量缓存。
    func beginSizeSession(generation: UInt) {
        sizeSessionGeneration = generation
        clearSizes()
    }

    func apply(path: String, result: DirectorySizeComputeResult, generation: UInt) {
        guard generation == sizeSessionGeneration else { return }
        switch result {
        case .complete(let size):
            lowerBoundPaths.remove(path)
            sizes[path] = size
        case .lowerBound(let size):
            lowerBoundPaths.insert(path)
            sizes[path] = size
        }
        sizeRevision &+= 1
    }

    func apply(path: String, count: Int, generation: UInt) {
        guard generation == countSessionGeneration else { return }
        counts[path] = count
        countRevision &+= 1
    }

    func removeSizes(paths: [String]) {
        guard !paths.isEmpty else { return }
        var changed = false
        for path in paths {
            if sizes.removeValue(forKey: path) != nil { changed = true }
            if lowerBoundPaths.remove(path) != nil { changed = true }
        }
        if changed { sizeRevision &+= 1 }
    }

    func removeCounts(paths: [String]) {
        guard !paths.isEmpty else { return }
        var changed = false
        for path in paths {
            if counts.removeValue(forKey: path) != nil { changed = true }
        }
        if changed { countRevision &+= 1 }
    }

    func sizeDisplay(for path: String) -> DirectorySizeDisplayInfo {
        guard let size = sizes[path] else {
            return .unknown
        }
        let formatted = FileItemFormatters.formatSize(size)
        if lowerBoundPaths.contains(path) {
            return DirectorySizeDisplayInfo(sortableSize: size, text: "≥\(formatted)")
        }
        return DirectorySizeDisplayInfo(sortableSize: size, text: formatted)
    }

    func countDisplay(for path: String) -> DirectoryItemCountDisplayInfo {
        guard !FileListApplicationBundle.isBundle(path: path) else {
            return .unknown
        }
        guard let count = counts[path] else {
            return .unknown
        }
        return .formatted(count)
    }

    private func clearSizes() {
        sizes.removeAll()
        lowerBoundPaths.removeAll()
        sizeRevision = 0
    }

    private func clearCounts() {
        counts.removeAll()
        countRevision = 0
    }
}
