import XCTest
@testable import Explorer

final class PreviewTextEditStateLogicTests: XCTestCase {
    func testHasUnsavedChangesIgnoresLineEndingDifferences() {
        XCTAssertFalse(
            PreviewTextEditStateLogic.hasUnsavedChanges(
                liveContent: "a\r\nb",
                originalContent: "a\nb"
            )
        )
    }

    func testHasUnsavedChangesDetectsContentChange() {
        XCTAssertTrue(
            PreviewTextEditStateLogic.hasUnsavedChanges(
                liveContent: "hello",
                originalContent: "world"
            )
        )
    }
}

final class PreviewTextEditNavigationPromptTests: XCTestCase {
    func testSaveResponseProceedsAndRequestsSave() {
        XCTAssertEqual(
            PreviewTextEditNavigationPrompt.decision(for: .alertFirstButtonReturn),
            .proceed
        )
        XCTAssertTrue(
            PreviewTextEditNavigationPrompt.shouldSaveBeforeProceeding(response: .alertFirstButtonReturn)
        )
    }

    func testDiscardResponseProceedsWithoutSave() {
        XCTAssertEqual(
            PreviewTextEditNavigationPrompt.decision(for: .alertSecondButtonReturn),
            .proceed
        )
        XCTAssertTrue(
            PreviewTextEditNavigationPrompt.shouldDiscardBeforeProceeding(response: .alertSecondButtonReturn)
        )
    }

    func testCancelResponseBlocksNavigation() {
        XCTAssertEqual(
            PreviewTextEditNavigationPrompt.decision(for: .alertThirdButtonReturn),
            .cancelled
        )
    }
}

@MainActor
final class PreviewSessionTextEditTests: XCTestCase {
    private func makeWritableFile(named name: String, content: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("PreviewSessionTextEdit-\(UUID().uuidString)-\(name)")
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func makeFileItem(url: URL) -> FileItem {
        FileItem(
            id: url.path,
            url: url,
            name: url.lastPathComponent,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: url.pathExtension,
            sizeDisplay: "0 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testEnterTextEditModeFromMarkdownPreviewSwitchesToSource() throws {
        let url = try makeWritableFile(named: "sample.md", content: "# Title")
        defer { try? FileManager.default.removeItem(at: url) }

        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem(url: url))
        session.content.textContent = "# Title"
        session.content.loadPhase = .loaded
        session.text.markdownMode = .preview

        session.enterTextEditMode()

        XCTAssertEqual(session.text.markdownMode, .source)
        XCTAssertEqual(session.text.displayMode, .editing)
    }

    func testEnterTextEditModeRequiresEligibility() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: makeFileItem(url: URL(fileURLWithPath: "/tmp/unwritable.txt"))
        )
        session.content.textContent = "hello"
        session.content.loadPhase = .loaded

        session.enterTextEditMode()

        XCTAssertEqual(session.text.displayMode, .viewing)
    }

    func testEnterTextEditModeWhenEligible() throws {
        let url = try makeWritableFile(named: "sample.txt", content: "hello")
        defer { try? FileManager.default.removeItem(at: url) }

        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem(url: url))
        session.content.textContent = "hello"
        session.content.loadPhase = .loaded
        session.syncTextEditStateAfterLoad()

        session.enterTextEditMode()

        XCTAssertEqual(session.text.displayMode, .editing)
        XCTAssertEqual(session.text.liveEditContent, "hello")
        XCTAssertFalse(session.text.hasUnsavedChanges)
    }

    func testUpdateTextEditDirtyState() throws {
        let url = try makeWritableFile(named: "sample.txt", content: "hello")
        defer { try? FileManager.default.removeItem(at: url) }

        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem(url: url))
        session.content.textContent = "hello"
        session.content.loadPhase = .loaded
        session.enterTextEditMode()

        session.updateTextEditDirtyState(with: "hello world")

        XCTAssertTrue(session.text.hasUnsavedChanges)
        XCTAssertEqual(session.text.liveEditContent, "hello world")
    }

    func testApplyTextEditRevertThroughRevertWithoutConfirm() async throws {
        let url = try makeWritableFile(named: "sample.txt", content: "hello")
        defer { try? FileManager.default.removeItem(at: url) }

        let session = PreviewSession(hostWindowID: UUID(), file: makeFileItem(url: url))
        session.content.textContent = "hello"
        session.content.loadPhase = .loaded
        session.enterTextEditMode()
        session.updateTextEditDirtyState(with: "changed")

        let reverted = await session.revertTextEdits(skipConfirm: true)

        XCTAssertTrue(reverted)
        XCTAssertEqual(session.text.displayMode, .viewing)
        XCTAssertEqual(session.content.textContent, "hello")
        XCTAssertFalse(session.text.hasUnsavedChanges)
    }

    func testSyncTextEditStateAfterLoadResetsEditing() {
        let session = PreviewSession(
            hostWindowID: UUID(),
            file: makeFileItem(url: URL(fileURLWithPath: "/tmp/sample.txt"))
        )
        session.text.displayMode = .editing
        session.text.hasUnsavedChanges = true
        session.content.textContent = "loaded"

        session.syncTextEditStateAfterLoad()

        XCTAssertEqual(session.text.displayMode, .viewing)
        XCTAssertEqual(session.text.originalContent, "loaded")
        XCTAssertFalse(session.text.hasUnsavedChanges)
    }
}
