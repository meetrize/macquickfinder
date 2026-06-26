import Foundation

/// 轻量触碰网络卷目录，促使 SMB 客户端建立连接/缓存，降低首次列目录延迟。
enum NetworkVolumePrewarmer {
    static func touchPath(_ path: String) {
        guard DirectorySizeVolumeFilter.isNetworkVolume(path: path) else { return }
        Task.detached(priority: .utility) {
            if let volumeRoot = volumeRootPath(for: path) {
                _ = try? FileManager.default.contentsOfDirectory(atPath: volumeRoot)
            }
            let parent = (path as NSString).deletingLastPathComponent
            if parent != path {
                _ = try? FileManager.default.contentsOfDirectory(atPath: parent)
            }
        }
    }

    static func volumeRootPath(for path: String) -> String? {
        guard path.hasPrefix("/Volumes/") else { return nil }
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 2, components[0] == "Volumes" else { return nil }
        return "/Volumes/\(components[1])"
    }
}
