import FileList
import XCTest

@testable import Explorer

@MainActor
final class PanoramaPreferencesTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "PanoramaPreferencesTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testThumbnailLayoutModeDefaultsToGrid() {
        let layout = ExplorerWindowLayoutState(defaults: defaults)

        XCTAssertEqual(layout.thumbnailLayoutMode, .grid)
        XCTAssertEqual(
            defaults.string(forKey: FileListStorageKeys.thumbnailLayoutMode),
            FileListThumbnailLayoutMode.grid.rawValue
        )
    }

    func testThumbnailLayoutModePersistsPanorama() {
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        layout.setThumbnailLayoutMode(.panorama)

        let reloaded = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertEqual(reloaded.thumbnailLayoutMode, .panorama)
    }

    func testPanoramaExpandDepthPolicyDefaultsToAutomatic() {
        let layout = ExplorerWindowLayoutState(defaults: defaults)

        XCTAssertEqual(layout.panoramaExpandDepthPolicy, .automatic)
        XCTAssertEqual(
            defaults.string(forKey: AppPreferences.Panorama.expandDepthPolicy),
            PanoramaExpandDepthPolicy.automatic.rawValue
        )
    }

    func testPanoramaExpandDepthPolicyPersistsDepth5() {
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        layout.setPanoramaExpandDepthPolicy(.depth5)

        let reloaded = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertEqual(reloaded.panoramaExpandDepthPolicy, .depth5)
    }

    func testPanoramaExpandDepthPolicyBootstrapPriorityMaxDepth() {
        XCTAssertEqual(PanoramaExpandDepthPolicy.automatic.bootstrapPriorityMaxDepth, 2)
        XCTAssertEqual(PanoramaExpandDepthPolicy.depth2.bootstrapPriorityMaxDepth, 2)
        XCTAssertEqual(PanoramaExpandDepthPolicy.depth5.bootstrapPriorityMaxDepth, 5)
        XCTAssertNil(PanoramaExpandDepthPolicy.unlimited.bootstrapPriorityMaxDepth)
    }

    func testInvalidStoredThumbnailLayoutModeFallsBackToGrid() {
        defaults.set("invalid", forKey: FileListStorageKeys.thumbnailLayoutMode)

        let layout = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertEqual(layout.thumbnailLayoutMode, .grid)
    }

    func testInvalidStoredExpandDepthPolicyFallsBackToAutomatic() {
        defaults.set("invalid", forKey: AppPreferences.Panorama.expandDepthPolicy)

        let layout = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertEqual(layout.panoramaExpandDepthPolicy, .automatic)
    }
}
