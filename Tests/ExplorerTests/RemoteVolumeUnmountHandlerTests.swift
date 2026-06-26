import XCTest
@testable import Explorer

final class RemoteVolumeUnmountHandlerTests: XCTestCase {
    func testIsPathInsideVolumeMatchesRootAndChildren() {
        XCTAssertTrue(
            RemoteVolumeUnmountHandler.isPath("/Volumes/nas", insideVolume: "/Volumes/nas")
        )
        XCTAssertTrue(
            RemoteVolumeUnmountHandler.isPath("/Volumes/nas/media/clip.mov", insideVolume: "/Volumes/nas")
        )
        XCTAssertFalse(
            RemoteVolumeUnmountHandler.isPath("/Volumes/nas-backup", insideVolume: "/Volumes/nas")
        )
    }

    func testResolveFallbackPathReturnsNilWhenOutsideUnmountedVolume() {
        let result = RemoteVolumeUnmountHandler.resolveFallbackPath(
            from: "/Users/test/Documents",
            unmountedVolumePath: "/Volumes/nas",
            homeDirectory: "/Users/test"
        )
        XCTAssertNil(result)
    }

    func testResolveFallbackPathFallsBackToHome() {
        let result = RemoteVolumeUnmountHandler.resolveFallbackPath(
            from: "/Volumes/nas/media",
            unmountedVolumePath: "/Volumes/nas",
            homeDirectory: "/Users/test"
        )
        XCTAssertEqual(result, "/Users/test")
    }
}

final class DirectorySizeVolumeFilterTests: XCTestCase {
    func testIsNetworkVolumeIsInverseOfShouldAutoCalculateForLocalHome() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertEqual(
            DirectorySizeVolumeFilter.isNetworkVolume(path: home),
            !DirectorySizeVolumeFilter.shouldAutoCalculate(path: home)
        )
    }
}
