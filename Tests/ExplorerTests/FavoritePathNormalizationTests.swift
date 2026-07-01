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

    func testIsDescendantUsesCanonicalPaths() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let desktop = (home as NSString).appendingPathComponent("Desktop")
        let fileOnDesktop = (desktop as NSString).appendingPathComponent("note.txt")
        XCTAssertTrue(FavoritePathNormalization.isDescendant(path: fileOnDesktop, of: desktop))
        XCTAssertFalse(FavoritePathNormalization.isDescendant(path: desktop, of: desktop))
        XCTAssertFalse(FavoritePathNormalization.isDescendant(path: "/tmp/other", of: desktop))
    }
}
