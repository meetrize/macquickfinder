import Foundation

struct RemoteServerBookmark: Codable, Identifiable, Equatable {
    let id: String
    let displayName: String
    let urlString: String
    let lastConnectedAt: Date

    init(url: URL, connectedAt: Date = Date()) {
        id = Self.normalizedID(for: url)
        displayName = Self.makeDisplayName(for: url)
        urlString = url.absoluteString
        lastConnectedAt = connectedAt
    }

    init(id: String, displayName: String, urlString: String, lastConnectedAt: Date) {
        self.id = id
        self.displayName = displayName
        self.urlString = urlString
        self.lastConnectedAt = lastConnectedAt
    }

    var url: URL? {
        URL(string: urlString)
    }

    static func normalizedID(for url: URL) -> String {
        url.absoluteString.lowercased()
    }

    static func makeDisplayName(for url: URL) -> String {
        let host = url.host ?? url.absoluteString
        let trimmedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !trimmedPath.isEmpty else { return host }
        return "\(host)/\(trimmedPath)"
    }
}
