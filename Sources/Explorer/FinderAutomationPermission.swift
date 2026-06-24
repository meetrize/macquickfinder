import AppKit
import ApplicationServices

enum FinderAutomationPermission {
    private static let finderBundleID = "com.apple.finder"
    
    @MainActor
    static func ensureAccess() async -> Bool {
        activateFinder()
        
        if hasAccess() {
            return true
        }
        
        if requestAccessPromptingUser() {
            return true
        }
        
        if await runProbeScript() {
            return true
        }
        
        showAccessDeniedAlert()
        return false
    }
    
    @MainActor
    private static func hasAccess() -> Bool {
        let target = NSAppleEventDescriptor(bundleIdentifier: finderBundleID)
        return AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            false
        ) == noErr
    }
    
    @MainActor
    private static func launchFinderIfNeeded() {
        if NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).isEmpty {
            let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            NSWorkspace.shared.openApplication(at: finderURL, configuration: NSWorkspace.OpenConfiguration())
        }
    }
    
    @MainActor
    private static func requestAccessPromptingUser() -> Bool {
        var status = determinePermission(promptUser: true)
        
        if status == procNotFound {
            launchFinderIfNeeded()
            Thread.sleep(forTimeInterval: 0.6)
            status = determinePermission(promptUser: true)
        }
        
        return status == noErr
    }
    
    @MainActor
    private static func determinePermission(promptUser: Bool) -> OSStatus {
        let target = NSAppleEventDescriptor(bundleIdentifier: finderBundleID)
        return AEDeterminePermissionToAutomateTarget(
            target.aeDesc,
            typeWildCard,
            typeWildCard,
            promptUser
        )
    }
    
    @MainActor
    private static func activateFinder() {
        if let finder = NSRunningApplication.runningApplications(withBundleIdentifier: finderBundleID).first {
            finder.activate(options: [.activateIgnoringOtherApps])
        } else {
            launchFinderIfNeeded()
        }
    }
    
    @MainActor
    private static func runProbeScript() async -> Bool {
        let scriptSource = """
        tell application "Finder"
            return name
        end tell
        """
        
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: scriptSource) else { return false }
        _ = appleScript.executeAndReturnError(&error)
        return error == nil
    }
    
    @MainActor
    private static func showAccessDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "需要自动化权限"
        alert.informativeText = """
        MeoFind 需要「控制 Finder」的权限才能显示废纸篓内容。

        请在「系统设置 → 隐私与安全性 → 自动化」中，允许 MeoFind 控制 Finder。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            openAutomationSettings()
        }
    }
    
    @MainActor
    private static func openAutomationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Automation"
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
