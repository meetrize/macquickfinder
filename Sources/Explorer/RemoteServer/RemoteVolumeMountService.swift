import AppKit
import Foundation

protocol MountedVolumeListing {
    func mountedVolumePaths() -> Set<String>
}

struct DefaultMountedVolumeListing: MountedVolumeListing {
    func mountedVolumePaths() -> Set<String> {
        Set(SidebarVolumeLoader.load().map(\.path))
    }
}

protocol SystemMountOpening {
    @MainActor func open(_ url: URL) throws
}

struct NSWorkspaceSystemMountOpening: SystemMountOpening {
    @MainActor
    func open(_ url: URL) throws {
        guard NSWorkspace.shared.open(url) else {
            throw RemoteMountError.mountFailed("NSWorkspace.open returned false")
        }
    }
}

enum RemoteVolumeMountDiff {
    static func newPaths(before: Set<String>, after: Set<String>) -> [String] {
        Array(after.subtracting(before)).sorted()
    }

    static func matchingHints(from serverURL: URL) -> [String] {
        var hints: [String] = []
        if let host = serverURL.host?.lowercased(), !host.isEmpty {
            hints.append(host)
        }
        let trimmedPath = serverURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let share = trimmedPath.split(separator: "/").first {
            hints.append(String(share).lowercased())
        }
        return Array(Set(hints))
    }

    static func selectMountPath(from newPaths: [String], matching serverURL: URL) -> String? {
        guard !newPaths.isEmpty else { return nil }
        if newPaths.count == 1 { return newPaths[0] }

        let hints = matchingHints(from: serverURL)
        for hint in hints {
            if let match = newPaths.first(where: {
                URL(fileURLWithPath: $0).lastPathComponent.lowercased() == hint
            }) {
                return match
            }
        }
        return newPaths[0]
    }

    static func existingMountPath(for serverURL: URL, among paths: Set<String>) -> String? {
        let hints = matchingHints(from: serverURL)
        for path in paths.sorted() {
            let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()
            if hints.contains(name) {
                return path
            }
        }
        return nil
    }
}

struct RemoteVolumeMountService {
    var volumeListing: any MountedVolumeListing = DefaultMountedVolumeListing()
    var mountOpener: any SystemMountOpening = NSWorkspaceSystemMountOpening()
    var mountWaitTimeout: TimeInterval = 30
    var pollInterval: TimeInterval = 0.5

    func connect(input: String) async throws -> URL {
        switch RemoteServerURL.normalize(input) {
        case .success(let url):
            return try await connect(to: url)
        case .invalidURL:
            throw RemoteMountError.invalidURL
        case .unsupportedProtocol(let scheme):
            throw RemoteMountError.unsupportedProtocol(scheme)
        }
    }

    func connect(to serverURL: URL) async throws -> URL {
        let before = volumeListing.mountedVolumePaths()

        if let existing = RemoteVolumeMountDiff.existingMountPath(for: serverURL, among: before) {
            return URL(fileURLWithPath: existing, isDirectory: true)
        }

        try await MainActor.run {
            try mountOpener.open(serverURL)
        }

        let mountPath = try await waitForNewVolume(excluding: before, serverURL: serverURL)
        return URL(fileURLWithPath: mountPath, isDirectory: true)
    }

    private func waitForNewVolume(
        excluding before: Set<String>,
        serverURL: URL
    ) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.mountWaitTimeout * 1_000_000_000))
                throw RemoteMountError.timeout
            }

            group.addTask {
                while !Task.isCancelled {
                    let current = self.volumeListing.mountedVolumePaths()
                    let newPaths = RemoteVolumeMountDiff.newPaths(before: before, after: current)
                    if let selected = RemoteVolumeMountDiff.selectMountPath(
                        from: newPaths,
                        matching: serverURL
                    ) {
                        return selected
                    }
                    try await Task.sleep(nanoseconds: UInt64(self.pollInterval * 1_000_000_000))
                }
                throw CancellationError()
            }

            guard let result = try await group.next() else {
                throw RemoteMountError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}
