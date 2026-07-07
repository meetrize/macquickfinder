import AppKit
import Foundation

@MainActor
final class GitSettingsModel: ObservableObject {
    @Published private(set) var resolvedPath = "/usr/bin/git"
    @Published private(set) var isAvailable = false
    @Published private(set) var hasCustomPath = false
    @Published private(set) var versionString: String?
    @Published var alertMessage: String?

    private let store = GitSettingsStore.shared

    func refresh() {
        resolvedPath = store.resolvedExecutableURL.path
        isAvailable = store.isAvailable
        hasCustomPath = store.customExecutablePath != nil
        versionString = readVersion()
    }

    func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.title = L10n.Settings.Git.choosePanelTitle
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.treatsFilePackagesAsDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let path = url.path
        guard GitCLI.isExecutableFile(at: url) else {
            alertMessage = L10n.Settings.Git.invalidExecutable
            return
        }

        store.setCustomExecutablePath(path)
        refresh()
    }

    func resetToAutoDetect() {
        store.setCustomExecutablePath(nil)
        refresh()
        if !isAvailable {
            alertMessage = L10n.Settings.Git.notFound
        }
    }

    private func readVersion() -> String? {
        guard isAvailable else { return nil }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: resolvedPath)
        process.arguments = ["--version"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return nil
        }
    }
}
