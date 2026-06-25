import AppKit
import SwiftUI

enum FullDiskAccessPermission {
    /// TCC 保护的用户目录/文件；须实际读取内容，`isReadableFile` 不会触发 TCC 校验。
    private static let protectedDirectoryProbes = [
        "Library/Mail",
        "Library/Messages",
        "Library/Calendars",
    ]
    private static let protectedFileProbes = [
        "Library/Safari/Bookmarks.plist",
    ]

    static func hasAccess() -> Bool {
        for relative in protectedDirectoryProbes where canListProtectedDirectory(relative) {
            return true
        }
        for relative in protectedFileProbes where canReadProtectedFile(relative) {
            return true
        }
        return false
    }

    private static func homePath(_ relative: String) -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(relative)
            .path
    }

    private static func canListProtectedDirectory(_ relative: String) -> Bool {
        let path = homePath(relative)
        guard FileManager.default.fileExists(atPath: path) else { return false }
        do {
            _ = try FileManager.default.contentsOfDirectory(atPath: path)
            return true
        } catch {
            return false
        }
    }

    private static func canReadProtectedFile(_ relative: String) -> Bool {
        let path = homePath(relative)
        guard FileManager.default.fileExists(atPath: path) else { return false }
        return FileManager.default.contents(atPath: path) != nil
    }

    @MainActor
    static func openSystemSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AllFiles",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    @MainActor
    static func restartApplication() {
        let bundleURL = Bundle.main.bundleURL
        let bundlePath = bundleURL.path
        let pid = ProcessInfo.processInfo.processIdentifier
        let quotedPath = ShellQuoting.singleQuote(bundlePath)
        // 等当前进程完全退出后再 open，避免 terminate 时杀掉未 detached 的子 shell。
        let relaunchCommand =
            "while /bin/kill -0 \(pid) 2>/dev/null; do /bin/sleep 0.05; done; /usr/bin/open \(quotedPath)"

        if launchDetachedRelaunchWatcher(relaunchCommand) {
            NSApp.terminate(nil)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        }
    }

    /// 通过 nohup 启动独立 watcher，在宿主进程退出后重新打开应用。
    private static func launchDetachedRelaunchWatcher(_ shellCommand: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/nohup")
        process.arguments = ["/bin/sh", "-c", shellCommand]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return true
        } catch {
            return false
        }
    }

    static var appDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "MeoFind"
    }
}

@MainActor
final class FullDiskAccessPromptController: ObservableObject {
    static let shared = FullDiskAccessPromptController()

    @Published private(set) var isPresented = false
    @Published private(set) var hasAccess = FullDiskAccessPermission.hasAccess()
    @Published private(set) var didOpenSystemSettings = false

    private var didCheckOnLaunch = false

    var isPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.isPresented },
            set: { self.isPresented = $0 }
        )
    }

    private init() {}

    func checkOnLaunchIfNeeded() {
        guard !didCheckOnLaunch else { return }
        didCheckOnLaunch = true
        refreshAccessState()
        if !hasAccess {
            isPresented = true
        }
    }

    func refreshAccessState() {
        hasAccess = FullDiskAccessPermission.hasAccess()
    }

    func openSystemSettings() {
        FullDiskAccessPermission.openSystemSettings()
        didOpenSystemSettings = true
    }

    func dismissForNow() {
        isPresented = false
    }

    func restartApplication() {
        FullDiskAccessPermission.restartApplication()
    }

    func handleAppDidBecomeActive() {
        guard isPresented || !didCheckOnLaunch else { return }
        let hadAccess = hasAccess
        refreshAccessState()
        if isPresented && !hadAccess && hasAccess {
            isPresented = false
        }
    }
}

struct FullDiskAccessGate<Content: View>: View {
    @ObservedObject private var prompt = FullDiskAccessPromptController.shared
    @ViewBuilder private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .sheet(isPresented: prompt.isPresentedBinding) {
                FullDiskAccessPromptView()
            }
            .onAppear {
                prompt.checkOnLaunchIfNeeded()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            ) { _ in
                prompt.handleAppDidBecomeActive()
            }
    }
}

private struct FullDiskAccessPromptView: View {
    @ObservedObject private var prompt = FullDiskAccessPromptController.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.exclamationmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                    .symbolRenderingMode(.hierarchical)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.Permission.FullDiskAccess.title)
                        .font(.title2.weight(.semibold))
                    Text(L10n.Permission.FullDiskAccess.message)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                instructionRow(number: 1, text: L10n.Permission.FullDiskAccess.step1)
                instructionRow(
                    number: 2,
                    text: L10n.Permission.FullDiskAccess.step2(FullDiskAccessPermission.appDisplayName)
                )
                instructionRow(
                    number: 3,
                    text: L10n.Permission.FullDiskAccess.step3
                )
            }
            .padding(.vertical, 4)

            if prompt.hasAccess {
                Label(L10n.Permission.FullDiskAccess.detected, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else if prompt.didOpenSystemSettings {
                Label(L10n.Permission.FullDiskAccess.notDetected, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button(L10n.Permission.FullDiskAccess.later) {
                    prompt.dismissForNow()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(L10n.Permission.FullDiskAccess.openSettings) {
                    prompt.openSystemSettings()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button(L10n.Permission.FullDiskAccess.restartApp) {
                    prompt.dismissForNow()
                    dismiss()
                    Task { @MainActor in
                        prompt.restartApplication()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(width: 520)
        .interactiveDismissDisabled()
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number).")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)
            Text(text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
