import XCTest
@testable import Explorer
import FileList

@MainActor
final class OperationRecordingIntegrationTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("operation-recording-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        OperationRecordingHub.unregister(OperationRecordingHub.activeRecorder ?? OperationRecorder())
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }

    private func makeFileItem(name: String, isDirectory: Bool = false) -> FileItem {
        let url = tempDirectory.appendingPathComponent(name, isDirectory: isDirectory)
        return FileItem(
            id: url.path,
            url: url,
            name: name,
            isDirectory: isDirectory,
            modificationDate: Date(),
            creationDate: Date(),
            size: 0,
            isHidden: false,
            fileType: isDirectory ? "文件夹" : (name as NSString).pathExtension,
            sizeDisplay: "0 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testCopyPasteRecordsTwoSteps() {
        let sourceURL = tempDirectory.appendingPathComponent("a.txt")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data())
        let item = makeFileItem(name: "a.txt")

        let recorder = OperationRecorder()
        recorder.start(cwd: tempDirectory.path)
        OperationRecordingHub.register(recorder)

        FileOperations.copy([item])
        let pasteExpectation = expectation(description: "paste")
        FileOperations.paste(to: tempDirectory) {
            pasteExpectation.fulfill()
        }
        wait(for: [pasteExpectation], timeout: 2)

        XCTAssertEqual(recorder.steps.count, 2)
        if case .copy = recorder.steps[0].operation {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected copy as first step")
        }
        if case .paste = recorder.steps[1].operation {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected paste as second step")
        }
    }

    func testRenameRecordsSingleStep() {
        let sourceURL = tempDirectory.appendingPathComponent("old.txt")
        FileManager.default.createFile(atPath: sourceURL.path, contents: Data())
        let item = makeFileItem(name: "old.txt")

        let recorder = OperationRecorder()
        recorder.start(cwd: tempDirectory.path)
        OperationRecordingHub.register(recorder)

        let result = FileOperations.moveItem(item, toNewName: "new.txt")
        guard case .success = result else {
            XCTFail("Rename failed")
            return
        }

        XCTAssertEqual(recorder.steps.count, 1)
        if case .rename(let source, let destination) = recorder.steps[0].operation {
            XCTAssertEqual(source.lastPathComponent, "old.txt")
            XCTAssertEqual(destination.lastPathComponent, "new.txt")
        } else {
            XCTFail("Expected rename operation")
        }
    }
}
