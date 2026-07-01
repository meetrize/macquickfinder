import XCTest
@testable import Explorer

final class SnippetRecordingDraftBuilderTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("snippet-draft-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    private func step(_ operation: RecordedOperation) -> RecordedOperationStep {
        RecordedOperationStep(operation: operation)
    }

    private func makeFile(named name: String) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name)
        FileManager.default.createFile(atPath: url.path, contents: Data())
        return url
    }

    private func makeDirectory(named name: String) throws -> URL {
        let url = temporaryDirectory.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testCreationOnlyInfersAnytimeScope() {
        let steps = [
            step(.createDirectory(url: URL(fileURLWithPath: "/tmp/backup"))),
            step(.createFile(url: URL(fileURLWithPath: "/tmp/readme.txt"))),
        ]
        let scope = SnippetRecordingDraftBuilder.inferScope(from: steps.map(\.operation), recordingCWD: "/tmp")
        XCTAssertEqual(scope, .anytime)
    }

    func testSingleRenameInfersSingleSelection() {
        let steps = [
            step(.rename(
                source: URL(fileURLWithPath: "/tmp/a.txt"),
                destination: URL(fileURLWithPath: "/tmp/b.txt")
            )),
        ]
        let scope = SnippetRecordingDraftBuilder.inferScope(from: steps.map(\.operation), recordingCWD: "/tmp")
        XCTAssertEqual(scope, .singleSelection)
    }

    func testMultipleSameExtensionInfersFileExtensions() throws {
        let first = try makeFile(named: "a.txt")
        let second = try makeFile(named: "b.txt")
        let operations = [
            RecordedOperation.trash(items: [first]),
            RecordedOperation.trash(items: [second]),
        ]
        let scope = SnippetRecordingDraftBuilder.inferScope(
            from: operations,
            recordingCWD: temporaryDirectory.path
        )
        XCTAssertEqual(scope, .fileExtensions(["txt"]))
    }

    func testMultipleFilesDifferentExtensionsInfersFilesOnly() throws {
        let first = try makeFile(named: "a.txt")
        let second = try makeFile(named: "b.pdf")
        let operations = [
            RecordedOperation.trash(items: [first, second]),
        ]
        let scope = SnippetRecordingDraftBuilder.inferScope(
            from: operations,
            recordingCWD: temporaryDirectory.path
        )
        XCTAssertEqual(scope, .filesOnly)
    }

    func testMultipleDirectoriesInfersDirectoriesOnly() throws {
        let first = try makeDirectory(named: "alpha")
        let second = try makeDirectory(named: "beta")
        let operations = [
            RecordedOperation.trash(items: [first, second]),
        ]
        let scope = SnippetRecordingDraftBuilder.inferScope(
            from: operations,
            recordingCWD: temporaryDirectory.path
        )
        XCTAssertEqual(scope, .directoriesOnly)
    }

    func testScopeLabelFormatsExtensions() {
        let label = SnippetRecordingDraftBuilder.scopeLabel(for: .fileExtensions(["txt", "md"]))
        XCTAssertTrue(label.contains("txt"))
        XCTAssertTrue(label.contains("md"))
        XCTAssertNotEqual(label, "snippets.scope.file_extensions")
    }

    func testBuildUsesSuggestedNameAndScript() {
        let steps = [step(.createDirectory(url: URL(fileURLWithPath: "/tmp/backup")))]
        let draft = SnippetRecordingDraftBuilder.build(
            steps: steps,
            script: "mkdir backup",
            recordingCWD: "/tmp"
        )
        XCTAssertEqual(draft.content, "mkdir backup")
        XCTAssertEqual(draft.suggestedScope, .anytime)
        XCTAssertFalse(draft.suggestedName.isEmpty)
        XCTAssertNotEqual(draft.suggestedName, "operation_recording.default_snippet_name")
    }
}
