import XCTest
import FileList

final class DirectoryListingFSEventsPolicyTests: XCTestCase {
    func testDirectChildEventAffectsListing() {
        XCTAssertTrue(
            DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: ["/tmp/dir/new-file.txt"],
                directoryPath: "/tmp/dir"
            )
        )
    }
    
    func testNestedEventDoesNotAffectListing() {
        XCTAssertFalse(
            DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: ["/tmp/dir/sub/file.txt"],
                directoryPath: "/tmp/dir"
            )
        )
    }
    
    func testDirectorySelfEventAffectsListing() {
        XCTAssertTrue(
            DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: ["/tmp/dir/"],
                directoryPath: "/tmp/dir"
            )
        )
    }
    
    func testUnrelatedPathDoesNotAffectListing() {
        XCTAssertFalse(
            DirectoryListingFSEventsPolicy.listingAffectedByEvents(
                eventPaths: ["/tmp/other/file.txt"],
                directoryPath: "/tmp/dir"
            )
        )
    }
}
