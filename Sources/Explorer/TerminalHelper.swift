import AppKit
import Foundation

enum TerminalHelper {
    static func open(at directoryPath: String) {
        let standardizedPath = (directoryPath as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: standardizedPath, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return
        }
        
        // 使用 open 而非 AppleScript，无需「自动化」权限；
        // -n 在 Terminal 已运行时仍新建窗口，-a 指定应用。
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", "Terminal", standardizedPath]
        
        do {
            try process.run()
        } catch {
            print("Failed to open Terminal: \(error)")
        }
    }
}