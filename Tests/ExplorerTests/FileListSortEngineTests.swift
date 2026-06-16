import XCTest
import FileList

final class FileListSortEngineTests: XCTestCase {
    
    private func row(
        id: String,
        name: String,
        fileType: String = "txt",
        size: Int64 = 0,
        date: Date = .distantPast,
        isParent: Bool = false
    ) -> FileListRow {
        FileListRow(
            id: id,
            name: name,
            fileType: fileType,
            sizeDisplay: "\(size)",
            dateDisplay: "",
            size: size,
            modificationDate: date,
            isDirectory: false,
            isHidden: false,
            isParentDirectoryEntry: isParent,
            iconPath: "/tmp/\(name)"
        )
    }
    
    func testParentRowStaysFirstWhenSortingByName() {
        let parent = row(id: "__parent__", name: "..", isParent: true)
        let rows = [
            parent,
            row(id: "b", name: "Bravo"),
            row(id: "a", name: "Alpha")
        ]
        
        let sorted = FileListSortEngine.sorted(
            rows,
            by: FileListSortState(column: .name, ascending: true)
        )
        
        XCTAssertTrue(sorted.first?.isParentDirectoryEntry == true)
        XCTAssertEqual(sorted.dropFirst().map(\.name), ["Alpha", "Bravo"])
    }
    
    func testSortBySizeDescending() {
        let rows = [
            row(id: "1", name: "small", size: 10),
            row(id: "2", name: "large", size: 100)
        ]
        
        let sorted = FileListSortEngine.sorted(
            rows,
            by: FileListSortState(column: .size, ascending: false)
        )
        
        XCTAssertEqual(sorted.map(\.id), ["2", "1"])
    }
    
    func testUnknownDirectorySizeSortsLastRegardlessOfDirection() {
        let rows = [
            row(id: "known", name: "known", size: 50),
            row(id: "unknown", name: "unknown", size: -1)
        ]
        
        let ascending = FileListSortEngine.sorted(
            rows,
            by: FileListSortState(column: .size, ascending: true)
        )
        XCTAssertEqual(ascending.map(\.id), ["known", "unknown"])
        
        let descending = FileListSortEngine.sorted(
            rows,
            by: FileListSortState(column: .size, ascending: false)
        )
        XCTAssertEqual(descending.map(\.id), ["known", "unknown"])
    }
    
    func testSortByTypeAscending() {
        let rows = [
            row(id: "1", name: "b.zip", fileType: "zip"),
            row(id: "2", name: "a.txt", fileType: "txt")
        ]
        
        let sorted = FileListSortEngine.sorted(
            rows,
            by: FileListSortState(column: .type, ascending: true)
        )
        
        XCTAssertEqual(sorted.map(\.fileType), ["txt", "zip"])
    }
}
