import FileList
import XCTest

@testable import Explorer

final class ExplorerSessionRecoveryTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "ExplorerSessionRecoveryTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        ExplorerSessionRecovery.resetPrepareStateForTesting()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        ExplorerSessionRecovery.resetPrepareStateForTesting()
        super.tearDown()
    }

    func testFirstLaunchDoesNotResetViewMode() {
        defaults.set(FileListViewMode.thumbnail.rawValue, forKey: AppPreferences.FileList.viewMode)

        let didReset = ExplorerSessionRecovery.prepareLaunchIfNeeded(defaults: defaults)

        XCTAssertFalse(didReset)
        XCTAssertEqual(
            defaults.string(forKey: AppPreferences.FileList.viewMode),
            FileListViewMode.thumbnail.rawValue
        )
        XCTAssertEqual(defaults.bool(forKey: AppPreferences.Session.exitedCleanly), false)
    }

    func testDirtySessionResetsToDefaultListView() {
        defaults.set(false, forKey: AppPreferences.Session.exitedCleanly)
        defaults.set(FileListViewMode.thumbnail.rawValue, forKey: AppPreferences.FileList.viewMode)

        let didReset = ExplorerSessionRecovery.prepareLaunchIfNeeded(defaults: defaults)

        XCTAssertTrue(didReset)
        XCTAssertEqual(
            defaults.string(forKey: AppPreferences.FileList.viewMode),
            FileListViewMode.list.rawValue
        )
    }

    func testCleanExitPreservesThumbnailViewOnNextLaunch() {
        defaults.set(FileListViewMode.thumbnail.rawValue, forKey: AppPreferences.FileList.viewMode)
        defaults.set(false, forKey: AppPreferences.Session.exitedCleanly)

        _ = ExplorerSessionRecovery.prepareLaunchIfNeeded(defaults: defaults)
        ExplorerSessionRecovery.markCleanExit(defaults: defaults)
        ExplorerSessionRecovery.resetPrepareStateForTesting()

        defaults.set(FileListViewMode.thumbnail.rawValue, forKey: AppPreferences.FileList.viewMode)

        let didReset = ExplorerSessionRecovery.prepareLaunchIfNeeded(defaults: defaults)
        XCTAssertFalse(didReset)
        XCTAssertEqual(
            defaults.string(forKey: AppPreferences.FileList.viewMode),
            FileListViewMode.thumbnail.rawValue
        )
    }

    @MainActor
    func testLayoutStateInitAppliesCrashRecoveryBeforeReadingModes() {
        defaults.set(false, forKey: AppPreferences.Session.exitedCleanly)
        defaults.set(FileListViewMode.thumbnail.rawValue, forKey: AppPreferences.FileList.viewMode)

        let layout = ExplorerWindowLayoutState(defaults: defaults)
        XCTAssertEqual(layout.fileListViewMode, .list)
    }
}
