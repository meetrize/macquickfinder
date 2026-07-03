import Foundation

enum GitPorcelainParser {
    static func parse(zTerminated data: Data) -> [GitPorcelainEntry] {
        guard !data.isEmpty else { return [] }

        var entries: [GitPorcelainEntry] = []
        var index = data.startIndex

        while index < data.endIndex {
            guard let lineEnd = data[index...].firstIndex(of: 0) else { break }
            let lineData = data[index..<lineEnd]
            index = data.index(after: lineEnd)

            guard lineData.count >= 2,
                  let line = String(data: lineData, encoding: .utf8) else {
                continue
            }

            let indexStatus = line[line.startIndex]
            let workTreeStatus = line[line.index(after: line.startIndex)]
            let path = extractPath(from: line)

            if indexStatus == "R" || workTreeStatus == "R" {
                guard index < data.endIndex else {
                    entries.append(
                        GitPorcelainEntry(status: .renamed, path: path, oldPath: nil)
                    )
                    continue
                }
                let newPathEnd = data[index...].firstIndex(of: 0) ?? data.endIndex
                let newPathData = data[index..<newPathEnd]
                index = newPathEnd < data.endIndex ? data.index(after: newPathEnd) : data.endIndex
                let newPath = String(data: newPathData, encoding: .utf8) ?? path
                entries.append(
                    GitPorcelainEntry(status: .renamed, path: newPath, oldPath: path.isEmpty ? nil : path)
                )
                continue
            }

            let status = mapStatus(index: indexStatus, workTree: workTreeStatus)
            guard !path.isEmpty else { continue }
            entries.append(GitPorcelainEntry(status: status, path: path))
        }

        return entries
    }

    private static func extractPath(from line: String) -> String {
        guard line.count > 3 else { return "" }
        let remainder = line[line.index(line.startIndex, offsetBy: 3)...]
        return String(remainder)
    }

    private static func mapStatus(index: Character, workTree: Character) -> GitPathStatus {
        if index == "U" || workTree == "U" {
            return .conflict
        }
        if index == "A" && workTree == "A" {
            return .conflict
        }
        if index == "D" && workTree == "D" {
            return .conflict
        }
        if index == "?" && workTree == "?" {
            return .untracked
        }
        if index == "A" || workTree == "A" {
            return .added
        }
        if index == "D" || workTree == "D" {
            return .deleted
        }
        if index == "R" || workTree == "R" {
            return .renamed
        }
        return .modified
    }
}
