import XCTest
import FileList

final class DirectorySizeComputePolicyTests: XCTestCase {
    func testFoldersAffectedByNestedEventPath() {
        let listed: Set<String> = ["/tmp/A", "/tmp/B"]
        let affected = DirectorySizeComputePolicy.foldersAffectedByEvents(
            eventPaths: ["/tmp/A/sub/file.txt"],
            listedFolderPaths: listed
        )
        XCTAssertEqual(affected, ["/tmp/A"])
    }
    
    func testFoldersAffectedIgnoresUnlistedPaths() {
        let listed: Set<String> = ["/tmp/A"]
        let affected = DirectorySizeComputePolicy.foldersAffectedByEvents(
            eventPaths: ["/tmp/other/file.txt"],
            listedFolderPaths: listed
        )
        XCTAssertTrue(affected.isEmpty)
    }
    
    func testShouldStopEnumeratingAtFileLimit() {
        let startedAt = ContinuousClock.now
        XCTAssertTrue(
            DirectorySizeComputePolicy.shouldStopEnumerating(
                fileCount: DirectorySizeComputePolicy.maxEnumeratedFiles,
                startedAt: startedAt,
                now: startedAt
            )
        )
    }
    
    func testShouldStopEnumeratingAfterDuration() {
        let startedAt = ContinuousClock.now - DirectorySizeComputePolicy.maxComputeDuration - .milliseconds(1)
        XCTAssertTrue(
            DirectorySizeComputePolicy.shouldStopEnumerating(
                fileCount: 0,
                startedAt: startedAt,
                now: ContinuousClock.now
            )
        )
    }
}
