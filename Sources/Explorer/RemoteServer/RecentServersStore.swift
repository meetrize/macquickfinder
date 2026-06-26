import Foundation

@MainActor
final class RecentServersStore: ObservableObject {
    static let shared = RecentServersStore()

    static let maxBookmarks = 20

    @Published private(set) var bookmarks: [RemoteServerBookmark] = []

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = AppPreferences.RemoteServer.recentBookmarks
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        load()
    }

    func recordConnection(for url: URL, at date: Date = Date()) {
        let bookmark = RemoteServerBookmark(url: url, connectedAt: date)
        var updated = bookmarks.filter { $0.id != bookmark.id }
        updated.insert(bookmark, at: 0)
        if updated.count > Self.maxBookmarks {
            updated = Array(updated.prefix(Self.maxBookmarks))
        }
        bookmarks = updated
        save()
    }

    func removeBookmark(id: String) {
        let updated = bookmarks.filter { $0.id != id }
        guard updated.count != bookmarks.count else { return }
        bookmarks = updated
        save()
    }

    private func load() {
        guard let data = UserDefaultsStorage.data(forKey: storageKey, in: defaults) else {
            bookmarks = []
            return
        }
        do {
            bookmarks = try JSONDecoder().decode([RemoteServerBookmark].self, from: data)
        } catch {
            bookmarks = []
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        UserDefaultsStorage.set(data, forKey: storageKey, in: defaults)
    }
}
