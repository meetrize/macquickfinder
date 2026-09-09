import XCTest
@testable import Explorer

final class TabListingReconcilePolicyTests: XCTestCase {
    func testShouldReconcileSkipsWhenLocalMTimeUnchanged() {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(
            TabListingReconcilePolicy.shouldReconcileListingOnClaim(
                cachedMTime: stamp,
                currentMTime: stamp,
                isNetwork: false
            )
        )
    }

    func testShouldReconcileWhenLocalMTimeChanged() {
        let cached = Date(timeIntervalSince1970: 1_700_000_000)
        let current = Date(timeIntervalSince1970: 1_700_000_100)
        XCTAssertTrue(
            TabListingReconcilePolicy.shouldReconcileListingOnClaim(
                cachedMTime: cached,
                currentMTime: current,
                isNetwork: false
            )
        )
    }

    func testShouldReconcileWhenEitherMTimeMissing() {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(
            TabListingReconcilePolicy.shouldReconcileListingOnClaim(
                cachedMTime: nil,
                currentMTime: stamp,
                isNetwork: false
            )
        )
        XCTAssertTrue(
            TabListingReconcilePolicy.shouldReconcileListingOnClaim(
                cachedMTime: stamp,
                currentMTime: nil,
                isNetwork: false
            )
        )
        XCTAssertTrue(
            TabListingReconcilePolicy.shouldReconcileListingOnClaim(
                cachedMTime: nil,
                currentMTime: nil,
                isNetwork: false
            )
        )
    }

    func testShouldReconcileAlwaysOnNetworkEvenIfMTimeMatches() {
        let stamp = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertTrue(
            TabListingReconcilePolicy.shouldReconcileListingOnClaim(
                cachedMTime: stamp,
                currentMTime: stamp,
                isNetwork: true
            )
        )
    }

    func testFileItemListingHashEqualForSameIdsInOrder() {
        let a = makeFileItem(id: "/tmp/a", name: "a")
        let b = makeFileItem(id: "/tmp/b", name: "b")
        let hash1 = TabListingReconcilePolicy.fileItemListingHash(for: [a, b])
        let hash2 = TabListingReconcilePolicy.fileItemListingHash(for: [
            makeFileItem(id: "/tmp/a", name: "a-renamed-display"),
            makeFileItem(id: "/tmp/b", name: "b"),
        ])
        XCTAssertEqual(hash1, hash2)
    }

    func testFileItemListingHashDiffersWhenIdsChange() {
        let left = TabListingReconcilePolicy.fileItemListingHash(for: [
            makeFileItem(id: "/tmp/a", name: "a"),
            makeFileItem(id: "/tmp/b", name: "b"),
        ])
        let right = TabListingReconcilePolicy.fileItemListingHash(for: [
            makeFileItem(id: "/tmp/a", name: "a"),
            makeFileItem(id: "/tmp/c", name: "c"),
        ])
        XCTAssertNotEqual(left, right)
    }

    func testFileItemListingHashDiffersWhenOrderChanges() {
        let a = makeFileItem(id: "/tmp/a", name: "a")
        let b = makeFileItem(id: "/tmp/b", name: "b")
        XCTAssertNotEqual(
            TabListingReconcilePolicy.fileItemListingHash(for: [a, b]),
            TabListingReconcilePolicy.fileItemListingHash(for: [b, a])
        )
    }

    private func makeFileItem(id: String, name: String) -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: id),
            name: name,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "public.data",
            sizeDisplay: "—",
            dateDisplay: "—",
            creationDateDisplay: "—",
            finderComment: "",
            tags: []
        )
    }
}
