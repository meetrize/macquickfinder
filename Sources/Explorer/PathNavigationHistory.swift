import Foundation

/// 文件浏览器地址栏导航历史：后退栈、前进栈与可展示的访问轨迹。
struct PathNavigationHistory: Equatable {
    private(set) var backStack: [String] = []
    private(set) var forwardStack: [String] = []

    var canGoBack: Bool { !backStack.isEmpty }
    var canGoForward: Bool { !forwardStack.isEmpty }

    /// 按访问顺序排列的轨迹：…后退栈、当前路径、前进栈（由近到远）…
    func trail(currentPath: String) -> [String] {
        backStack + [currentPath] + forwardStack.reversed()
    }

    /// 历史菜单条目，最近访问的排在最前。
    func recentEntries(currentPath: String) -> [String] {
        trail(currentPath: currentPath).reversed()
    }

    mutating func recordNavigation(from oldPath: String, to newPath: String) {
        guard oldPath != newPath else { return }
        backStack.append(oldPath)
        forwardStack.removeAll()
    }

    mutating func goBack(from currentPath: String) -> String? {
        guard let previous = backStack.popLast() else { return nil }
        forwardStack.append(currentPath)
        return previous
    }

    mutating func goForward(from currentPath: String) -> String? {
        guard let next = forwardStack.popLast() else { return nil }
        backStack.append(currentPath)
        return next
    }

    /// 从历史菜单跳转到轨迹中的某一路径，并同步后退/前进栈。
    mutating func jump(to targetPath: String, from currentPath: String) {
        let trail = trail(currentPath: currentPath)
        let target = (targetPath as NSString).standardizingPath
        guard let index = trail.firstIndex(where: { ($0 as NSString).standardizingPath == target }) else {
            return
        }
        backStack = Array(trail[..<index])
        forwardStack = Array(trail[(index + 1)...]).reversed()
    }
}

enum PathBarHistoryDirection {
    case up
    case down
}

/// 地址栏文本模式下 ↑/↓ 浏览历史（类似终端命令历史）。
struct PathBarHistoryBrowsing: Equatable {
    private var browseIndex: Int?
    private var draftBeforeBrowse = ""

    mutating func reset() {
        browseIndex = nil
        draftBeforeBrowse = ""
    }

    mutating func step(_ direction: PathBarHistoryDirection, currentDraft: String, entries: [String]) -> String? {
        switch direction {
        case .up:
            return stepUp(currentDraft: currentDraft, entries: entries)
        case .down:
            return stepDown(entries: entries)
        }
    }

    private mutating func stepUp(currentDraft: String, entries: [String]) -> String? {
        guard !entries.isEmpty else { return nil }
        if browseIndex == nil {
            draftBeforeBrowse = currentDraft
            browseIndex = 0
            return entries[0]
        }
        guard let index = browseIndex, index + 1 < entries.count else { return nil }
        browseIndex = index + 1
        return entries[browseIndex!]
    }

    private mutating func stepDown(entries: [String]) -> String? {
        guard let index = browseIndex else { return nil }
        if index > 0 {
            browseIndex = index - 1
            return entries[browseIndex!]
        }
        browseIndex = nil
        return draftBeforeBrowse
    }
}
