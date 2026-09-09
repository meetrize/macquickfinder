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
            try upsertFolderHandlers(bundleIdentifier: bundleIdentifier)
            try setLaunchServicesDefaultHandlers(bundleIdentifier: bundleIdentifier)
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
            try upsertFolderHandlers(bundleIdentifier: finderBundleIdentifier)
            try setLaunchServicesDefaultHandlers(bundleIdentifier: finderBundleIdentifier)
            await applyWorkspaceDefault(bundleURL: finderURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func registerWithLaunchServicesIfNeeded() {
        registerWithLaunchServices()
        // 自愈：已是 NSFileViewer 但 public.folder 丢失时，微信「打开目录」会落到 Finder 或无响应。
        if globalFileViewerBundleIdentifier == bundleIdentifier {
            try? upsertFolderHandlers(bundleIdentifier: bundleIdentifier)
        }
    }

    private static func registerWithLaunchServices() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    private static func setLaunchServicesDefaultHandlers(bundleIdentifier: String) throws {
        for contentType in managedContentTypes {
            let status = LSSetDefaultRoleHandlerForContentType(
                contentType.identifier as CFString,
                .viewer,
                bundleIdentifier as CFString
            )
            // public.folder 无法通过此 API 设置（macOS 返回 paramErr），依赖 NSFileViewer + LSHandlers。
            if status == paramErr, contentType == .folder {
                continue
            }
            guard status == noErr else {
                throw DefaultFileViewerError.launchServicesFailed(status)
            }
        }
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

    /// 写入 / 覆盖 `public.folder` 的 LSHandlers（`defaults -array-add` 易丢失，导致打开目录仍走 Finder）。
    private static func upsertFolderHandlers(bundleIdentifier: String) throws {
        var handlers = copyLaunchServicesHandlers()
        handlers.removeAll { handler in
            handler["LSHandlerContentType"] as? String == UTType.folder.identifier
        }
        handlers.append([
            "LSHandlerContentType": UTType.folder.identifier,
            "LSHandlerRoleAll": bundleIdentifier,
            "LSHandlerRoleViewer": bundleIdentifier,
        ])
        try writeLaunchServicesHandlers(handlers)
    }

    private static func appendFolderHandlers(bundleIdentifier: String) throws {
        try upsertFolderHandlers(bundleIdentifier: bundleIdentifier)
    }

    private static func removeFolderHandlers(bundleIdentifier: String) throws {
        var handlers = copyLaunchServicesHandlers()
        let originalCount = handlers.count
        handlers.removeAll { handler in
            guard handler["LSHandlerContentType"] as? String == UTType.folder.identifier else {
                return false
            }
            for roleKey in ["LSHandlerRoleAll", "LSHandlerRoleViewer", "LSHandlerRoleEditor"] {
                if handler[roleKey] as? String == bundleIdentifier {
                    return true
                }
            }
            return false
        }
        guard handlers.count != originalCount else { return }
        try writeLaunchServicesHandlers(handlers)
    }

    private static func copyLaunchServicesHandlers() -> [[String: Any]] {
        CFPreferencesCopyValue(
            "LSHandlers" as CFString,
            launchServicesDomain as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? [[String: Any]] ?? []
    }

    private static func writeLaunchServicesHandlers(_ handlers: [[String: Any]]) throws {
        CFPreferencesSetValue(
            "LSHandlers" as CFString,
            handlers as CFArray,
            launchServicesDomain as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        )
        guard CFPreferencesSynchronize(
            launchServicesDomain as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) else {
            throw DefaultFileViewerError.preferencesSyncFailed
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
    case launchServicesFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .preferencesSyncFailed:
            return L10n.Error.DefaultViewer.preferencesSync
        case .defaultsCommandFailed(let code):
            return L10n.Error.DefaultViewer.defaultsCommand(code)
        case .finderNotFound:
            return L10n.Error.DefaultViewer.finderNotFound
        case .launchServicesFailed(let status):
            return L10n.Error.DefaultViewer.launchServices(status)
        }
    }
}
