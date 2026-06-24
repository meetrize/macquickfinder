import Foundation

enum OutputCommandHistoryDirection {
    case up
    case down
}

/// 输出面板命令框历史（每 Job Tab 独立，类似终端 ↑/↓）。
struct OutputCommandHistory: Equatable {
    /// 推荐默认：100 条。足够日常翻阅，内存可忽略（约数十 KB/Tab）。
    static let defaultCapacity = 100

    private(set) var entries: [String]
    private var browseIndex: Int?
    private var draftBeforeBrowse = ""

    init(entries: [String] = []) {
        self.entries = Array(entries.suffix(Self.defaultCapacity))
    }

    mutating func record(_ command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if entries.last != trimmed {
            entries.append(trimmed)
            if entries.count > Self.defaultCapacity {
                entries.removeFirst(entries.count - Self.defaultCapacity)
            }
        }
        resetBrowsing()
    }

    mutating func resetBrowsing() {
        browseIndex = nil
        draftBeforeBrowse = ""
    }

    mutating func step(_ direction: OutputCommandHistoryDirection, currentDraft: String) -> String? {
        switch direction {
        case .up:
            return stepUp(currentDraft: currentDraft)
        case .down:
            return stepDown()
        }
    }

    private mutating func stepUp(currentDraft: String) -> String? {
        guard !entries.isEmpty else { return nil }
        if browseIndex == nil {
            draftBeforeBrowse = currentDraft
            browseIndex = entries.count - 1
            return entries[browseIndex!]
        }
        guard let index = browseIndex, index > 0 else { return nil }
        browseIndex = index - 1
        return entries[browseIndex!]
    }

    private mutating func stepDown() -> String? {
        guard let index = browseIndex else { return nil }
        if index < entries.count - 1 {
            browseIndex = index + 1
            return entries[browseIndex!]
        }
        browseIndex = nil
        return draftBeforeBrowse
    }
}
