import XCTest
@testable import Explorer

final class OperationShellTranslatorTests: XCTestCase {
    private func step(_ operation: RecordedOperation) -> RecordedOperationStep {
        RecordedOperationStep(operation: operation)
    }

    func testCopyPasteMergedIntoCp() {
        let source = URL(fileURLWithPath: "/tmp/source.txt")
        let destination = URL(fileURLWithPath: "/tmp/dest/source.txt")
        let steps = [
            step(.copy(sources: [source])),
            step(.paste(
                pairs: [RecordedFilePair(source: source, destination: destination)],
                mode: .copy
            )),
        ]

        let script = OperationShellTranslator.translate(steps: steps)
        XCTAssertTrue(script.contains("/bin/cp -R"))
        XCTAssertTrue(script.contains("source.txt"))
        XCTAssertFalse(script.contains("copy(sources"))
    }

    func testCutPasteMergedIntoMv() {
        let source = URL(fileURLWithPath: "/tmp/source.txt")
        let destination = URL(fileURLWithPath: "/tmp/dest/source.txt")
        let steps = [
            step(.cut(sources: [source])),
            step(.paste(
                pairs: [RecordedFilePair(source: source, destination: destination)],
                mode: .move
            )),
        ]

        let script = OperationShellTranslator.translate(steps: steps)
        XCTAssertTrue(script.contains("/bin/mv"))
        XCTAssertFalse(script.contains("/bin/cp"))
    }

    func testRenameUsesMv() {
        let source = URL(fileURLWithPath: "/tmp/old.txt")
        let destination = URL(fileURLWithPath: "/tmp/new.txt")
        let script = OperationShellTranslator.translate(steps: [step(.rename(source: source, destination: destination))])

        XCTAssertEqual(script, "/bin/mv '/tmp/old.txt' '/tmp/new.txt'")
    }

    func testCreateDirectoryUsesMkdir() {
        let url = URL(fileURLWithPath: "/tmp/backup")
        let script = OperationShellTranslator.translate(steps: [step(.createDirectory(url: url))])

        XCTAssertEqual(script, "/bin/mkdir -p '/tmp/backup'")
    }

    func testCreateFileUsesTouch() {
        let url = URL(fileURLWithPath: "/tmp/new.txt")
        let script = OperationShellTranslator.translate(steps: [step(.createFile(url: url))])

        XCTAssertEqual(script, "/usr/bin/touch '/tmp/new.txt'")
    }

    func testTrashUsesOsascript() {
        let url = URL(fileURLWithPath: "/tmp/remove-me.txt")
        let script = OperationShellTranslator.translate(steps: [step(.trash(urls: [url]))])

        XCTAssertTrue(script.contains("/usr/bin/osascript"))
        XCTAssertTrue(script.contains("Finder"))
        XCTAssertTrue(script.contains("/tmp/remove-me.txt"))
    }

    func testExcludedStepsAreOmitted() {
        var renameStep = step(.rename(
            source: URL(fileURLWithPath: "/tmp/a"),
            destination: URL(fileURLWithPath: "/tmp/b")
        ))
        renameStep.isIncluded = false
        let touchStep = step(.createFile(url: URL(fileURLWithPath: "/tmp/c")))

        let script = OperationShellTranslator.translate(steps: [renameStep, touchStep])
        XCTAssertFalse(script.contains("/tmp/a"))
        XCTAssertTrue(script.contains("/tmp/c"))
    }
}
