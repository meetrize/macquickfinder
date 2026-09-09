import XCTest
@testable import Explorer

final class SingleWindowModeDecisionTests: XCTestCase {
    func testNoAnchorCreatesBrowserWindow() {
        XCTAssertEqual(
            ExternalFolderOpenCenter.singleWindowOpenDecision(
                hasBrowserAnchor: false,
                sameDirectoryTabInAnchorGroup: false
            ),
            .createBrowserWindow
        )
    }

    func testSameDirectoryTabReuses() {
        XCTAssertEqual(
            ExternalFolderOpenCenter.singleWindowOpenDecision(
                hasBrowserAnchor: true,
                sameDirectoryTabInAnchorGroup: true
            ),
            .reuseSameDirectoryTab
        )
    }

    func testDifferentDirectoryNavigatesInPlace() {
        XCTAssertEqual(
            ExternalFolderOpenCenter.singleWindowOpenDecision(
                hasBrowserAnchor: true,
                sameDirectoryTabInAnchorGroup: false
            ),
            .navigateInPlaceOnSelectedTab
        )
    }

    /// 回归：有浏览锚点时不得因「选中壳」而落到 createBrowserWindow。
    func testHasAnchorAlwaysPrefersInPlaceOrReuse() {
        XCTAssertNotEqual(
            ExternalFolderOpenCenter.singleWindowOpenDecision(
                hasBrowserAnchor: true,
                sameDirectoryTabInAnchorGroup: false
            ),
            .createBrowserWindow
        )
    }
}

@MainActor
final class SingleWindowModeOpenCenterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ExternalFolderOpenCenter.shared.resetForTesting()
        UserDefaults.standard.removeObject(forKey: AppPreferences.General.singleWindowMode)
    }

    override func tearDown() {
        ExternalFolderOpenCenter.shared.resetForTesting()
        UserDefaults.standard.removeObject(forKey: AppPreferences.General.singleWindowMode)
        super.tearDown()
    }

    func testPreferenceDefaultsToDisabled() {
        XCTAssertFalse(ExternalFolderOpenCenter.isSingleWindowModeEnabled)
    }

    func testPreferenceReadsEnabled() {
        UserDefaults.standard.set(true, forKey: AppPreferences.General.singleWindowMode)
        XCTAssertTrue(ExternalFolderOpenCenter.isSingleWindowModeEnabled)
    }

    func testSingleWindowWarmWithoutAnchorStillOpensFolderWindow() {
        let center = ExternalFolderOpenCenter.shared
        center.markSessionEstablished()
        UserDefaults.standard.set(true, forKey: AppPreferences.General.singleWindowMode)

        var openedDirectory: String?
        var openCount = 0
        center.setOpenFolderWindowHandler { request in
            openedDirectory = request.directoryPath
            openCount += 1
        }

        center.requestOpen(urls: [URL(fileURLWithPath: "/tmp/single-window-reveal.png")])

        XCTAssertEqual(openedDirectory, "/tmp")
        XCTAssertEqual(openCount, 1)
        XCTAssertNil(center.targetRequest)
        XCTAssertNil(center.consumePendingRequest())
    }

    func testDisabledModeWarmWithoutAnchorStillOpensFolderWindow() {
        let center = ExternalFolderOpenCenter.shared
        center.markSessionEstablished()
        UserDefaults.standard.set(false, forKey: AppPreferences.General.singleWindowMode)

        var openedDirectory: String?
        center.setOpenFolderWindowHandler { request in
            openedDirectory = request.directoryPath
        }

        center.requestOpen(urls: [URL(fileURLWithPath: "/tmp/multi-window-reveal.png")])

        XCTAssertEqual(openedDirectory, "/tmp")
    }
}
