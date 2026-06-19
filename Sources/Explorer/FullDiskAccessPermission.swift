import AppKit
import SwiftUI

enum FullDiskAccessPermission {
    /// 受 TCC 保护的路径；可读即表示已获得完全磁盘访问权限。
    private static let probePath = "/Library/Application Support/com.apple.TCC/TCC.db"

    static func hasAccess() -> Bool {
        FileManager.default.isReadableFile(atPath: probePath)
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
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
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
        refreshAccessState()
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
                    Text("需要完全磁盘访问权限")
                        .font(.title2.weight(.semibold))
                    Text("MeoFind 需要此权限才能浏览系统中的全部文件与文件夹。")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                instructionRow(number: 1, text: "点击下方「打开系统设置」。")
                instructionRow(
                    number: 2,
                    text: "在「隐私与安全性 → 完全磁盘访问权限」中，打开 \(FullDiskAccessPermission.appDisplayName) 的开关。"
                )
                instructionRow(
                    number: 3,
                    text: "返回本应用后，点击「重启应用」使权限生效。"
                )
            }
            .padding(.vertical, 4)

            if prompt.hasAccess {
                Label("已检测到完全磁盘访问权限，请重启应用以完成启用。", systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
            } else if prompt.didOpenSystemSettings {
                Label("尚未检测到权限。请确认已在系统设置中勾选本应用。", systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("稍后") {
                    prompt.dismissForNow()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("打开系统设置") {
                    prompt.openSystemSettings()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])

                Button("重启应用") {
                    prompt.restartApplication()
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
