import AppKit
import XCTest
@testable import Explorer

@MainActor
final class HoverPreviewCacheTests: XCTestCase {
    func testStoreAndRetrieveByKey() {
        let cache = HoverPreviewCache.shared
        let key = HoverPreviewCache.makeKey(
            path: "/tmp/a.png",
            modificationDate: Date(timeIntervalSince1970: 1),
            size: 10
        )
        cache.store(.text("hello"), for: key)
        guard case .text(let value) = cache.payload(for: key) else {
            return XCTFail("expected text payload")
        }
        XCTAssertEqual(value, "hello")
    }

    func testKeyChangesWithMtimeOrSize() {
        let date = Date(timeIntervalSince1970: 100)
        let a = HoverPreviewCache.makeKey(path: "/tmp/a", modificationDate: date, size: 1)
        let b = HoverPreviewCache.makeKey(path: "/tmp/a", modificationDate: date, size: 2)
        let c = HoverPreviewCache.makeKey(
            path: "/tmp/a",
            modificationDate: Date(timeIntervalSince1970: 101),
            size: 1
        )
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testTrimToHalfReducesBudget() {
        let cache = HoverPreviewCache.shared
        for index in 0..<12 {
            let key = HoverPreviewCache.makeKey(
                path: "/tmp/trim-\(index).txt",
                modificationDate: Date(timeIntervalSince1970: Double(index)),
                size: Int64(index)
            )
            let blob = String(repeating: "x", count: 8_000)
            cache.store(.text(blob), for: key)
        }
        cache.trimToHalf()
        #if DEBUG
        XCTAssertLessThanOrEqual(cache.debugEntryCount, HoverPreviewMetrics.cacheMaxEntries)
        #endif
    }
}
