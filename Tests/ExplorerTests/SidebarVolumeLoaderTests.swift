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

    func testInternalVolumeOffersStorageManagement() {
        let device = SidebarVolume(
            id: "/",
            name: "Macintosh HD",
            path: "/",
            isExternal: false,
            isNetworkVolume: false,
            canEject: false
        )
        XCTAssertTrue(device.canManageStorage)
    }

    func testExternalAndNetworkVolumesDoNotOfferStorageManagement() {
        let external = SidebarVolume(
            id: "/Volumes/Backup",
            name: "Backup",
            path: "/Volumes/Backup",
            isExternal: true,
            isNetworkVolume: false,
            canEject: true
        )
        let network = SidebarVolume(
            id: "/Volumes/Share",
            name: "Share",
            path: "/Volumes/Share",
            isExternal: true,
            isNetworkVolume: true,
            canEject: true
        )
        XCTAssertFalse(external.canManageStorage)
        XCTAssertFalse(network.canManageStorage)
    }
}
