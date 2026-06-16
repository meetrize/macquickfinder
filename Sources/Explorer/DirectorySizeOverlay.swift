import Combine
import FileList
import Foundation

/// 当前目录文件夹大小的主线程覆盖层（与 `FileItem` 解耦，异步回填）。
@MainActor
final class DirectorySizeOverlay: ObservableObject {
    static let shared = DirectorySizeOverlay()
    
    @Published private(set) var sizes: [String: Int64] = [:]
    @Published private(set) var lowerBoundPaths: Set<String> = []
    private(set) var sessionGeneration: UInt = 0
    
    private init() {}
    
    func beginSession(generation: UInt) {
        sessionGeneration = generation
        sizes.removeAll()
        lowerBoundPaths.removeAll()
    }
    
    func apply(path: String, result: DirectorySizeComputeResult, generation: UInt) {
        guard generation == sessionGeneration else { return }
        switch result {
        case .complete(let size):
            lowerBoundPaths.remove(path)
            sizes[path] = size
        case .lowerBound(let size):
            lowerBoundPaths.insert(path)
            sizes[path] = size
        }
    }
    
    func remove(paths: [String]) {
        for path in paths {
            sizes.removeValue(forKey: path)
            lowerBoundPaths.remove(path)
        }
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
}
