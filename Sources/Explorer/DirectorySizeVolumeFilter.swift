import Foundation

enum DirectorySizeVolumeFilter {
    /// 网络卷等非本地卷跳过自动计算，避免长时间阻塞列表浏览。
    static func shouldAutoCalculate(path: String) -> Bool {
        !isNetworkVolume(path: path)
    }

    /// 路径是否位于非本地（网络 / FUSE 等）卷上。
    static func isNetworkVolume(path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard let values = try? url.resourceValues(forKeys: [.volumeIsLocalKey]) else {
            return false
        }
        return !(values.volumeIsLocal ?? true)
    }
}
