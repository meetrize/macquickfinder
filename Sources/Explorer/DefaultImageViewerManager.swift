import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

enum DefaultImageViewerManager {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.explorer.app"
    static let previewBundleIdentifier = "com.apple.Preview"

    private static let launchServicesDomain = "com.apple.LaunchServices/com.apple.launchservices.secure"

    /// 与 Info.plist `CFBundleDocumentTypes` 及内置图片预览扩展名对齐。
    static let managedContentTypes: [UTType] = {
        let extensions = Array(BuiltinPreviewExtensions.image.union(BuiltinPreviewExtensions.quickLookImage))
        var types: [UTType] = [.image]
        for ext in extensions {
            if let type = UTType(filenameExtension: ext) {
                types.append(type)
            }
        }
        return types
    }()

    static func registerWithLaunchServicesIfNeeded() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    static var workspaceImageHandler: String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: .jpeg) else {
            return nil
        }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    static var effectiveDefaultBundleIdentifier: String {
        workspaceImageHandler ?? previewBundleIdentifier
    }

    static var isDefaultImageViewer: Bool {
        workspaceImageHandler == bundleIdentifier
    }

    static func displayName(for bundleIdentifier: String) -> String {
        if bundleIdentifier == Self.bundleIdentifier {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? "MeoFind"
        }
        if bundleIdentifier == previewBundleIdentifier {
            return "Preview"
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: appURL.path)
        }
        return bundleIdentifier
    }

    static func setAsDefaultImageViewer() async -> Result<Void, Error> {
        DefaultFileViewerManager.registerWithLaunchServicesIfNeeded()
        do {
            try setLaunchServicesDefaultHandlers(bundleIdentifier: bundleIdentifier)
            try appendImageHandlers(bundleIdentifier: bundleIdentifier)
            await applyWorkspaceDefault(bundleURL: Bundle.main.bundleURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func restorePreviewAsDefault() async -> Result<Void, Error> {
        guard let previewURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: previewBundleIdentifier) else {
            return .failure(DefaultImageViewerError.previewNotFound)
        }
        do {
            try removeImageHandlers(bundleIdentifier: bundleIdentifier)
            try setLaunchServicesDefaultHandlers(bundleIdentifier: previewBundleIdentifier)
            await applyWorkspaceDefault(bundleURL: previewURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private static func setLaunchServicesDefaultHandlers(bundleIdentifier: String) throws {
        for contentType in managedContentTypes {
            let status = LSSetDefaultRoleHandlerForContentType(
                contentType.identifier as CFString,
                .viewer,
                bundleIdentifier as CFString
            )
            guard status == noErr else {
                throw DefaultImageViewerError.launchServicesFailed(status)
            }
        }
    }

    private static func appendImageHandlers(bundleIdentifier: String) throws {
        for contentType in managedContentTypes {
            for roleKey in ["LSHandlerRoleAll", "LSHandlerRoleViewer"] {
                let entry = "{LSHandlerContentType=\"\(contentType.identifier)\";\(roleKey)=\"\(bundleIdentifier)\";}"
                try runDefaultsAppend(entry)
            }
        }
    }

    private static func removeImageHandlers(bundleIdentifier: String) throws {
        var handlers = copyLaunchServicesHandlers()
        let managedIdentifiers = Set(managedContentTypes.map(\.identifier))
        let originalCount = handlers.count
        handlers.removeAll { handler in
            guard let contentType = handler["LSHandlerContentType"] as? String,
                  managedIdentifiers.contains(contentType) else {
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
            throw DefaultImageViewerError.preferencesSyncFailed
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
            throw DefaultImageViewerError.defaultsCommandFailed(process.terminationStatus)
        }
    }

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

enum DefaultImageViewerError: LocalizedError {
    case preferencesSyncFailed
    case defaultsCommandFailed(Int32)
    case previewNotFound
    case launchServicesFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .preferencesSyncFailed:
            return L10n.Error.DefaultImageViewer.preferencesSync
        case .defaultsCommandFailed(let code):
            return L10n.Error.DefaultImageViewer.defaultsCommand(code)
        case .previewNotFound:
            return L10n.Error.DefaultImageViewer.previewNotFound
        case .launchServicesFailed(let status):
            return L10n.Error.DefaultImageViewer.launchServices(status)
        }
    }
}
