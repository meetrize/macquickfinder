import XCTest
@testable import Explorer

final class AppBundlePreviewInfoTests: XCTestCase {
    func testLoadSnapshotReadsInfoPlistWhenPresent() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppBundlePreviewInfoTests-\(UUID().uuidString)", isDirectory: true)
        let contents = tempRoot.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "456",
        ]
        let plistURL = contents.appendingPathComponent("Info.plist")
        try (plist as NSDictionary).write(to: plistURL)

        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let snapshot = AppBundlePreviewInfo.loadSnapshot(at: tempRoot.path)
        XCTAssertEqual(snapshot.shortVersion, "1.2.3")
        XCTAssertEqual(snapshot.version, "456")
    }

    func testWorkspaceIconReturnsNonEmptyImage() {
        let icon = AppBundlePreviewInfo.workspaceIcon(at: "/Applications", pointSize: 32)
        XCTAssertGreaterThan(icon.size.width, 0)
        XCTAssertGreaterThan(icon.size.height, 0)
    }
}
