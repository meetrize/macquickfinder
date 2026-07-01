import XCTest
@testable import Explorer

final class RecordedScriptValidatorTests: XCTestCase {
    func testEmptyScriptReportsError() {
        let result = RecordedScriptValidator.validate(content: "  ", recordingCWD: "/tmp")
        XCTAssertTrue(result.hasErrors)
    }

    func testUnknownVariableReportsError() {
        let result = RecordedScriptValidator.validate(content: "echo %foo", recordingCWD: "/tmp")
        XCTAssertTrue(result.hasErrors)
        XCTAssertTrue(result.issues.contains { $0.message.contains("%foo") || $0.message.contains("foo") })
    }

    func testSupportedVariablesPassValidation() {
        let result = RecordedScriptValidator.validate(content: "echo %d", recordingCWD: "/tmp/project")
        XCTAssertFalse(result.hasErrors)
        XCTAssertTrue(result.isSuccessful)
    }

    func testInvalidShellSyntaxReportsError() {
        let result = RecordedScriptValidator.validate(content: "if then", recordingCWD: "/tmp")
        XCTAssertTrue(result.hasErrors)
    }

    func testDestructiveCommandReportsWarning() {
        let result = RecordedScriptValidator.validate(content: "/bin/rm -rf %p", recordingCWD: "/tmp")
        XCTAssertFalse(result.hasErrors)
        XCTAssertFalse(result.isSuccessful)
        XCTAssertTrue(result.issues.contains { $0.level == .warning })
    }

    func testUnknownVariablesScannerFindsUnsupportedToken() {
        let unknown = RecordedScriptValidator.unknownVariables(in: "echo %p %unknown %date")
        XCTAssertEqual(unknown, ["%unknown"])
    }

    func testSnippetShellSecurityCheckerMatchesDestructivePatterns() {
        XCTAssertTrue(SnippetShellSecurityChecker.isDestructive("rm -rf /tmp/x"))
        XCTAssertFalse(SnippetShellSecurityChecker.isDestructive("echo hello"))
    }
}
