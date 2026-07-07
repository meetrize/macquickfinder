import XCTest
@testable import Explorer

final class GitCLITests: XCTestCase {
    private let preferencesKey = AppPreferences.Git.customExecutablePath

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: preferencesKey)
        super.tearDown()
    }

    func testResolveExecutableURLUsesCustomPathWhenSet() {
        let custom = "/tmp/custom-git-\(UUID().uuidString)"
        UserDefaultsStorage.set(custom, forKey: preferencesKey)

        XCTAssertEqual(GitCLI.resolveExecutableURL().path, custom)
    }

    func testIsAvailableReflectsExecutablePresence() {
        let existing = GitCLI.resolveExecutableURL()
        XCTAssertEqual(GitCLI.isAvailable, GitCLI.isExecutableFile(at: existing))
    }

    func testIsAvailableFalseForMissingCustomPath() {
        let missing = "/tmp/missing-git-\(UUID().uuidString)"
        UserDefaultsStorage.set(missing, forKey: preferencesKey)

        XCTAssertFalse(GitCLI.isAvailable)
        XCTAssertEqual(GitCLI.resolveExecutableURL().path, missing)
    }
}

@MainActor
final class GitStatusStoreMissingGitTests: XCTestCase {
    private let preferencesKey = AppPreferences.Git.customExecutablePath

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: preferencesKey)
        super.tearDown()
    }

    func testRefreshReportsExecutableNotFoundWhenGitMissing() async {
        UserDefaultsStorage.set("/tmp/missing-git-\(UUID().uuidString)", forKey: preferencesKey)

        let store = GitStatusStore(cli: .live)
        await store.refresh(cwd: "/")

        XCTAssertFalse(store.isRefreshing)
        XCTAssertNil(store.snapshot)
        XCTAssertEqual(store.lastError, L10n.Git.Error.executableNotFound)
    }
}
