import XCTest
@testable import FileList

final class FileListListingSignatureTests: XCTestCase {
    private func row(id: String) -> FileListRow {
        FileListRow(
            id: id,
            name: id,
            fileType: "txt",
            sizeDisplay: "0",
            dateDisplay: "",
            size: 0,
            modificationDate: .distantPast,
            isDirectory: false,
            isHidden: false,
            isParentDirectoryEntry: false,
            iconPath: "/tmp/\(id)"
        )
    }

    func testHashStableForSameIDs() {
        let rows = [row(id: "a"), row(id: "b")]
        XCTAssertEqual(
            FileListListingSignature.hash(for: rows),
            FileListListingSignature.hash(for: rows)
        )
    }

    func testHashChangesWhenOrderChanges() {
        let first = [row(id: "a"), row(id: "b")]
        let second = [row(id: "b"), row(id: "a")]
        XCTAssertNotEqual(
            FileListListingSignature.hash(for: first),
            FileListListingSignature.hash(for: second)
        )
    }

    func testHashChangesWhenCountChanges() {
        let one = [row(id: "a")]
        let two = [row(id: "a"), row(id: "b")]
        XCTAssertNotEqual(
            FileListListingSignature.hash(for: one),
            FileListListingSignature.hash(for: two)
        )
    }
}
