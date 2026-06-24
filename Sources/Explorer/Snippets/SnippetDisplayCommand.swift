import Foundation

enum SnippetDisplayCommand {
  static func build(snippet: Snippet, expandedContent: String) -> String {
    switch snippet.scriptType {
    case .shell:
      let interpreter = snippet.interpreter ?? SnippetDefaults.shellInterpreter
      return "\(interpreter) -lc '\(expandedContent)'"
    case .python3:
      if expandedContent.contains("\n") {
        return "python3 << '\(expandedContent.prefix(80))…'"
      }
      return "python3 -c '\(expandedContent)'"
    case .appleScript:
      return expandedContent
    }
  }
}
