import XCTest
@testable import Explorer

final class DirectoryMetadataCacheTests: XCTestCase {
    func testCacheKeyRoundTrip() {
        let key = DirectoryMetadataCache.key(path: "/tmp/a", showHiddenFiles: true)
        XCTAssertEqual(key, "/tmp/a|true")
        XCTAssertEqual(DirectoryMetadataCache.path(fromCacheKey: key), "/tmp/a")
    }

    func testPathFromCacheKeyWithoutSeparatorUsesWholeKey() {
        XCTAssertEqual(DirectoryMetadataCache.path(fromCacheKey: "/tmp/no-pipe"), "/tmp/no-pipe")
    }

    func testExactMTimeValidRequiresMatchingTimestamp() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let path = directory.path
        let mtime = try directoryMTime(at: directory)
        XCTAssertTrue(DirectoryMetadataCache.isExactMTimeValid(cached: mtime, path: path))
        XCTAssertFalse(DirectoryMetadataCache.isExactMTimeValid(cached: nil, path: path))
        XCTAssertFalse(
            DirectoryMetadataCache.isExactMTimeValid(cached: .distantPast, path: path)
        )
    }

    func testFuzzyMTimeValidAllowsSubMillisecondDrift() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let path = directory.path
        let mtime = try directoryMTime(at: directory)
        let slightlyEarlier = mtime.addingTimeInterval(-0.0005)
        XCTAssertTrue(DirectoryMetadataCache.isFuzzyMTimeValid(cached: slightlyEarlier, path: path))
        XCTAssertFalse(DirectoryMetadataCache.isFuzzyMTimeValid(cached: .distantPast, path: path))
    }

    func testFuzzyMTimeValidTreatsMissingDirectoryAsNilCachedOnly() {
        let missingPath = "/tmp/directory-metadata-cache-missing-\(UUID().uuidString)"
        XCTAssertTrue(DirectoryMetadataCache.isFuzzyMTimeValid(cached: nil, path: missingPath))
        XCTAssertFalse(
            DirectoryMetadataCache.isFuzzyMTimeValid(cached: .distantPast, path: missingPath)
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("directory-metadata-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func directoryMTime(at url: URL) throws -> Date {
        try url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate!
    }
}

@MainActor
final class DirectoryMetadataServiceTests: XCTestCase {
    private var tempDirectories: [URL] = []

    override func tearDown() {
        for url in tempDirectories {
            try? FileManager.default.removeItem(at: url)
        }
        tempDirectories.removeAll()
        super.tearDown()
    }

    func testScheduleWhenDisabledDoesNothing() async throws {
        let harness = makeHarness(scheduleEnabled: { false })
        let path = try makeTemporaryDirectoryPath()

        await harness.service.schedule(paths: [path], showHiddenFiles: false)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(harness.recorder.records.isEmpty)
        XCTAssertEqual(harness.counter.value, 0)
    }

    func testScheduleComputesAndAppliesResult() async throws {
        let harness = makeHarness()
        let path = try makeTemporaryDirectoryPath()

        await harness.service.schedule(paths: [path], showHiddenFiles: false)
        try await waitUntil { harness.recorder.records.count == 1 }

        XCTAssertEqual(harness.counter.value, 1)
        XCTAssertEqual(harness.recorder.records.map(\.path), [path])
        XCTAssertEqual(harness.recorder.records.map(\.value), [42])
    }

    func testCacheHitSkipsSecondCompute() async throws {
        let harness = makeHarness(
            isCacheValid: DirectoryMetadataCache.isExactMTimeValid
        )
        let path = try makeTemporaryDirectoryPath()

        await harness.service.schedule(paths: [path], showHiddenFiles: false)
        try await waitUntil { harness.recorder.records.count == 1 }
        let firstComputeCount = harness.counter.value

        await harness.service.schedule(paths: [path], showHiddenFiles: false)
        try await waitUntil { harness.recorder.records.count == 2 }

        XCTAssertEqual(harness.counter.value, firstComputeCount)
        XCTAssertEqual(harness.recorder.records.map(\.path), [path, path])
    }

    func testResetSessionIgnoresStaleGenerationResults() async throws {
        let gate = ComputeGate()
        let harness = makeHarness(
            compute: { path, _ in
                await gate.waitForRelease()
                return 7
            }
        )
        let path = try makeTemporaryDirectoryPath()

        await harness.service.resetSession(generation: 1)
        await harness.service.schedule(paths: [path], showHiddenFiles: false, priority: .normal)
        await harness.service.resetSession(generation: 2)
        gate.release()

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(harness.recorder.records.isEmpty)

        let snapshot = await harness.service.testingSnapshot()
        XCTAssertEqual(snapshot.activeGeneration, 2)
    }

    func testInvalidateTriggersRemoveAndForcesRecompute() async throws {
        let harness = makeHarness(
            isCacheValid: DirectoryMetadataCache.isExactMTimeValid
        )
        let path = try makeTemporaryDirectoryPath()

        await harness.service.schedule(paths: [path], showHiddenFiles: false)
        try await waitUntil { harness.recorder.records.count == 1 }

        await harness.service.invalidate(paths: [path])
        try await waitUntil { harness.removedPaths == [path] }

        await harness.service.schedule(paths: [path], showHiddenFiles: false)
        try await waitUntil { harness.counter.value == 2 }

        XCTAssertEqual(harness.removedPaths, [path])
    }

    func testInvalidateDescendantsClearsChildCacheEntries() async throws {
        let harness = makeHarness(
            invalidateDescendants: true,
            isCacheValid: DirectoryMetadataCache.isExactMTimeValid
        )
        let parent = try makeTemporaryDirectoryPath()
        let child = parent + "/nested"
        try FileManager.default.createDirectory(
            atPath: child,
            withIntermediateDirectories: true
        )

        await harness.service.schedule(paths: [parent, child], showHiddenFiles: false)
        try await waitUntil { harness.counter.value == 2 }

        await harness.service.invalidate(paths: [parent])
        await harness.service.schedule(paths: [child], showHiddenFiles: false)
        try await waitUntil { harness.counter.value == 3 }
    }

    func testShouldSchedulePathFilterSkipsExcludedPaths() async throws {
        let harness = makeHarness(
            shouldSchedulePath: { $0.contains("allowed") }
        )

        await harness.service.schedule(
            paths: ["/tmp/skipped", "/tmp/allowed-folder"],
            showHiddenFiles: false
        )
        try await waitUntil { harness.counter.value == 1 }

        XCTAssertEqual(harness.recorder.records.map(\.path), ["/tmp/allowed-folder"])
    }

    func testHigherPriorityReplacesQueuedWorkItem() async throws {
        let gate = ComputeGate()
        let harness = makeHarness(
            maxConcurrent: 1,
            compute: { path, _ in
                if path.hasSuffix("-blocker") {
                    await gate.waitForRelease()
                }
                return path.count
            }
        )
        let blockerPath = try makeTemporaryDirectoryPath() + "-SLOT-blocker"
        try FileManager.default.createDirectory(atPath: blockerPath, withIntermediateDirectories: true)
        tempDirectories.append(URL(fileURLWithPath: blockerPath))
        let targetPath = try makeTemporaryDirectoryPath()

        await harness.service.schedule(paths: [blockerPath], showHiddenFiles: false, priority: .normal)
        await harness.service.schedule(paths: [targetPath], showHiddenFiles: false, priority: .normal)
        await harness.service.schedule(paths: [targetPath], showHiddenFiles: false, priority: .visible)

        let snapshot = await harness.service.testingSnapshot()
        XCTAssertEqual(
            snapshot.queuedItems.first(where: { $0.path == targetPath })?.priority,
            .visible
        )

        gate.release()
        try await waitUntil { harness.recorder.records.count == 2 }
    }

    private func makeHarness(
        maxConcurrent: Int = 2,
        scheduleEnabled: @escaping @Sendable () -> Bool = { true },
        shouldSchedulePath: @escaping @Sendable (String) -> Bool = { _ in true },
        invalidateDescendants: Bool = false,
        isCacheValid: @escaping @Sendable (Date?, String) -> Bool = { _, _ in true },
        compute: (@Sendable (String, Bool) async throws -> Int)? = nil
    ) -> MetadataTestHarness {
        MetadataTestHarness(
            maxConcurrent: maxConcurrent,
            scheduleEnabled: scheduleEnabled,
            shouldSchedulePath: shouldSchedulePath,
            invalidateDescendants: invalidateDescendants,
            isCacheValid: isCacheValid,
            compute: compute
        )
    }

    private func makeTemporaryDirectoryPath() throws -> String {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("directory-metadata-service-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        tempDirectories.append(url)
        return url.path
    }

    private func waitUntil(
        timeoutNanoseconds: UInt64 = 2_000_000_000,
        pollNanoseconds: UInt64 = 10_000_000,
        _ predicate: @escaping () -> Bool
    ) async throws {
        let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if predicate() { return }
            try await Task.sleep(nanoseconds: pollNanoseconds)
        }
        XCTFail("Timed out waiting for condition")
    }
}

@MainActor
private final class MetadataTestHarness {
    let service: DirectoryMetadataService<Int>
    let counter = ComputeCounter()
    let recorder = MetadataApplyRecorder()
    private(set) var removedPaths: [String] = []

    init(
        maxConcurrent: Int,
        scheduleEnabled: @escaping @Sendable () -> Bool,
        shouldSchedulePath: @escaping @Sendable (String) -> Bool,
        invalidateDescendants: Bool,
        isCacheValid: @escaping @Sendable (Date?, String) -> Bool,
        compute: (@Sendable (String, Bool) async throws -> Int)?
    ) {
        let counter = self.counter
        let recorder = self.recorder
        service = DirectoryMetadataService(
            configuration: DirectoryMetadataServiceConfiguration(
                maxConcurrent: maxConcurrent,
                maxCacheEntries: 32,
                clearsEntireCacheWhenFull: false,
                invalidateDescendants: invalidateDescendants,
                scheduleEnabled: scheduleEnabled,
                shouldSchedulePath: shouldSchedulePath,
                isCacheValid: isCacheValid,
                compute: compute ?? { _, _ in
                    counter.increment()
                    return 42
                },
                apply: { path, value, generation in
                    recorder.record(path: path, value: value, generation: generation)
                },
                remove: { [weak self] paths in
                    self?.removedPaths.append(contentsOf: paths)
                }
            )
        )
    }
}

@MainActor
private final class MetadataApplyRecorder {
    private(set) var records: [(path: String, value: Int, generation: UInt)] = []

    func record(path: String, value: Int, generation: UInt) {
        records.append((path, value, generation))
    }
}

private final class ComputeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    func increment() {
        lock.lock()
        count += 1
        lock.unlock()
    }
}

private actor ComputeGate {
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    func waitForRelease() async {
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}
