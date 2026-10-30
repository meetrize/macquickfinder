import XCTest
@testable import Explorer

final class ExternalRevealPrunePolicyTests: XCTestCase {
    func testSameGroupKeepsPreexistingRegisteredTab() {
        let action = ExternalRevealPrunePolicy.sameGroupAction(
            windowPath: "/Volumes/SSD4T/notes",
            targetPath: "/Users/meetrice/Downloads",
            isAnchor: false,
            isNewTab: false,
            isPreexisting: true,
            isGenerationAllowed: false
        )
        XCTAssertEqual(action, .keep)
    }

    func testSameGroupClosesNilShell() {
        let action = ExternalRevealPrunePolicy.sameGroupAction(
            windowPath: nil,
            targetPath: "/Users/meetrice/Downloads",
            isAnchor: false,
            isNewTab: false,
            isPreexisting: false,
            isGenerationAllowed: true
        )
        XCTAssertEqual(action, .close(reason: "same-group-nil-shell"))
    }

    func testSameGroupClosesSurplusAllowedSamePathOnly() {
        let action = ExternalRevealPrunePolicy.sameGroupAction(
            windowPath: "/Users/meetrice/Downloads",
            targetPath: "/Users/meetrice/Downloads",
            isAnchor: false,
            isNewTab: false,
            isPreexisting: false,
            isGenerationAllowed: true
        )
        XCTAssertEqual(action, .close(reason: "surplus-allowed-same-path"))
    }

    func testSameGroupKeepsAnchorAndNewTab() {
        XCTAssertEqual(
            ExternalRevealPrunePolicy.sameGroupAction(
                windowPath: nil,
                targetPath: "/tmp",
                isAnchor: true,
                isNewTab: false,
                isPreexisting: false,
                isGenerationAllowed: false
            ),
            .keep
        )
        XCTAssertEqual(
            ExternalRevealPrunePolicy.sameGroupAction(
                windowPath: "/tmp",
                targetPath: "/tmp",
                isAnchor: false,
                isNewTab: true,
                isPreexisting: false,
                isGenerationAllowed: true
            ),
            .keep
        )
    }

    func testDetachedNeverClosesOtherDirectoryRegisteredWindow() {
        // 回归：新标签独立成组后，不得关掉锚点组里的 notes 等业务标签。
        let action = ExternalRevealPrunePolicy.detachedWindowAction(
            windowPath: "/Volumes/SSD4T/notes",
            targetPath: "/Users/meetrice/Downloads",
            isInAnchorGroup: false,
            isAnchor: false,
            isNewTab: false
        )
        XCTAssertEqual(action, .keep)
    }

    func testDetachedClosesNilShellOutsideAnchorGroup() {
        let action = ExternalRevealPrunePolicy.detachedWindowAction(
            windowPath: nil,
            targetPath: "/Users/meetrice/Downloads",
            isInAnchorGroup: false,
            isAnchor: false,
            isNewTab: false
        )
        XCTAssertEqual(action, .close(reason: "detached-nil-shell"))
    }

    func testDetachedClosesSamePathDuplicateOutsideAnchorGroup() {
        let action = ExternalRevealPrunePolicy.detachedWindowAction(
            windowPath: "/Users/meetrice/Downloads",
            targetPath: "/Users/meetrice/Downloads",
            isInAnchorGroup: false,
            isAnchor: false,
            isNewTab: false
        )
        XCTAssertEqual(action, .close(reason: "detached-same-path-duplicate"))
    }

    func testDetachedKeepsWindowsInAnchorGroup() {
        let action = ExternalRevealPrunePolicy.detachedWindowAction(
            windowPath: "/Volumes/SSD4T/notes",
            targetPath: "/Users/meetrice/Downloads",
            isInAnchorGroup: true,
            isAnchor: false,
            isNewTab: false
        )
        XCTAssertEqual(action, .keep)
    }

    func testRejectOrphanAdoptWithinCooldown() {
        XCTAssertTrue(
            ExternalRevealPrunePolicy.shouldRejectOrphanAdoptAfterReveal(
                secondsSinceRevealMerge: 0.2
            )
        )
        XCTAssertTrue(
            ExternalRevealPrunePolicy.shouldRejectOrphanAdoptAfterReveal(
                secondsSinceRevealMerge: 1.49
            )
        )
        XCTAssertFalse(
            ExternalRevealPrunePolicy.shouldRejectOrphanAdoptAfterReveal(
                secondsSinceRevealMerge: 1.5
            )
        )
        XCTAssertFalse(
            ExternalRevealPrunePolicy.shouldRejectOrphanAdoptAfterReveal(
                secondsSinceRevealMerge: nil
            )
        )
    }
}
