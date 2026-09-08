import XCTest
@testable import Explorer

@MainActor
final class FileTransferCenterTests: XCTestCase {
    override func tearDown() async throws {
        FileTransferCenter.shared.cancelAll()
        try await super.tearDown()
    }

    func testWeightPlanFractionsPreferLargerFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("transfer-weight-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let small = root.appendingPathComponent("small.txt")
        let large = root.appendingPathComponent("large.txt")
        try Data(repeating: 0x61, count: 10).write(to: small)
        try Data(repeating: 0x62, count: 1000).write(to: large)

        let plan = FileTransferCenter.WeightPlan.make(urls: [small, large])
        XCTAssertEqual(plan.weights.count, 2)
        XCTAssertGreaterThan(plan.weights[1], plan.weights[0])

        let afterSmall = plan.fraction(completedCount: 1)
        let afterBoth = plan.fraction(completedCount: 2)
        XCTAssertLessThan(afterSmall, 0.5)
        XCTAssertEqual(afterBoth, 1.0, accuracy: 0.0001)
    }

    func testRevealPolicyDefersTinyCopy() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("transfer-policy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let file = root.appendingPathComponent("tiny.txt")
        try Data("hi".utf8).write(to: file)
        let destination = root.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let policy = FileTransferCenter.ProgressPolicy.revealPolicy(
            urls: [file],
            copy: true,
            destination: destination
        )
        XCTAssertEqual(policy, .deferred)
    }

    func testRevealPolicyImmediateForDirectoryCopy() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("transfer-dir-policy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let folder = root.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let policy = FileTransferCenter.ProgressPolicy.revealPolicy(
            urls: [folder],
            copy: true,
            destination: destination
        )
        XCTAssertEqual(policy, .immediate)
    }

    func testBeginTransferImmediatePublishesProgress() {
        let center = FileTransferCenter.shared
        let sessionID = center.beginTransfer(
            mode: .copy,
            total: 3,
            destination: "/tmp",
            weightPlan: FileTransferCenter.WeightPlan(weights: [1, 1, 1], totalWeight: 3),
            deferredReveal: false
        )
        XCTAssertEqual(center.activeProgress?.sessionID, sessionID)

        center.updateTransfer(sessionID: sessionID, completed: 1, total: 3, currentName: "a.txt", force: true)
        XCTAssertEqual(center.activeProgress?.progressFraction, 1.0 / 3.0, accuracy: 0.0001)

        center.finish(sessionID: sessionID)
        XCTAssertNil(center.activeProgress)
    }

    func testDeferredTransferFinishesBeforeRevealLeavesNoBanner() async throws {
        let center = FileTransferCenter.shared
        let sessionID = center.beginTransfer(
            mode: .move,
            total: 1,
            destination: "/tmp",
            weightPlan: FileTransferCenter.WeightPlan(weights: [1], totalWeight: 1),
            deferredReveal: true
        )
        XCTAssertNil(center.activeProgress)
        center.finish(sessionID: sessionID)
        try await Task.sleep(nanoseconds: 350_000_000)
        XCTAssertNil(center.activeProgress)
    }

    func testRevealPolicyImmediateWhenManyFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("transfer-many-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var urls: [URL] = []
        for index in 0..<5 {
            let file = root.appendingPathComponent("f\(index).txt")
            try Data("x".utf8).write(to: file)
            urls.append(file)
        }
        let destination = root.appendingPathComponent("dest", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let policy = FileTransferCenter.ProgressPolicy.revealPolicy(
            urls: urls,
            copy: true,
            destination: destination
        )
        XCTAssertEqual(policy, .immediate)
    }

    func testCancelThenBeginDoesNotClearNewSession() {
        let center = FileTransferCenter.shared
        FileOperations.cancelActiveTransfer()
        let sessionID = center.beginTransfer(
            mode: .copy,
            total: 2,
            destination: "/tmp",
            weightPlan: FileTransferCenter.WeightPlan(weights: [1, 1], totalWeight: 2),
            deferredReveal: false
        )
        // 回归：旧实现会再异步 cancelAll，把刚 begin 的进度清掉。
        XCTAssertEqual(center.activeProgress?.sessionID, sessionID)
    }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("transfer-async-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let source = root.appendingPathComponent("source.txt")
        let destination = root.appendingPathComponent("dest", isDirectory: true)
        try Data("payload".utf8).write(to: source)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        let expectation = expectation(description: "moveItems completion")
        FileOperations.moveItems([source], to: destination, copy: true) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5)
        let copied = destination.appendingPathComponent("source.txt")
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
    }
}
