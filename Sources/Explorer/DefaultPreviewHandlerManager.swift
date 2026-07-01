import AppKit
import CoreServices
import Foundation
import UniformTypeIdentifiers

enum DefaultPreviewHandlerManager {
    static let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.explorer.app"
    static let previewBundleIdentifier = "com.apple.Preview"

    private static let launchServicesDomain = "com.apple.LaunchServices/com.apple.launchservices.secure"

    static let imageContentTypes: [UTType] = {
        let extensions = Array(BuiltinPreviewExtensions.image.union(BuiltinPreviewExtensions.quickLookImage))
        var types: [UTType] = [.image]
        var seen = Set<String>()
        for type in types {
            seen.insert(type.identifier)
        }
        for ext in extensions {
            guard let type = UTType(filenameExtension: ext) else { continue }
            if seen.insert(type.identifier).inserted {
                types.append(type)
            }
        }
        return types
    }()

    static func registerWithLaunchServicesIfNeeded() {
        LSRegisterURL(Bundle.main.bundleURL as CFURL, true)
    }

    static func isDefault(for group: PreviewHandlerGroup) -> Bool {
        workspaceHandler(for: group.representativeContentType) == bundleIdentifier
    }

    static func currentHandlerName(for group: PreviewHandlerGroup) -> String {
        let bundleID = workspaceHandler(for: group.representativeContentType)
            ?? group.systemFallbackBundleIdentifier
        return displayName(for: bundleID)
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
        if bundleIdentifier == "com.apple.TextEdit" {
            return "TextEdit"
        }
        if bundleIdentifier == "com.apple.QuickTimePlayerX" {
            return "QuickTime Player"
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: appURL.path)
        }
        return bundleIdentifier
    }

    static func setAsDefault(for group: PreviewHandlerGroup) async -> Result<Void, Error> {
        registerWithLaunchServicesIfNeeded()
        DefaultFileViewerManager.registerWithLaunchServicesIfNeeded()
        do {
            try setLaunchServicesDefaultHandlers(
                bundleIdentifier: bundleIdentifier,
                contentTypes: group.managedContentTypes
            )
            try appendHandlers(bundleIdentifier: bundleIdentifier, contentTypes: group.managedContentTypes)
            await applyWorkspaceDefault(bundleURL: Bundle.main.bundleURL, contentTypes: group.managedContentTypes)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func restoreSystemDefault(for group: PreviewHandlerGroup) async -> Result<Void, Error> {
        let fallbackID = group.systemFallbackBundleIdentifier
        guard let fallbackURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: fallbackID) else {
            return .failure(DefaultPreviewHandlerError.fallbackAppNotFound(fallbackID))
        }
        do {
            try removeHandlers(bundleIdentifier: bundleIdentifier, contentTypes: group.managedContentTypes)
            try setLaunchServicesDefaultHandlers(
                bundleIdentifier: fallbackID,
                contentTypes: group.managedContentTypes
            )
            await applyWorkspaceDefault(bundleURL: fallbackURL, contentTypes: group.managedContentTypes)
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    private static func workspaceHandler(for contentType: UTType) -> String? {
        guard let appURL = NSWorkspace.shared.urlForApplication(toOpen: contentType) else {
            return nil
        }
        return Bundle(url: appURL)?.bundleIdentifier
    }

    private static func setLaunchServicesDefaultHandlers(
        bundleIdentifier: String,
        contentTypes: [UTType]
    ) throws {
        for contentType in contentTypes {
            let status = LSSetDefaultRoleHandlerForContentType(
                contentType.identifier as CFString,
                .viewer,
                bundleIdentifier as CFString
            )
            guard status == noErr else {
                throw DefaultPreviewHandlerError.launchServicesFailed(status)
            }
        }
    }

    private static func appendHandlers(
        bundleIdentifier: String,
        contentTypes: [UTType]
    ) throws {
        for contentType in contentTypes {
            for roleKey in ["LSHandlerRoleAll", "LSHandlerRoleViewer"] {
                let entry = "{LSHandlerContentType=\"\(contentType.identifier)\";\(roleKey)=\"\(bundleIdentifier)\";}"
                try runDefaultsAppend(entry)
            }
        }
    }

    private static func removeHandlers(
        bundleIdentifier: String,
        contentTypes: [UTType]
    ) throws {
        var handlers = copyLaunchServicesHandlers()
        let managedIdentifiers = Set(contentTypes.map(\.identifier))
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
            throw DefaultPreviewHandlerError.preferencesSyncFailed
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
            throw DefaultPreviewHandlerError.defaultsCommandFailed(process.terminationStatus)
        }
    }

    private static func applyWorkspaceDefault(bundleURL: URL, contentTypes: [UTType]) async {
        for contentType in contentTypes {
            await withCheckedContinuation { continuation in
                NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpen: contentType) { _ in
                    continuation.resume()
                }
            }
        }
    }
}

enum DefaultPreviewHandlerError: LocalizedError {
    case preferencesSyncFailed
    case defaultsCommandFailed(Int32)
    case fallbackAppNotFound(String)
    case launchServicesFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .preferencesSyncFailed:
            return L10n.Error.DefaultPreviewHandler.preferencesSync
        case .defaultsCommandFailed(let code):
            return L10n.Error.DefaultPreviewHandler.defaultsCommand(code)
        case .fallbackAppNotFound(let bundleID):
            return L10n.Error.DefaultPreviewHandler.fallbackNotFound(bundleID)
        case .launchServicesFailed(let status):
            return L10n.Error.DefaultPreviewHandler.launchServices(status)
        }
    }
}
