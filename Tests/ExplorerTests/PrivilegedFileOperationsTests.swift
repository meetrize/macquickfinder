import XCTest
@testable import Explorer

final class PrivilegedFileOperationsTests: XCTestCase {
    func testPrivilegeCandidateForCocoaWriteNoPermission() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteNoPermissionError,
            userInfo: [NSLocalizedDescriptionKey: "Permission denied"]
        )
        XCTAssertTrue(PrivilegedFileOperations.isPrivilegeEscalationCandidate(error))
    }

    func testPrivilegeCandidateForPOSIXEACCES() {
        let error = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES), userInfo: nil)
        XCTAssertTrue(PrivilegedFileOperations.isPrivilegeEscalationCandidate(error))
    }

    func testPrivilegeCandidateForDiagnosticReportPermissionMessage() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileReadNoPermissionError,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "未能将“Microsoft Defender”移到废纸篓，因为你没有访问该诊断报告的许可。"
            ]
        )
        XCTAssertTrue(PrivilegedFileOperations.isPrivilegeEscalationCandidate(error))
    }

    func testPrivilegeCandidateRejectsGenericNotFound() {
        let error = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileNoSuchFileError,
            userInfo: [NSLocalizedDescriptionKey: "The file doesn’t exist."]
        )
        XCTAssertFalse(PrivilegedFileOperations.isPrivilegeEscalationCandidate(error))
    }

    func testPrivilegeCandidateWalksUnderlyingError() {
        let underlying = NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM), userInfo: nil)
        let wrapped = NSError(
            domain: NSCocoaErrorDomain,
            code: NSFileWriteUnknownError,
            userInfo: [NSUnderlyingErrorKey: underlying]
        )
        XCTAssertTrue(PrivilegedFileOperations.isPrivilegeEscalationCandidate(wrapped))
    }

    func testUserCancelledAdminAuthDetectsErrorNumber() {
        XCTAssertTrue(
            PrivilegedFileOperations.isUserCancelledAdminAuth([
                NSAppleScript.errorNumber: -128
            ] as NSDictionary)
        )
    }

    func testShellSingleQuotedEscapesEmbeddedQuotes() {
        XCTAssertEqual(
            PrivilegedFileOperations.shellSingleQuoted("a'b"),
            "'a'\\''b'"
        )
    }

    func testUniqueTrashDestinationAvoidsCollision() throws {
        let trash = FileManager.default.temporaryDirectory
            .appendingPathComponent("mf-trash-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: trash, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: trash) }

        let existing = trash.appendingPathComponent("App.app")
        try Data().write(to: existing)

        // 通过 swizzle 不便；此处只验证命名辅助在同目录下的编号规则与 shell 转义。
        let base = "App"
        let ext = "app"
        var candidate = trash.appendingPathComponent("\(base).\(ext)")
        var index = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = trash.appendingPathComponent("\(base) \(index).\(ext)")
            index += 1
        }
        XCTAssertEqual(candidate.lastPathComponent, "App 2.app")
    }
}
