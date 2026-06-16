import XCTest
import FileList

final class FileListLayoutTests: XCTestCase {
    
    func testBlankAreaFractionIsTenPercent() {
        XCTAssertEqual(FileListLayoutMetrics.blankAreaFraction, 0.10, accuracy: 0.0001)
    }
    
    func testTableAndBlankWidthsSumToTotal() {
        let total: CGFloat = 800
        let table = FileListLayoutMetrics.tableWidth(forTotalWidth: total)
        let blank = FileListLayoutMetrics.blankAreaWidth(forTotalWidth: total)
        XCTAssertEqual(table + blank, total, accuracy: 0.001)
        XCTAssertEqual(blank / total, 0.10, accuracy: 0.001)
    }
    
    func testTableHeaderHeightIsPositive() {
        XCTAssertGreaterThan(FileListLayoutMetrics.tableHeaderHeight, 0)
    }
}
