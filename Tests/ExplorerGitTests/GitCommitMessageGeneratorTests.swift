import XCTest
@testable import Explorer

final class GitCommitMessageGeneratorTests: XCTestCase {
    private let generator = RuleBasedGitCommitMessageGenerator()

    func testGeneratedFilesFallback() {
        let entries = [
            GitPorcelainEntry(status: .modified, path: "a.swift"),
            GitPorcelainEntry(status: .added, path: "b.swift"),
        ]
        let message = generator.generate(
            repoRoot: "/tmp/repo",
            scope: .allChanges,
            entries: entries
        )
        XCTAssertEqual(message, L10n.Git.Commit.generatedFiles(2))
    }

    func testDirectoryClusterSummary() {
        let entries = (1...3).map {
            GitPorcelainEntry(status: .modified, path: "Explorer/Preview/file\($0).swift")
        } + [GitPorcelainEntry(status: .modified, path: "Other/file.swift")]

        let message = generator.generate(
            repoRoot: "/tmp/repo",
            scope: .allChanges,
            entries: entries
        )
        XCTAssertEqual(message, L10n.Git.Commit.generatedDirectory("Explorer/Preview", 3))
    }

    func testSelectedScopeUsesSelectedPaths() {
        let entries = [
            GitPorcelainEntry(status: .modified, path: "a.swift"),
            GitPorcelainEntry(status: .modified, path: "b.swift"),
        ]
        let message = generator.generate(
            repoRoot: "/tmp/repo",
            scope: .selectedPaths(["a.swift"]),
            entries: entries
        )
        XCTAssertEqual(message, L10n.Git.Commit.generatedFiles(1))
    }
}
