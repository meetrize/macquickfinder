import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

enum DefaultFileViewerManager {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.explorer.app"
    static let finderBundleIdentifier = "com.apple.finder"

    private static let launchServicesDomain = "com.apple.LaunchServices/com.apple.launchservices.secure"
    private static let managedContentTypes: [UTType] = [.folder, .volume]

    static var globalFileViewerBundleIdentifier: String? {
        CFPreferencesCopyAppValue("NSFileViewer" as CFString, kCFPreferencesAnyApplication) as? String
    }

    static var workspaceFolderHandler: String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: .folder) else {
            return nil
        }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    static var effectiveDefaultBundleIdentifier: String {
        if let global = globalFileViewerBundleIdentifier, !global.isEmpty {
            return global
        }
        if let handler = workspaceFolderHandler, !handler.isEmpty {
            return handler
        }
        return finderBundleIdentifier
    }

    static var isDefaultFileViewer: Bool {
        let ours = bundleIdentifier
        if globalFileViewerBundleIdentifier == ours {
            return true
        }
        return workspaceFolderHandler == ours
    }

    static func displayName(for bundleIdentifier: String) -> String {
        if bundleIdentifier == Self.bundleIdentifier {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "MeoFind"
        }
        if bundleIdentifier == finderBundleIdentifier {
            return "Finder"
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: appURL.path)
        }
        return bundleIdentifier
    }

    static func setAsDefaultFileViewer() async -> Result<Void, Error> {
        registerWithLaunchServices()
        do {
            try setGlobalFileViewer(bundleIdentifier)
            try appendFolderHandlers(bundleIdentifier: bundleIdentifier)
            await applyWorkspaceDefault(bundleURL: Bundle.main.bundleURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func restoreFinderAsDefault() async -> Result<Void, Error> {
        guard let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: finderBundleIdentifier) else {
            return .failure(DefaultFileViewerError.finderNotFound)
        }
        do {
            try clearGlobalFileViewer()
            try appendFolderHandlers(bundleIdentifier: finderBundleIdentifier)
            await applyWorkspaceDefault(bundleURL: finderURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private static func registerWithLaunchServices() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    private static func setGlobalFileViewer(_ bundleIdentifier: String) throws {
        CFPreferencesSetAppValue(
            "NSFileViewer" as CFString,
            bundleIdentifier as CFString,
            kCFPreferencesAnyApplication
        )
        guard CFPreferencesAppSynchronize(kCFPreferencesAnyApplication) else {
            throw DefaultFileViewerError.preferencesSyncFailed
        }
    }

    private static func clearGlobalFileViewer() throws {
        CFPreferencesSetValue(
            "NSFileViewer" as CFString,
            nil,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesAppSynchronize(kCFPreferencesAnyApplication) else {
            throw DefaultFileViewerError.preferencesSyncFailed
        }
    }

    private static func appendFolderHandlers(bundleIdentifier: String) throws {
        for roleKey in ["LSHandlerRoleAll", "LSHandlerRoleViewer"] {
            let entry = "{LSHandlerContentType=\"public.folder\";\(roleKey)=\"\(bundleIdentifier)\";}"
            try runDefaultsAppend(entry)
        }
    }

    private static func runDefaultsAppend(_ entry: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = [
            "write",
            launchServicesDomain,
            "LSHandlers",
            "-array-add",
            entry
        ]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw DefaultFileViewerError.defaultsCommandFailed(process.terminationStatus)
        }
    }

    /// NSWorkspace API 为辅助路径；第三方文件管理器主要依赖 NSFileViewer + LSHandlers。
    private static func applyWorkspaceDefault(bundleURL: URL) async {
        for contentType in managedContentTypes {
            await withCheckedContinuation { continuation in
                NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpen: contentType) { _ in
                    continuation.resume()
                }
            }
        }
    }
}

enum DefaultFileViewerError: LocalizedError {
    case preferencesSyncFailed
    case defaultsCommandFailed(Int32)
    case finderNotFound

    var errorDescription: String? {
        switch self {
        case .preferencesSyncFailed:
            return "无法写入系统偏好设置。"
        case .defaultsCommandFailed(let code):
            return "系统命令执行失败（退出码 \(code)）。"
        case .finderNotFound:
            return "未找到 Finder 应用。"
        }
    }
}
