import Foundation

enum SystemTerminalRunner {
    static func run(
        snippet: Snippet,
        expandedContent: String,
        workingDirectory: String?
    ) throws {
        let script = buildScript(
            snippet: snippet,
            expandedContent: expandedContent,
            workingDirectory: workingDirectory
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("mqf-snippet-\(UUID().uuidString).command")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-na", "Terminal", url.path]
        try process.run()
    }

    private static func buildScript(
        snippet: Snippet,
        expandedContent: String,
        workingDirectory: String?
    ) -> String {
        let interpreter = snippet.interpreter ?? SnippetDefaults.shellInterpreter
        var lines: [String] = ["#!\(interpreter)"]

        if let workingDirectory, !workingDirectory.isEmpty {
            lines.append("cd \(ShellQuoting.singleQuote(workingDirectory)) || exit 1")
        }

        switch snippet.scriptType {
        case .shell:
            lines.append(expandedContent)
        case .python3:
            let delimiter = heredocDelimiter(avoiding: expandedContent)
            lines.append("/usr/bin/python3 <<'\(delimiter)'")
            lines.append(expandedContent)
            lines.append(delimiter)
        case .appleScript:
            let delimiter = heredocDelimiter(avoiding: expandedContent)
            lines.append("/usr/bin/osascript <<'\(delimiter)'")
            lines.append(expandedContent)
            lines.append(delimiter)
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func heredocDelimiter(avoiding content: String) -> String {
        var delimiter = "MQF_SNIPPET_END"
        var suffix = 0
        while content.contains(delimiter) {
            suffix += 1
            delimiter = "MQF_SNIPPET_END_\(suffix)"
        }
        return delimiter
    }
}
