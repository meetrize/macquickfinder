import Foundation

/// Shell 单引号转义，用于将字符串安全嵌入 `/bin/sh -c` 等命令。
enum ShellQuoting {
  static func singleQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}
