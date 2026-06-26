import XCTest
@testable import Explorer

final class RemoteServerURLTests: XCTestCase {
    func testNormalizeAddsDefaultSMBScheme() {
        let result = RemoteServerURL.normalize("nas.local/share")
        guard case .success(let url) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(url.scheme, "smb")
        XCTAssertEqual(url.host, "nas.local")
        XCTAssertEqual(url.path, "/share")
    }

    func testNormalizeAcceptsExplicitSMB() {
        let result = RemoteServerURL.normalize("smb://user@nas.local/media")
        guard case .success(let url) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(url.scheme, "smb")
        XCTAssertEqual(url.host, "nas.local")
    }

    func testNormalizeAcceptsFTP() {
        let result = RemoteServerURL.normalize("ftp://ftp.example.com/pub")
        guard case .success(let url) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(url.scheme, "ftp")
        XCTAssertEqual(url.host, "ftp.example.com")
        XCTAssertTrue(RemoteServerURL.isFTP(url))
    }

    func testNormalizeAcceptsWebDAVHTTPS() {
        let result = RemoteServerURL.normalize("https://dav.example.com/remote.php/dav")
        guard case .success(let url) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(url.scheme, "https")
    }

    func testNormalizeRejectsSFTP() {
        let result = RemoteServerURL.normalize("sftp://user@host/path")
        XCTAssertEqual(result, .unsupportedProtocol("sftp"))
    }

    func testNormalizeRejectsEmptyInput() {
        XCTAssertEqual(RemoteServerURL.normalize("   "), .invalidURL)
    }

    func testNormalizeRejectsFileScheme() {
        XCTAssertEqual(RemoteServerURL.normalize("file:///etc/passwd"), .invalidURL)
    }

    func testNormalizeRejectsMissingHost() {
        XCTAssertEqual(RemoteServerURL.normalize("smb:///share"), .invalidURL)
    }

    func testNormalizeTrimsWhitespace() {
        let result = RemoteServerURL.normalize("  smb://nas.local/share  ")
        guard case .success(let url) = result else {
            return XCTFail("Expected success")
        }
        XCTAssertEqual(url.host, "nas.local")
    }
}

final class RemoteVolumeMountDiffTests: XCTestCase {
    func testNewPathsDiff() {
        let before: Set<String> = ["/", "/Volumes/USB"]
        let after: Set<String> = ["/", "/Volumes/USB", "/Volumes/nas-share"]
        XCTAssertEqual(
            RemoteVolumeMountDiff.newPaths(before: before, after: after),
            ["/Volumes/nas-share"]
        )
    }

    func testSelectMountPathReturnsSingleCandidate() {
        let selected = RemoteVolumeMountDiff.selectMountPath(
            from: ["/Volumes/media"],
            matching: URL(string: "smb://nas.local/media")!
        )
        XCTAssertEqual(selected, "/Volumes/media")
    }

    func testSelectMountPathPrefersShareName() {
        let serverURL = URL(string: "smb://nas.local/media")!
        let selected = RemoteVolumeMountDiff.selectMountPath(
            from: ["/Volumes/other", "/Volumes/media"],
            matching: serverURL
        )
        XCTAssertEqual(selected, "/Volumes/media")
    }

    func testExistingMountPathMatchesShareName() {
        let serverURL = URL(string: "smb://nas.local/media")!
        let existing = RemoteVolumeMountDiff.existingMountPath(
            for: serverURL,
            among: ["/", "/Volumes/media"]
        )
        XCTAssertEqual(existing, "/Volumes/media")
    }

    func testMatchingHintsIncludeHostAndShare() {
        let hints = RemoteVolumeMountDiff.matchingHints(
            from: URL(string: "smb://nas.local/media/photos")!
        )
        XCTAssertTrue(hints.contains("nas.local"))
        XCTAssertTrue(hints.contains("media"))
    }
}

final class RemoteVolumeMountServiceTests: XCTestCase {
    func testConnectReturnsExistingMountWithoutOpening() async throws {
        let listing = MockMountedVolumeListing(paths: ["/", "/Volumes/media"])
        let opener = MockSystemMountOpening()
        var service = RemoteVolumeMountService(volumeListing: listing, mountOpener: opener)
        service.mountWaitTimeout = 1
        service.pollInterval = 0.05

        let mountURL = try await service.connect(to: URL(string: "smb://nas.local/media")!)
        XCTAssertEqual(mountURL.path, "/Volumes/media")
        XCTAssertEqual(opener.openedURLs, [])
    }

    func testConnectWaitsForNewVolume() async throws {
        let listing = MockMountedVolumeListing(paths: ["/"])
        let opener = MockSystemMountOpening()
        var service = RemoteVolumeMountService(volumeListing: listing, mountOpener: opener)
        service.mountWaitTimeout = 2
        service.pollInterval = 0.05

        Task {
            try await Task.sleep(nanoseconds: 150_000_000)
            listing.paths.insert("/Volumes/nas-share")
        }

        let mountURL = try await service.connect(to: URL(string: "smb://nas.local/nas-share")!)
        XCTAssertEqual(mountURL.path, "/Volumes/nas-share")
        XCTAssertEqual(opener.openedURLs.map(\.absoluteString), ["smb://nas.local/nas-share"])
    }

    func testConnectInputRejectsSFTP() async {
        let service = RemoteVolumeMountService(
            volumeListing: MockMountedVolumeListing(paths: []),
            mountOpener: MockSystemMountOpening()
        )

        do {
            _ = try await service.connect(input: "sftp://user@host")
            XCTFail("Expected unsupportedProtocol")
        } catch let error as RemoteMountError {
            XCTAssertEqual(error, .unsupportedProtocol("sftp"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockMountedVolumeListing: MountedVolumeListing {
    var paths: Set<String>

    init(paths: Set<String>) {
        self.paths = paths
    }

    func mountedVolumePaths() -> Set<String> {
        paths
    }
}

private final class MockSystemMountOpening: SystemMountOpening {
    private(set) var openedURLs: [URL] = []

    @MainActor
    func open(_ url: URL) throws {
        openedURLs.append(url)
    }
}

final class RemoteServerL10nTests: XCTestCase {
    func testRemoteServerErrorStringsResolve() {
        XCTAssertNotEqual(L10n.RemoteServer.Error.invalidURL, "remote_server.error.invalid_url")
        XCTAssertNotEqual(L10n.RemoteServer.Error.timeout, "remote_server.error.timeout")
        XCTAssertNotEqual(L10n.RemoteServer.Error.sftpDeferred, "remote_server.error.sftp_deferred")
        XCTAssertNotEqual(
            L10n.RemoteServer.Error.unsupportedProtocol("ftpes"),
            "remote_server.error.unsupported_protocol ftpes"
        )
    }

    func testRemoteServerUIStringsResolve() {
        XCTAssertNotEqual(L10n.RemoteServer.connectServerMenu, "remote_server.connect_server_menu")
        XCTAssertNotEqual(L10n.RemoteServer.sheetTitle, "remote_server.sheet.title")
        XCTAssertNotEqual(L10n.RemoteServer.connect, "remote_server.connect")
        XCTAssertNotEqual(L10n.RemoteServer.disconnectedFromServer, "remote_server.disconnected_from_server")
        XCTAssertNotEqual(L10n.Menu.go, "menu.go")
    }

    func testRemoteMountErrorUsesLocalizedDescriptions() {
        XCTAssertNotNil(RemoteMountError.invalidURL.errorDescription)
        XCTAssertNotNil(RemoteMountError.timeout.errorDescription)
        XCTAssertNotNil(RemoteMountError.unsupportedProtocol("sftp").errorDescription)
        XCTAssertNil(RemoteMountError.cancelled.errorDescription)
    }
}
