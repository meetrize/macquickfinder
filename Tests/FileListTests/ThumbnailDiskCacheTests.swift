import AppKit
import XCTest
@testable import FileList

final class ThumbnailDiskCacheTests: XCTestCase {
    func testTrimToBudgetEvictsOldestFilesFirst() throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("thumb-disk-cache-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: testDir) }
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)

        let cache = ThumbnailDiskCache(testRoot: testDir, maxTotalBytes: 1_000)
        let fileManager = FileManager.default
        let oldURL = testDir.appendingPathComponent("oldest.png")
        let midURL = testDir.appendingPathComponent("middle.png")
        let newURL = testDir.appendingPathComponent("newest.png")
        let chunk = Data(repeating: 0xAB, count: 400)

        try chunk.write(to: oldURL)
        try chunk.write(to: midURL)
        try chunk.write(to: newURL)
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 1)],
            ofItemAtPath: oldURL.path
        )
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 2)],
            ofItemAtPath: midURL.path
        )
        try fileManager.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 3)],
            ofItemAtPath: newURL.path
        )

        cache.trimToBudget()
        cache.waitForIdle()

        XCTAssertFalse(fileManager.fileExists(atPath: oldURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: midURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: newURL.path))
    }
}
