import XCTest
@testable import Explorer

final class ArchiveOperationsTests: XCTestCase {
    func testIsArchiveFileName() {
        XCTAssertTrue(ArchiveOperations.isArchiveFileName("backup.ZIP"))
        XCTAssertTrue(ArchiveOperations.isArchiveFileName("data.tar.gz"))
        XCTAssertTrue(ArchiveOperations.isArchiveFileName("bundle.tgz"))
        XCTAssertTrue(ArchiveOperations.isArchiveFileName("win.rar"))
        XCTAssertTrue(ArchiveOperations.isArchiveFileName("pack.7z"))
        XCTAssertFalse(ArchiveOperations.isArchiveFileName("notes.txt"))
    }

    func testDefaultArchiveFileNameSingleItem() {
        let item = makeItem(name: "readme.txt", path: "/tmp/readme.txt")
        XCTAssertEqual(ArchiveOperations.defaultArchiveFileName(for: [item]), "readme.txt.zip")
    }

    func testDefaultArchiveFileNameMultipleItems() {
        let items = [
            makeItem(name: "a.txt", path: "/tmp/a.txt"),
            makeItem(name: "b.txt", path: "/tmp/b.txt"),
        ]
        XCTAssertEqual(ArchiveOperations.defaultArchiveFileName(for: items), "Archive.zip")
    }

    func testArchiveStemNameDoubleExtension() {
        let url = URL(fileURLWithPath: "/tmp/project.tar.gz")
        XCTAssertEqual(ArchiveOperations.archiveStemName(for: url), "project")
    }

    func testUniqueNamedPathIncrementsWhenExists() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-ops-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let existing = directory.appendingPathComponent("foo")
        try Data().write(to: existing)

        let resolved = ArchiveOperations.uniqueNamedPath(name: "foo", in: directory)
        XCTAssertEqual(resolved.lastPathComponent, "foo 2")
    }

    func testUniqueExtractDirectoryUsesStem() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-ops-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let archive = directory.appendingPathComponent("demo.zip")
        try Data().write(to: archive)

        let destination = ArchiveOperations.uniqueExtractDirectory(for: archive, in: directory)
        XCTAssertEqual(destination.lastPathComponent, "demo")
    }

    func testMakeCompressCommandSingleItemUsesDitto() {
        let command = ArchiveCommandBuilder.makeCompressCommand(
            itemURLs: [URL(fileURLWithPath: "/tmp/a b/文件.txt")],
            destinationZip: URL(fileURLWithPath: "/tmp/out.zip"),
            sourceDirectory: URL(fileURLWithPath: "/tmp")
        )
        XCTAssertTrue(command.contains("/usr/bin/ditto -c -k --keepParent"))
        XCTAssertTrue(command.contains("'/tmp/a b/文件.txt'"))
        XCTAssertTrue(command.contains("'/tmp/out.zip'"))
    }

    func testMakeCompressCommandMultipleItemsUsesZip() {
        let command = ArchiveCommandBuilder.makeCompressCommand(
            itemURLs: [
                URL(fileURLWithPath: "/tmp/a.txt"),
                URL(fileURLWithPath: "/tmp/b.txt"),
            ],
            destinationZip: URL(fileURLWithPath: "/tmp/Archive.zip"),
            sourceDirectory: URL(fileURLWithPath: "/tmp")
        )
        XCTAssertTrue(command.contains("cd '/tmp' && /usr/bin/zip -r '/tmp/Archive.zip'"))
        XCTAssertTrue(command.contains("'a.txt'"))
        XCTAssertTrue(command.contains("'b.txt'"))
        XCTAssertFalse(command.contains("ditto"))
    }

    func testMakeExtractCommandCreatesDirectoryAndExtracts() {
        let command = ArchiveCommandBuilder.makeExtractCommand(
            archive: URL(fileURLWithPath: "/tmp/a.zip"),
            destinationDirectory: URL(fileURLWithPath: "/tmp/a 2")
        )
        XCTAssertTrue(command.contains("/bin/mkdir -p '/tmp/a 2'"))
        XCTAssertTrue(command.contains("/usr/bin/tar -xf '/tmp/a.zip' -C '/tmp/a 2'"))
    }

    func testMakeExtractCommandWithMembersUsesTarPatterns() {
        let command = ArchiveCommandBuilder.makeExtractCommand(
            archive: URL(fileURLWithPath: "/tmp/a.zip"),
            destinationDirectory: URL(fileURLWithPath: "/tmp/out"),
            members: ["docs/readme.md", "photo.png"]
        )
        XCTAssertTrue(command.contains("-- 'docs/readme.md' 'photo.png'"))
    }

    func testMakeExtractCommandWithPasswordUsesUnzip() {
        let command = ArchiveCommandBuilder.makeExtractCommand(
            archive: URL(fileURLWithPath: "/tmp/a.zip"),
            destinationDirectory: URL(fileURLWithPath: "/tmp/out"),
            members: ["readme.md"],
            password: "secret"
        )
        XCTAssertTrue(command.contains("/usr/bin/unzip -o -q -P 'secret' '/tmp/a.zip' 'readme.md' -d '/tmp/out'"))
    }

    func testIsPasswordProtectedErrorDetectsPromptKeywords() {
        XCTAssertTrue(
            ArchiveOperations.isPasswordProtectedError(
                ArchiveOperationsError.shellOutput("Enter password:")
            )
        )
    }

    func testCanCompressAndExtractRules() {
        let archive = makeItem(name: "a.zip", path: "/tmp/a.zip")
        let file = makeItem(name: "b.txt", path: "/tmp/b.txt")

        XCTAssertTrue(ArchiveOperations.canCompress([file], inTrash: false))
        XCTAssertFalse(ArchiveOperations.canCompress([archive], inTrash: false))
        XCTAssertTrue(ArchiveOperations.canCompress([archive, file], inTrash: false))

        XCTAssertTrue(ArchiveOperations.canExtract([archive], inTrash: false))
        XCTAssertFalse(ArchiveOperations.canExtract([file], inTrash: false))
        XCTAssertFalse(ArchiveOperations.canExtract([archive, file], inTrash: false))

        XCTAssertFalse(ArchiveOperations.canCompress([file], inTrash: true))
        XCTAssertFalse(ArchiveOperations.canExtract([archive], inTrash: true))
    }

    func testShouldUseOutputPanelForDirectorySelection() {
        XCTAssertTrue(
            ArchiveTaskRunner.shouldUseOutputPanel(
                estimatedBytes: 1,
                volumePaths: ["/tmp"],
                containsDirectory: true
            )
        )
    }

    private func makeItem(name: String, path: String) -> FileItem {
        FileItem(
            id: path,
            url: URL(fileURLWithPath: path),
            name: name,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 1024,
            isHidden: false,
            fileType: (name as NSString).pathExtension,
            sizeDisplay: "1 KB",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }
}
