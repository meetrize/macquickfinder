import XCTest
@testable import Explorer

@MainActor
final class PreviewSessionStoreTests: XCTestCase {
    private func makeFileItem(id: String = "file-a") -> FileItem {
        FileItem(
            id: id,
            url: URL(fileURLWithPath: "/tmp/\(id).txt"),
            name: "\(id).txt",
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: "txt",
            sizeDisplay: "0 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testRemoveClearsLoadedPreviewContent() {
        let store = PreviewSessionStore.shared
        let hostID = UUID()
        let session = PreviewSession(hostWindowID: hostID, file: makeFileItem())
        session.content.textContent = "preview body"
        session.content.loadPhase = .loaded

        store.register(session)
        store.remove(session.id)

        XCTAssertNil(store.session(for: session.id))
        XCTAssertEqual(session.content.textContent, "")
        XCTAssertEqual(session.content.loadPhase, .idle)
    }

    func testRegisterAndRemoveSession() {
        let store = PreviewSessionStore.shared
        let hostID = UUID()
        let session = PreviewSession(hostWindowID: hostID, file: makeFileItem())

        store.register(session)
        XCTAssertNotNil(store.session(for: session.id))

        store.remove(session.id)
        XCTAssertNil(store.session(for: session.id))
    }

    func testExistingInlineSessionLookup() {
        let store = PreviewSessionStore.shared
        let hostID = UUID()
        let file = makeFileItem()
        let session = PreviewSession(hostWindowID: hostID, file: file)
        store.register(session)

        XCTAssertEqual(store.existingInlineSession(hostWindowID: hostID, fileID: file.id)?.id, session.id)

        session.location = .detached(windowNumber: 1)
        XCTAssertNil(store.existingInlineSession(hostWindowID: hostID, fileID: file.id))

        store.remove(session.id)
    }

    func testRemoveInlineSessionsPreservesDetached() {
        let store = PreviewSessionStore.shared
        let hostID = UUID()
        let inline = PreviewSession(hostWindowID: hostID, file: makeFileItem(id: "inline"))
        let detached = PreviewSession(hostWindowID: hostID, file: makeFileItem(id: "detached"))
        detached.location = .detached(windowNumber: 42)
        detached.content.textContent = "detached body"

        store.register(inline)
        store.register(detached)

        store.removeInlineSessions(forHostWindowID: hostID)

        XCTAssertNil(store.session(for: inline.id))
        XCTAssertNotNil(store.session(for: detached.id))
        XCTAssertEqual(detached.content.textContent, "detached body")

        store.remove(detached.id)
    }
}
