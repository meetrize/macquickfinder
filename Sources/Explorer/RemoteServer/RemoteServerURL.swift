import Foundation

enum RemoteServerURL {
    static let defaultScheme = "smb"

    static let supportedSchemes: Set<String> = [
        "smb", "nfs", "afp", "http", "https", "ftp"
    ]

    static let deferredSchemes: Set<String> = ["sftp"]

    static let blockedSchemes: Set<String> = [
        "file", "javascript", "data"
    ]

    enum NormalizeResult: Equatable {
        case success(URL)
        case invalidURL
        case unsupportedProtocol(String)
    }

    static func normalize(_ input: String) -> NormalizeResult {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalidURL }

        var candidate = trimmed
        if !candidate.contains("://") {
            candidate = "\(defaultScheme)://\(candidate)"
        }

        guard let url = URL(string: candidate), let scheme = url.scheme?.lowercased() else {
            return .invalidURL
        }

        if blockedSchemes.contains(scheme) {
            return .invalidURL
        }

        if deferredSchemes.contains(scheme) {
            return .unsupportedProtocol(scheme)
        }

        guard supportedSchemes.contains(scheme) else {
            return .invalidURL
        }

        guard let host = url.host, !host.isEmpty else {
            return .invalidURL
        }

        return .success(url)
    }

    static func isFTP(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "ftp"
    }

    static func displayHost(for url: URL) -> String {
        url.host ?? url.absoluteString
    }
}

enum RemoteMountError: LocalizedError, Equatable {
    case invalidURL
    case cancelled
    case timeout
    case alreadyMounted(URL)
    case mountFailed(String)
    case ambiguousNewVolumes([URL])
    case unsupportedProtocol(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return L10n.RemoteServer.Error.invalidURL
        case .cancelled, .alreadyMounted:
            return nil
        case .timeout:
            return L10n.RemoteServer.Error.timeout
        case .mountFailed(let detail):
            return L10n.RemoteServer.Error.mountFailed(detail)
        case .ambiguousNewVolumes:
            return L10n.RemoteServer.Error.ambiguousNewVolumes
        case .unsupportedProtocol(let scheme):
            if scheme.lowercased() == "sftp" {
                return L10n.RemoteServer.Error.sftpDeferred
            }
            return L10n.RemoteServer.Error.unsupportedProtocol(scheme)
        }
    }
}
