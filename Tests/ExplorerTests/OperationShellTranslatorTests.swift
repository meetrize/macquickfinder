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

    func testGeneralizeSingleSourceRename() {
        let cwd = "/tmp/project"
        let source = URL(fileURLWithPath: "/tmp/project/old.txt")
        let destination = URL(fileURLWithPath: "/tmp/project/new.txt")
        let steps = [step(.rename(source: source, destination: destination))]
        let script = OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(generalizePaths: true, recordingCWD: cwd)
        )

        XCTAssertTrue(script.contains("%p"))
        XCTAssertTrue(script.contains("'%d/new.txt'"))
        XCTAssertFalse(script.contains("/tmp/project/old.txt"))
    }

    func testGeneralizeRenameExtensionChangeUnderCWD() {
        let cwd = "/tmp/project"
        let source = URL(fileURLWithPath: "/tmp/project/photo.jpg")
        let destination = URL(fileURLWithPath: "/tmp/project/photo.png")
        let steps = [step(.rename(source: source, destination: destination))]
        let script = OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(generalizePaths: true, recordingCWD: cwd)
        )

        XCTAssertTrue(script.contains("/bin/mv %p '%d/%b.png'"))
    }

    func testGeneralizeMoveToDesktopKeepsFileName() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cwd = "/tmp/project"
        let source = URL(fileURLWithPath: "/tmp/project/photo.jpg")
        let destination = URL(fileURLWithPath: "\(home)/Desktop/photo.jpg")
        let steps = [step(.rename(source: source, destination: destination))]
        let script = OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(generalizePaths: true, recordingCWD: cwd)
        )

        XCTAssertTrue(script.contains("/bin/mv %p"))
        XCTAssertTrue(script.contains("/%n'"))
        XCTAssertFalse(script.contains("photo.jpg'"))
    }

    func testGeneralizeMoveToDesktopChangesExtension() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let cwd = "/tmp/project"
        let source = URL(fileURLWithPath: "/tmp/project/photo.jpg")
        let destination = URL(fileURLWithPath: "\(home)/Desktop/photo.png")
        let steps = [step(.rename(source: source, destination: destination))]
        let script = OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(generalizePaths: true, recordingCWD: cwd)
        )

        XCTAssertTrue(script.contains("/bin/mv %p"))
        XCTAssertTrue(script.contains("/%b.png'"))
    }

    func testGeneralizeCreateDirectoryUnderCWD() {
        let cwd = "/tmp/project"
        let steps = [step(.createDirectory(url: URL(fileURLWithPath: "/tmp/project/backup")))]
        let script = OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(generalizePaths: true, recordingCWD: cwd)
        )

        XCTAssertTrue(script.contains("'%d/backup'"))
    }

    func testLiteralPathsWhenGeneralizationDisabled() {
        let cwd = "/tmp/project"
        let source = URL(fileURLWithPath: "/tmp/project/old.txt")
        let destination = URL(fileURLWithPath: "/tmp/project/new.txt")
        let steps = [step(.rename(source: source, destination: destination))]
        let script = OperationShellTranslator.translate(
            steps: steps,
            options: OperationShellTranslationOptions(generalizePaths: false, recordingCWD: cwd)
        )

        XCTAssertEqual(script, "/bin/mv '/tmp/project/old.txt' '/tmp/project/new.txt'")
    }

    func testCompressUsesStoredCommand() {
        let source = URL(fileURLWithPath: "/tmp/project/file.txt")
        let archive = URL(fileURLWithPath: "/tmp/project/file.txt.zip")
        let command = "/usr/bin/ditto -c -k --keepParent '/tmp/project/file.txt' '/tmp/project/file.txt.zip'"
        let steps = [step(.compress(sources: [source], archive: archive, command: command))]
        let script = OperationShellTranslator.translate(steps: steps)
        XCTAssertEqual(script, command)
        XCTAssertTrue(script.contains("ditto"))
    }

    func testExtractUsesStoredCommand() {
        let archive = URL(fileURLWithPath: "/tmp/project/archive.zip")
        let destination = URL(fileURLWithPath: "/tmp/project/archive")
        let command = "/bin/mkdir -p '/tmp/project/archive' && /usr/bin/unzip -o -q '/tmp/project/archive.zip' -d '/tmp/project/archive'"
        let steps = [step(.extract(archive: archive, destination: destination, command: command))]
        let script = OperationShellTranslator.translate(steps: steps)
        XCTAssertEqual(script, command)
        XCTAssertTrue(script.contains("unzip"))
    }
}
