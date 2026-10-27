import AppKit
import Foundation

/// 无权限删除时的提权回退：弹出系统管理员密码框（与安装软件同源），再移入废纸篓或永久删除。
enum PrivilegedFileOperations {
    enum Outcome {
        case success(destinations: [URL?])
        case cancelled
        case failure(String)
    }

    /// 判断是否值得尝试管理员提权（POSIX / Cocoa 无权限，或文案含许可/权限）。
    static func isPrivilegeEscalationCandidate(_ error: Error) -> Bool {
        let nsError = error as NSError
        if isPrivilegeEscalationCandidate(nsError: nsError) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return isPrivilegeEscalationCandidate(underlying)
        }
        return false
    }

    static func isPrivilegeEscalationCandidate(nsError: NSError) -> Bool {
        if nsError.domain == NSCocoaErrorDomain {
            switch nsError.code {
            case NSFileWriteNoPermissionError,
                 NSFileReadNoPermissionError,
                 NSFileWriteVolumeReadOnlyError:
                return true
            default:
                break
            }
        }
        if nsError.domain == NSPOSIXErrorDomain {
            switch nsError.code {
            case Int(EPERM), Int(EACCES):
                return true
            default:
                break
            }
        }

        let text = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            nsError.localizedRecoverySuggestion
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
            .lowercased()

        let markers = [
            "permission",
            "permitted",
            "not authorized",
            "authorization",
            "privilege",
            "denied",
            "许可",
            "权限",
            "特权",
            "不允许",
            "没有访问"
        ]
        return markers.contains { text.contains($0) }
    }

    /// 以管理员权限将项目移入当前用户废纸篓（一次密码可处理多项）。
    static func moveToTrashWithAdministratorPrivileges(_ urls: [URL]) -> Outcome {
        guard !urls.isEmpty else { return .success(destinations: []) }

        var destinations: [URL] = []
        var shellParts: [String] = []

        for url in urls {
            let destination = uniqueTrashDestination(for: url)
            destinations.append(destination)
            shellParts.append(
                "/bin/mv \(shellSingleQuoted(url.path)) \(shellSingleQuoted(destination.path))"
            )
        }

        switch runAdministratorShell(shellParts.joined(separator: " && ")) {
        case .success:
            if urls.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
                return .failure(L10n.Alert.operationFailed)
            }
            return .success(destinations: destinations.map { Optional($0) })
        case .cancelled:
            return .cancelled
        case .failure(let message):
            return .failure(message)
        }
    }

    /// 以管理员权限永久删除（一次密码可处理多项）。
    static func removeWithAdministratorPrivileges(_ urls: [URL]) -> Outcome {
        guard !urls.isEmpty else { return .success(destinations: []) }

        let shell = urls
            .map { "/bin/rm -rf \(shellSingleQuoted($0.path))" }
            .joined(separator: " && ")

        switch runAdministratorShell(shell) {
        case .success:
            let stillPresent = urls.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !stillPresent.isEmpty {
                return .failure(L10n.Alert.operationFailed)
            }
            return .success(destinations: Array(repeating: nil, count: urls.count))
        case .cancelled:
            return .cancelled
        case .failure(let message):
            return .failure(message)
        }
    }

    // MARK: - Private

    private enum AdminShellResult {
        case success
        case cancelled
        case failure(String)
    }

    private static func runAdministratorShell(_ shellCommand: String) -> AdminShellResult {
        let escapedCommand = appleScriptEscapedString(shellCommand)
        let source = "do shell script \"\(escapedCommand)\" with administrator privileges"
        var errorInfo: NSDictionary?
        guard let script = NSAppleScript(source: source) else {
            return .failure(L10n.Alert.operationFailed)
        }
        _ = script.executeAndReturnError(&errorInfo)
        guard let errorInfo else { return .success }

        if isUserCancelledAdminAuth(errorInfo) {
            return .cancelled
        }
        let message = (errorInfo[NSAppleScript.errorMessage] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .failure(message?.isEmpty == false ? message! : L10n.Alert.operationFailed)
    }

    static func isUserCancelledAdminAuth(_ errorInfo: NSDictionary) -> Bool {
        if let number = errorInfo[NSAppleScript.errorNumber] as? Int, number == -128 {
            return true
        }
        let message = ((errorInfo[NSAppleScript.errorMessage] as? String) ?? "").lowercased()
        let markers = ["user canceled", "user cancelled", "用户已取消", "已取消"]
        return markers.contains { message.contains($0) }
    }

    static func uniqueTrashDestination(for source: URL) -> URL {
        let trashDirectory = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".Trash", isDirectory: true)
        try? FileManager.default.createDirectory(at: trashDirectory, withIntermediateDirectories: true)

        let baseName = source.deletingPathExtension().lastPathComponent
        let ext = source.pathExtension
        var candidate = trashDirectory.appendingPathComponent(source.lastPathComponent)
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(baseName) \(index)" : "\(baseName) \(index).\(ext)"
            candidate = trashDirectory.appendingPathComponent(numbered)
            index += 1
        }
        return candidate
    }

    /// POSIX sh 单引号转义。
    static func shellSingleQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func appleScriptEscapedString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
