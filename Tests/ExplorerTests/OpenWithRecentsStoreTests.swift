import XCTest
@testable import Explorer

final class OpenWithRecentsStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "OpenWithRecentsStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        OpenWithRecentsStore.resetCacheForTesting()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        OpenWithRecentsStore.resetCacheForTesting()
        super.tearDown()
    }

    func testFileTypeKeyUsesLowercasedExtension() {
        let url = URL(fileURLWithPath: "/tmp/Photo.PNG")
        XCTAssertEqual(OpenWithRecentsStore.fileTypeKey(for: url), "png")
    }

    func testFileTypeKeyEmptyWhenNoExtension() {
        let url = URL(fileURLWithPath: "/tmp/Makefile")
        XCTAssertEqual(OpenWithRecentsStore.fileTypeKey(for: url), "")
    }

    func testRecordInsertsAtFrontForSameType() {
        let file = URL(fileURLWithPath: "/tmp/a.png")
        let preview = "/Applications/Preview.app"
        let photoshop = "/Applications/Adobe Photoshop.app"

        OpenWithRecentsStore.record(appPath: preview, forTypeKey: "png", defaults: defaults)
        OpenWithRecentsStore.record(appPath: photoshop, forTypeKey: "png", defaults: defaults)

        XCTAssertEqual(
            OpenWithRecentsStore.recentAppPaths(forTypeKey: "png", defaults: defaults),
            [photoshop, preview]
        )
    }

    func testRecordMovesExistingAppToFront() {
        let preview = "/Applications/Preview.app"
        let photoshop = "/Applications/Adobe Photoshop.app"

        OpenWithRecentsStore.record(appPath: preview, forTypeKey: "png", defaults: defaults)
        OpenWithRecentsStore.record(appPath: photoshop, forTypeKey: "png", defaults: defaults)
        OpenWithRecentsStore.record(appPath: preview, forTypeKey: "png", defaults: defaults)

        XCTAssertEqual(
            OpenWithRecentsStore.recentAppPaths(forTypeKey: "png", defaults: defaults),
            [preview, photoshop]
        )
    }

    func testDifferentTypesAreIndependent() {
        OpenWithRecentsStore.record(appPath: "/Applications/Preview.app", forTypeKey: "png", defaults: defaults)
        OpenWithRecentsStore.record(appPath: "/Applications/Preview.app", forTypeKey: "pdf", defaults: defaults)
        OpenWithRecentsStore.record(appPath: "/Applications/Adobe Acrobat.app", forTypeKey: "pdf", defaults: defaults)

        XCTAssertEqual(
            OpenWithRecentsStore.recentAppPaths(forTypeKey: "png", defaults: defaults),
            ["/Applications/Preview.app"]
        )
        XCTAssertEqual(
            OpenWithRecentsStore.recentAppPaths(forTypeKey: "pdf", defaults: defaults),
            ["/Applications/Adobe Acrobat.app", "/Applications/Preview.app"]
        )
    }

    func testRecordTrimsToMaxAppsPerType() {
        for index in 0..<(OpenWithRecentsStore.maxAppsPerType + 3) {
            OpenWithRecentsStore.record(
                appPath: "/Applications/App\(index).app",
                forTypeKey: "txt",
                defaults: defaults
            )
        }
        let paths = OpenWithRecentsStore.recentAppPaths(forTypeKey: "txt", defaults: defaults)
        XCTAssertEqual(paths.count, OpenWithRecentsStore.maxAppsPerType)
        XCTAssertEqual(paths.first, "/Applications/App\(OpenWithRecentsStore.maxAppsPerType + 2).app")
    }

    func testPersistenceRoundTrip() {
        OpenWithRecentsStore.record(
            appPath: "/Applications/Preview.app",
            forTypeKey: "png",
            defaults: defaults
        )
        OpenWithRecentsStore.resetCacheForTesting()

        let reloaded = OpenWithRecentsStore.load(from: defaults)
        XCTAssertEqual(reloaded["png"], ["/Applications/Preview.app"])
    }

    func testRecordViaFileURLUsesExtension() {
        let file = URL(fileURLWithPath: "/tmp/shot.JPEG")
        let app = URL(fileURLWithPath: "/Applications/Preview.app")
        OpenWithRecentsStore.record(appURL: app, forFileURL: file, defaults: defaults)
        XCTAssertEqual(
            OpenWithRecentsStore.recentAppPaths(forFileURL: file, defaults: defaults),
            [OpenWithRecentsStore.normalizedAppPath(app)]
        )
    }

    func testSortAppURLsByRecentsPrefersMRUThenAlphabetical() {
        let alpha = URL(fileURLWithPath: "/Applications/Alpha.app")
        let beta = URL(fileURLWithPath: "/Applications/Beta.app")
        let gamma = URL(fileURLWithPath: "/Applications/Gamma.app")
        let names = [
            OpenWithRecentsStore.normalizedAppPath(alpha): "Alpha",
            OpenWithRecentsStore.normalizedAppPath(beta): "Beta",
            OpenWithRecentsStore.normalizedAppPath(gamma): "Gamma",
        ]
        let recent = [
            OpenWithRecentsStore.normalizedAppPath(gamma),
            OpenWithRecentsStore.normalizedAppPath(alpha),
        ]

        let sorted = OpenWithRecentsStore.sortAppURLsByRecents(
            [beta, alpha, gamma],
            recentPaths: recent,
            displayName: { names[OpenWithRecentsStore.normalizedAppPath($0)] ?? $0.lastPathComponent }
        )

        XCTAssertEqual(
            sorted.map { OpenWithRecentsStore.normalizedAppPath($0) },
            [
                OpenWithRecentsStore.normalizedAppPath(gamma),
                OpenWithRecentsStore.normalizedAppPath(alpha),
                OpenWithRecentsStore.normalizedAppPath(beta),
            ]
        )
    }
}
