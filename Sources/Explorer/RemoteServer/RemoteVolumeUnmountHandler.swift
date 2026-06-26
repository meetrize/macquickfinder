import Foundation

enum RemoteVolumeUnmountHandler {
    static func isPath(_ path: String, insideVolume volumePath: String) -> Bool {
        let normalizedPath = (path as NSString).standardizingPath
        let normalizedVolume = (volumePath as NSString).standardizingPath
        guard !normalizedVolume.isEmpty else { return false }
        if normalizedPath == normalizedVolume { return true }
        return normalizedPath.hasPrefix(normalizedVolume + "/")
    }

    static func resolveFallbackPath(
        from currentPath: String,
        unmountedVolumePath: String,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String? {
        guard isPath(currentPath, insideVolume: unmountedVolumePath) else { return nil }

        var candidate = (currentPath as NSString).standardizingPath
        while !candidate.isEmpty {
            if isPath(candidate, insideVolume: unmountedVolumePath) {
                let parent = (candidate as NSString).deletingLastPathComponent
                if parent == candidate { break }
                candidate = parent
                continue
            }
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
            let parent = (candidate as NSString).deletingLastPathComponent
            if parent == candidate { break }
            candidate = parent
        }
        return homeDirectory
    }
}

enum SidebarVolumeEjector {
    static func eject(
        _ device: SidebarVolume,
        onComplete: @escaping (Bool) -> Void = { _ in }
    ) {
        guard device.canEject else {
            DispatchQueue.main.async { onComplete(false) }
            return
        }

        let path = device.path
        DispatchQueue.global(qos: .utility).async {
            let success = unmountVolume(at: path)
            DispatchQueue.main.async {
                onComplete(success)
            }
        }
    }

    /// SMB（smbfs）挂载点不是磁盘设备，`diskutil eject` 会失败；优先 `unmount`。
    private static func unmountVolume(at path: String) -> Bool {
        let attempts: [[String]] = [
            ["/usr/sbin/diskutil", "unmount", path],
            ["/usr/sbin/diskutil", "unmount", "force", path],
            ["/usr/sbin/diskutil", "eject", path],
            ["/sbin/umount", path],
            ["/sbin/umount", "-f", path],
        ]

        for args in attempts {
            if runCommand(executable: args[0], arguments: Array(args.dropFirst())) == 0 {
                return true
            }
        }
        return false
    }

    private static func runCommand(executable: String, arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        } catch {
            return -1
        }
    }
}

extension Notification.Name {
    static let explorerTransientNotice = Notification.Name("explorerTransientNotice")
}
