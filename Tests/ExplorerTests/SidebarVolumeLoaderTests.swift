import XCTest
@testable import Explorer

final class SidebarVolumeLoaderTests: XCTestCase {
    func testCanEjectVolumeAllowsNetworkVolumeWhenNotEjectable() {
        XCTAssertTrue(
            SidebarVolumeLoader.canEjectVolume(
                isExternal: true,
                isEjectable: false,
                isNetworkVolume: true
            )
        )
    }

    func testCanEjectVolumeAllowsEjectableExternalDrive() {
        XCTAssertTrue(
            SidebarVolumeLoader.canEjectVolume(
                isExternal: true,
                isEjectable: true,
                isNetworkVolume: false
            )
        )
    }

    func testCanEjectVolumeRejectsInternalVolume() {
        XCTAssertFalse(
            SidebarVolumeLoader.canEjectVolume(
                isExternal: false,
                isEjectable: true,
                isNetworkVolume: false
            )
        )
    }

    func testCanEjectVolumeRejectsNonEjectableLocalExternal() {
        XCTAssertFalse(
            SidebarVolumeLoader.canEjectVolume(
                isExternal: true,
                isEjectable: false,
                isNetworkVolume: false
            )
        )
    }
}
