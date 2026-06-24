import XCTest
@testable import Explorer

final class FavoritePathNormalizationTests: XCTestCase {
    func testSystemVolumeRootsAreEquivalent() {
        XCTAssertTrue(
            FavoritePathNormalization.pathsRepresentSameLocation("/", "/System/Volumes/Data")
        )
    }

    func testDifferentPathsAreNotEquivalent() {
        XCTAssertFalse(
            FavoritePathNormalization.pathsRepresentSameLocation("/tmp/a", "/tmp/b")
        )
    }
}
