import Foundation

struct SnippetAskParameter: Equatable, Identifiable {
    /// 去重键：`id:xxx` 或 `prompt:…`
    var key: String
    /// 语法中的可选命名 id（`%ask[name]{…}`）
    var askId: String?
    var prompt: String
    var isSecret: Bool

    var id: String { key }
}

enum SnippetAskParseError: LocalizedError, Equatable {
    case emptyPrompt
    case unclosedBrace
    case invalidId(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return L10n.Error.SnippetAsk.emptyPrompt
        case .unclosedBrace:
            return L10n.Error.SnippetAsk.unclosedBrace
        case .invalidId(let id):
            return L10n.Error.SnippetAsk.invalidId(id)
        }
    }
}

enum SnippetAskParser {
    private static let secretHints = ["password", "secret", "token", "密码"]

    /// 按首次出现顺序返回去重后的参数列表。
    static func uniqueParameters(in template: String) throws -> [SnippetAskParameter] {
        let matches = try matches(in: template)
        var seen = Set<String>()
        var result: [SnippetAskParameter] = []
        for match in matches {
            if seen.insert(match.parameter.key).inserted {
                result.append(match.parameter)
            }
        }
        return result
    }

    /// 全部字面匹配（含重复），用于替换。
    static func matches(in template: String) throws -> [AskMatch] {
        var result: [AskMatch] = []
        var searchStart = template.startIndex

        while searchStart < template.endIndex {
            guard let askRange = template.range(of: "%ask", range: searchStart..<template.endIndex) else {
                break
            }

            var cursor = askRange.upperBound
            guard cursor < template.endIndex else {
                searchStart = askRange.upperBound
                continue
            }

            var askId: String?
            if template[cursor] == "[" {
                guard let closeBracket = template[cursor...].firstIndex(of: "]") else {
                    throw SnippetAskParseError.invalidId("")
                }
                let idStart = template.index(after: cursor)
                let rawId = String(template[idStart..<closeBracket])
                guard isValidAskId(rawId) else {
                    throw SnippetAskParseError.invalidId(rawId)
                }
                askId = rawId
                cursor = template.index(after: closeBracket)
            }

            guard cursor < template.endIndex, template[cursor] == "{" else {
                // 不是 `%ask{` / `%ask[…]{`（例如误写），跳过该前缀继续扫
                searchStart = askRange.upperBound
                continue
            }

            let promptStart = template.index(after: cursor)
            guard let promptEnd = template[promptStart...].firstIndex(of: "}") else {
                throw SnippetAskParseError.unclosedBrace
            }
            let prompt = String(template[promptStart..<promptEnd])
            guard !prompt.isEmpty else {
                throw SnippetAskParseError.emptyPrompt
            }

            let fullEnd = template.index(after: promptEnd)
            let key = askId.map { "id:\($0)" } ?? "prompt:\(prompt)"
            let parameter = SnippetAskParameter(
                key: key,
                askId: askId,
                prompt: prompt,
                isSecret: isSecretHint(askId: askId, prompt: prompt)
            )
            result.append(AskMatch(parameter: parameter, range: askRange.lowerBound..<fullEnd))
            searchStart = fullEnd
        }

        return result
    }

    static func isValidAskId(_ rawId: String) -> Bool {
        guard let first = rawId.unicodeScalars.first else { return false }
        guard isASCIIIdStart(first) else { return false }
        return rawId.unicodeScalars.dropFirst().allSatisfy(isASCIIIdContinue)
    }

    private static func isASCIIIdStart(_ scalar: UnicodeScalar) -> Bool {
        (scalar >= "A" && scalar <= "Z")
            || (scalar >= "a" && scalar <= "z")
            || scalar == "_"
    }

    private static func isASCIIIdContinue(_ scalar: UnicodeScalar) -> Bool {
        isASCIIIdStart(scalar) || (scalar >= "0" && scalar <= "9")
    }

    private static func isSecretHint(askId: String?, prompt: String) -> Bool {
        let haystack = ((askId ?? "") + " " + prompt).lowercased()
        return secretHints.contains { haystack.contains($0) }
    }

    struct AskMatch: Equatable {
        var parameter: SnippetAskParameter
        var range: Range<String.Index>
    }
}
