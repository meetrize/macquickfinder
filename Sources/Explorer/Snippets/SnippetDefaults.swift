import Foundation

enum SnippetDefaults {
    static let shellInterpreter = "/bin/zsh"
    static let bashInterpreter = "/bin/bash"
    static let hidesUnavailableSnippets = true
    static let schemaVersion = 1
    static let maxImportCount = 500

    /// 输出面板底部续跑命令时使用的默认 zsh Snippet（无绑定 Snippet 的 Job 亦可执行）。
    static var inPlaceShellSnippet: Snippet {
        Snippet(
            name: "Shell",
            scriptType: .shell,
            scope: .anytime,
            content: "",
            interpreter: shellInterpreter
        )
    }
}
