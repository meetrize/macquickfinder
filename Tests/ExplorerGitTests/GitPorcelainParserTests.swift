import XCTest
@testable import Explorer

final class GitPorcelainParserTests: XCTestCase {
    func testParsesModifiedAndUntrackedEntries() {
        let payload = " M Sources/Foo.swift\0?? docs/new.md\0"
        let entries = GitPorcelainParser.parse(zTerminated: Data(payload.utf8))

        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].status, .modified)
        XCTAssertEqual(entries[0].path, "Sources/Foo.swift")
        XCTAssertEqual(entries[1].status, .untracked)
        XCTAssertEqual(entries[1].path, "docs/new.md")
    }

    func testParsesRenameEntry() {
        let payload = "R  old/name.swift\0new/name.swift\0"
        let entries = GitPorcelainParser.parse(zTerminated: Data(payload.utf8))

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].status, .renamed)
        XCTAssertEqual(entries[0].oldPath, "old/name.swift")
        XCTAssertEqual(entries[0].path, "new/name.swift")
    }

    func testParsesConflictEntry() {
        let payload = "UU conflicted.swift\0"
        let entries = GitPorcelainParser.parse(zTerminated: Data(payload.utf8))

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].status, .conflict)
        XCTAssertEqual(entries[0].path, "conflicted.swift")
    }

    func testParsesDeletedEntry() {
        let payload = " D removed.swift\0"
        let entries = GitPorcelainParser.parse(zTerminated: Data(payload.utf8))

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].status, .deleted)
        XCTAssertEqual(entries[0].path, "removed.swift")
    }

    func testEmptyPayloadReturnsEmptyList() {
        XCTAssertTrue(GitPorcelainParser.parse(zTerminated: Data()).isEmpty)
    }
}
