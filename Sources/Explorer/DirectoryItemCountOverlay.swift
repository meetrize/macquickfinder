import Combine
import FileList
import Foundation

/// 文件夹子项数量的主线程覆盖层（缩略图右下角角标异步回填）。
@MainActor
final class DirectoryItemCountOverlay: ObservableObject {
    static let shared = DirectoryItemCountOverlay()
    
    @Published private(set) var counts: [String: Int] = [:]
    @Published private(set) var revision: UInt = 0
    private(set) var sessionGeneration: UInt = 0
    
    private init() {}
    
    func beginSession(generation: UInt) {
        sessionGeneration = generation
        counts.removeAll()
        revision = 0
    }
    
    func apply(path: String, count: Int, generation: UInt) {
        guard generation == sessionGeneration else { return }
        counts[path] = count
        revision &+= 1
    }
    
    func remove(paths: [String]) {
        for path in paths {
            counts.removeValue(forKey: path)
        }
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
}
