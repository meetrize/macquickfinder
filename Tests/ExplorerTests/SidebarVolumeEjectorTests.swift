import XCTest
@testable import Explorer

final class SidebarVolumeEjectorTests: XCTestCase {
    func testEjectRejectsNonEjectableDevice() {
        let device = SidebarVolume(
            id: "/",
            name: "Macintosh HD",
            path: "/",
            isExternal: false,
            isNetworkVolume: false,
            canEject: false
        )
        let exp = expectation(description: "completion")
        SidebarVolumeEjector.eject(device) { success in
            XCTAssertFalse(success)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 2)
    }
}
