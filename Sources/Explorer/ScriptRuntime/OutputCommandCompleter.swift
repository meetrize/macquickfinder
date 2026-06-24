import Foundation

/// Tab 补全时的候选轮换状态。
struct OutputCommandCompletionSession: Equatable {
    var candidates: [String] = []
    var cycleIndex: Int = 0
    var anchorWord: String = ""

    mutating func reset() {
        candidates = []
        cycleIndex = 0
        anchorWord = ""
    }
}

enum OutputCommandWordParser {
    static func wordRange(in line: String, cursor: Int) -> Range<String.Index>? {
        guard !line.isEmpty else { return nil }
        let ns = line as NSString
        let length = ns.length
        let clamped = min(max(cursor, 0), length)
        var start = clamped
        var end = clamped
        while start > 0 {
            let ch = ns.character(at: start - 1)
            if ch == 32 || ch == 9 { break }
            start -= 1
        }
        while end < length {
            let ch = ns.character(at: end)
            if ch == 32 || ch == 9 { break }
            end += 1
        }
        guard start < end else { return nil }
        return Range(NSRange(location: start, length: end - start), in: line)
    }

    static func currentWord(in line: String, cursor: Int) -> String {
        guard let range = wordRange(in: line, cursor: cursor) else { return "" }
        return String(line[range])
    }

    static func isFirstWord(in line: String, cursor: Int) -> Bool {
        guard let range = wordRange(in: line, cursor: cursor) else { return true }
        return range.lowerBound == line.startIndex
    }
}

struct OutputCommandCompletionRequest: Equatable {
    var line: String
    var cursor: Int
    var cwd: String
}

struct OutputCommandCompletionResult: Equatable {
    var line: String
    var cursor: Int
    var listForDisplay: [String]?
}

enum OutputCommandCompleter {
    typealias CandidatesProvider = (_ word: String, _ line: String, _ cwd: String) -> [String]

    private static let zshScript = #"""
    cd "$MEOFINDER_CWD" 2>/dev/null || exit 0
    word="$MEOFINDER_WORD"
    line="$MEOFINDER_LINE"
    setopt localoptions nullglob markdirs extendedglob nonomatch
    if [[ -z "$word" ]]; then
      exit 0
    fi
    if [[ "$word" == */* || "$word" == /* || "$word" == ~* || "$word" == .* ]]; then
      matches=(${~word}*(N))
      for match in $matches; do
        if [[ -d "$match" ]]; then
          print -r -- "${match}/"
        else
          print -r -- "$match"
        fi
      done
      exit 0
    fi
    if [[ "$line" == "$word" || "$line" == "$word "* ]]; then
      print -rl -- ${(ko)commands[(I)${word}*]}
      exit 0
    fi
    dir="$MEOFINDER_CWD"
    prefix="$word"
    if [[ "$word" == */* ]]; then
      dir="${word%/*}"
      prefix="${word##*/}"
      [[ -d "$dir" ]] || dir="$MEOFINDER_CWD"
    fi
    for entry in "$dir"/*(N); do
      name="${entry:t}"
      [[ "$name" == ${prefix}* ]] || continue
      if [[ -d "$entry" ]]; then
        if [[ "$word" == */* ]]; then
          print -r -- "${word%/*}/${name}/"
        else
          print -r -- "${name}/"
        fi
      else
        if [[ "$word" == */* ]]; then
          print -r -- "${word%/*}/${name}"
        else
          print -r -- "$name"
        fi
      fi
    done
    """#

    static func complete(
        request: OutputCommandCompletionRequest,
        session: inout OutputCommandCompletionSession,
        candidatesProvider: CandidatesProvider? = nil
    ) -> OutputCommandCompletionResult? {
        let word = OutputCommandWordParser.currentWord(in: request.line, cursor: request.cursor)
        guard !word.isEmpty else { return nil }
        guard let wordRange = OutputCommandWordParser.wordRange(in: request.line, cursor: request.cursor) else {
            return nil
        }

        let provider = candidatesProvider ?? defaultCandidatesProvider
        let candidates = uniqueSorted(provider(word, request.line, request.cwd))
        guard !candidates.isEmpty else {
            session.reset()
            return nil
        }

        if session.candidates == candidates,
           candidates.count > 1,
           word == session.anchorWord || session.candidates.contains(word) {
            let index = session.cycleIndex % candidates.count
            let chosen = candidates[index]
            session.cycleIndex = (index + 1) % candidates.count
            return apply(chosen, request: request, wordRange: wordRange, listForDisplay: nil)
        }

        session.anchorWord = word
        session.candidates = candidates
        session.cycleIndex = 0

        if candidates.count == 1 {
            return apply(candidates[0], request: request, wordRange: wordRange, listForDisplay: nil)
        }

        if let prefix = longestCommonPrefix(in: candidates), prefix.count > word.count {
            let partial = String(prefix)
            return apply(partial, request: request, wordRange: wordRange, listForDisplay: nil)
        }

        let chosen = candidates[0]
        session.cycleIndex = 1
        return apply(
            chosen,
            request: request,
            wordRange: wordRange,
            listForDisplay: candidates.count > 1 ? candidates : nil
        )
    }

    private static let defaultCandidatesProvider: CandidatesProvider = { word, line, cwd in
        if let zsh = fetchCandidatesWithZsh(word: word, line: line, cwd: cwd), !zsh.isEmpty {
            return zsh
        }
        return fetchCandidatesWithSwift(word: word, line: line, cwd: cwd)
    }

    private static func fetchCandidatesWithZsh(word: String, line: String, cwd: String) -> [String]? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-ilc", zshScript]
        var environment = ProcessInfo.processInfo.environment
        environment["MEOFINDER_CWD"] = SnippetExpander.standardize(cwd)
        environment["MEOFINDER_WORD"] = word
        environment["MEOFINDER_LINE"] = line
        process.environment = environment
        process.currentDirectoryURL = URL(fileURLWithPath: SnippetExpander.standardize(cwd))

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            process.waitUntilExit()
            group.leave()
        }
        let timedOut = group.wait(timeout: .now() + 0.35) == .timedOut
        if timedOut {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return nil }
        return output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func fetchCandidatesWithSwift(word: String, line: String, cwd: String) -> [String] {
        if OutputCommandWordParser.isFirstWord(in: line, cursor: line.count) && !word.contains("/") {
            return completeCommands(prefix: word)
        }
        return completePaths(partial: word, cwd: cwd)
    }

    private static func completeCommands(prefix: String) -> [String] {
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        var names = Set<String>()
        let fileManager = FileManager.default
        for dir in pathEnv.split(separator: ":") {
            let directory = String(dir)
            guard let entries = try? fileManager.contentsOfDirectory(atPath: directory) else { continue }
            for entry in entries where entry.hasPrefix(prefix) {
                var isDirectory: ObjCBool = false
                let fullPath = (directory as NSString).appendingPathComponent(entry)
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDirectory),
                      !isDirectory.boolValue else { continue }
                names.insert(entry)
            }
        }
        return names.sorted()
    }

    private static func completePaths(partial: String, cwd: String) -> [String] {
        let standardizedCWD = SnippetExpander.standardize(cwd)
        let expanded = (partial as NSString).expandingTildeInPath
        let isAbsolute = expanded.hasPrefix("/")
        let base = isAbsolute ? "" : standardizedCWD
        let fullPartial = isAbsolute ? expanded : (base as NSString).appendingPathComponent(expanded)
        let directory = (fullPartial as NSString).deletingLastPathComponent
        let prefix = (fullPartial as NSString).lastPathComponent
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: directory) else { return [] }

        return entries
            .filter { $0.hasPrefix(prefix) || prefix.isEmpty }
            .sorted()
            .map { entry in
                let full = (directory as NSString).appendingPathComponent(entry)
                var isDirectory: ObjCBool = false
                _ = FileManager.default.fileExists(atPath: full, isDirectory: &isDirectory)
                let relative: String
                if partial.contains("/") {
                    let head = (partial as NSString).deletingLastPathComponent
                    relative = head.isEmpty ? entry : "\(head)/\(entry)"
                } else {
                    relative = entry
                }
                return isDirectory.boolValue ? "\(relative)/" : relative
            }
    }

    private static func apply(
        _ replacement: String,
        request: OutputCommandCompletionRequest,
        wordRange: Range<String.Index>,
        listForDisplay: [String]?
    ) -> OutputCommandCompletionResult {
        var line = request.line
        line.replaceSubrange(wordRange, with: replacement)
        let cursorOffset = line.distance(
            from: line.startIndex,
            to: wordRange.lowerBound
        ) + replacement.count
        return OutputCommandCompletionResult(
            line: line,
            cursor: cursorOffset,
            listForDisplay: listForDisplay
        )
    }

    static func longestCommonPrefix(in values: [String]) -> String? {
        guard let first = values.first else { return nil }
        var prefix = first
        for value in values.dropFirst() {
            while !value.hasPrefix(prefix) {
                guard !prefix.isEmpty else { return "" }
                prefix = String(prefix.dropLast())
            }
        }
        return prefix
    }

    private static func uniqueSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted()
    }
}
