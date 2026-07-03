import AppKit
import XCTest
@testable import Explorer

@MainActor
final class PreviewHostWindowRegistryTests: XCTestCase {
    func testRegisterAndLookupWindow() {
        let registry = PreviewHostWindowRegistry.shared
        let hostWindowID = UUID()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [], backing: .buffered, defer: false)

        registry.register(hostWindowID: hostWindowID, window: window)
        XCTAssertTrue(registry.window(for: hostWindowID) === window)

        registry.unregister(hostWindowID: hostWindowID)
        XCTAssertNil(registry.window(for: hostWindowID))
    }

    func testRevealInHostEventPublishedByCoordinator() {
        let coordinator = PreviewDetachCoordinator.shared
        let hostWindowID = UUID()
        let file = FileItem(
            id: "/tmp/example/preview.txt",
            url: URL(fileURLWithPath: "/tmp/example/preview.txt"),
            name: "preview.txt",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 10,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "10 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
        let session = PreviewSession(hostWindowID: hostWindowID, file: file)
        let revisionBefore = coordinator.revealInHostRevision

        coordinator.revealFileInHostWindow(for: session)

        XCTAssertEqual(coordinator.revealInHostRevision, revisionBefore + 1)
        XCTAssertEqual(coordinator.lastRevealInHostEvent?.hostWindowID, hostWindowID)
        XCTAssertEqual(coordinator.lastRevealInHostEvent?.directoryPath, "/tmp/example")
        XCTAssertEqual(coordinator.lastRevealInHostEvent?.selectionPath, "/tmp/example/preview.txt")
    }
}
