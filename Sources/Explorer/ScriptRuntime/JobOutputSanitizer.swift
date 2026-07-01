import Foundation

/// 过滤误进入 stderr 时间线的 Snippet 脚本正文（避免粉色脚本块遮挡输出）。
enum JobOutputSanitizer {
  static func stripEmbeddedScriptEcho(from stdout: inout String, scriptBody: String) {
    let body = scriptBody.trimmingCharacters(in: .whitespacesAndNewlines)
    guard body.count > 40 else { return }

    var rebuilt = ""
    var remainder = stdout
    var removedAny = false

    while let openRange = remainder.range(of: OutputSessionFormatting.stderrOpenMarker) {
      let before = String(remainder[..<openRange.lowerBound])
      rebuilt += before
      remainder = String(remainder[openRange.upperBound...])
      guard let closeRange = remainder.range(of: OutputSessionFormatting.stderrCloseMarker) else {
        rebuilt += OutputSessionFormatting.stderrOpenMarker + remainder
        break
      }
      let stderrText = String(remainder[..<closeRange.lowerBound])
      remainder = String(remainder[closeRange.upperBound...])
      if shouldSuppress(stderrText, scriptBody: body) {
        removedAny = true
      } else {
        rebuilt += OutputSessionFormatting.wrapStderr(stderrText)
      }
    }
    rebuilt += remainder

    if removedAny {
      stdout = rebuilt
    }
  }

  static func shouldSuppressStderrChunk(_ chunk: String, scriptBody: String) -> Bool {
    shouldSuppress(chunk, scriptBody: scriptBody)
  }

  private static func shouldSuppress(_ stderrText: String, scriptBody: String) -> Bool {
    let text = stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard text.count > 20 else { return false }
    if text == scriptBody { return true }
    if scriptBody.contains(text) { return true }
    if text.contains(scriptBody.prefix(min(scriptBody.count, 120))) { return true }
    return false
  }
}
