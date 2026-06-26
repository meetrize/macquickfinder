import XCTest
@testable import Explorer

final class RecentServersStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "RecentServersStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testRecordConnectionInsertsAtFront() {
        let store = RecentServersStore(defaults: defaults)
        let first = URL(string: "smb://nas.local/media")!
        let second = URL(string: "ftp://ftp.example.com/pub")!

        store.recordConnection(for: first)
        store.recordConnection(for: second)

        XCTAssertEqual(store.bookmarks.map(\.urlString), [
            second.absoluteString,
            first.absoluteString
        ])
    }

    func testRecordConnectionUpsertsExistingEntry() throws {
        let store = RecentServersStore(defaults: defaults)
        let url = URL(string: "smb://nas.local/share")!
        let earlier = Date(timeIntervalSince1970: 1_000)
        let later = Date(timeIntervalSince1970: 2_000)

        store.recordConnection(for: url, at: earlier)
        store.recordConnection(for: url, at: later)

        XCTAssertEqual(store.bookmarks.count, 1)
        XCTAssertEqual(store.bookmarks.first?.lastConnectedAt, later)
    }

    func testRecordConnectionTrimsToMaxBookmarks() {
        let store = RecentServersStore(defaults: defaults)

        for index in 0..<(RecentServersStore.maxBookmarks + 3) {
            store.recordConnection(for: URL(string: "smb://host\(index).local/share")!)
        }

        XCTAssertEqual(store.bookmarks.count, RecentServersStore.maxBookmarks)
        XCTAssertEqual(store.bookmarks.first?.displayName, "host22.local/share")
    }

    func testPersistenceRoundTrip() {
        let storageKey = "test.recentBookmarks"
        let writer = RecentServersStore(defaults: defaults, storageKey: storageKey)
        writer.recordConnection(for: URL(string: "smb://nas.local/media")!)

        let reader = RecentServersStore(defaults: defaults, storageKey: storageKey)
        XCTAssertEqual(reader.bookmarks.count, 1)
        XCTAssertEqual(reader.bookmarks.first?.urlString, "smb://nas.local/media")
    }

    func testRemoveBookmark() {
        let store = RecentServersStore(defaults: defaults)
        let url = URL(string: "smb://nas.local/media")!
        store.recordConnection(for: url)

        let bookmarkID = try XCTUnwrap(store.bookmarks.first?.id)
        store.removeBookmark(id: bookmarkID)

        XCTAssertTrue(store.bookmarks.isEmpty)
    }
}

final class RemoteServerBookmarkTests: XCTestCase {
    func testDisplayNameIncludesSharePath() {
        let bookmark = RemoteServerBookmark(url: URL(string: "smb://nas.local/media/photos")!)
        XCTAssertEqual(bookmark.displayName, "nas.local/media/photos")
    }

    func testNormalizedIDIsLowercasedURL() {
        let url = URL(string: "SMB://NAS.LOCAL/Media")!
        XCTAssertEqual(RemoteServerBookmark.normalizedID(for: url), "smb://nas.local/media")
    }
}
