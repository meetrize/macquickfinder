import AppKit

/// 强化系统标签栏「当前标签」视觉：macOS 26+ liquid glass 下选中/未选中常几乎无差别。
/// 通过公开的 `NSGlassEffectView.tintColor` + 标题字重/颜色区分活动标签（无描边）。
///
/// 性能约束（多标签必读）：
/// - **禁止**订阅 `NSWindow.didUpdateNotification`：样式写入会触发 update，再 apply 会形成主线程死循环。
/// - 合并短时多次 `scheduleApply`，避免切标签/resize 风暴时反复 DFS 整棵标题栏视图树。
/// - 样式未变则跳过写入（`attributedTitle` / layer 变更会再引发 update）。
@MainActor
enum ExplorerTabBarActiveAppearance {
    private static var didInstall = false
    private static var applyWorkItem: DispatchWorkItem?
    private static var observers: [NSObjectProtocol] = []
    /// 每个 tabGroup 上次应用的活动下标与按钮数；相同则跳过写样式。
    private static var lastAppliedSignatureByGroup: [ObjectIdentifier: AppliedSignature] = [:]

    private struct AppliedSignature: Equatable {
        let activeIndex: Int
        let buttonCount: Int
        let windowCount: Int
    }

    static func installIfNeeded() {
        guard !didInstall else { return }
        didInstall = true
        let center = NotificationCenter.default
        // 刻意不含 didUpdate：它会在几乎每帧触发，且本类型写样式会再次触发 update。
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didResizeNotification,
            NSWindow.didChangeOcclusionStateNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { notification in
                guard let window = notification.object as? NSWindow,
                      shouldTrack(window: window) else {
                    return
                }
                // 系统可能已重置标签样式；强制重上色。
                Task { @MainActor in
                    scheduleApply(forceRestyle: true)
                }
            }
        }
        scheduleApply(forceRestyle: true)
    }

    static func scheduleApply() {
        scheduleApply(forceRestyle: false)
    }

    /// - Parameter forceRestyle: 为 true 时忽略「样式未变」短路（key/resize 后系统可能已清掉我们的 tint）。
    static func scheduleApply(forceRestyle: Bool) {
        if forceRestyle {
            lastAppliedSignatureByGroup.removeAll(keepingCapacity: true)
        }
        applyWorkItem?.cancel()
        let work = DispatchWorkItem {
            applyWorkItem = nil
            applyToVisibleExplorerWindows()
        }
        applyWorkItem = work
        // 合并同一事件循环内的多次 schedule（切标签 / bump revision / resize）。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016, execute: work)
    }

    private static func shouldTrack(window: NSWindow) -> Bool {
        guard window.isVisible || window.isKeyWindow else { return false }
        guard window.tabbingMode != .disallowed else { return false }
        guard let group = window.tabGroup, group.windows.count > 1, group.isTabBarVisible else {
            return false
        }
        return true
    }

    private static func applyToVisibleExplorerWindows() {
        let candidates = NSApp.windows.filter(shouldTrack(window:))
        // 每个 tabGroup 只处理一次（优先 selected / key）。
        var seenGroups = Set<ObjectIdentifier>()
        var liveGroups = Set<ObjectIdentifier>()
        for window in candidates {
            guard let group = window.tabGroup else { continue }
            let groupID = ObjectIdentifier(group)
            guard !seenGroups.contains(groupID) else { continue }
            seenGroups.insert(groupID)
            liveGroups.insert(groupID)
            let host = group.selectedWindow ?? (window.isKeyWindow ? window : group.windows.first)
            guard let host else { continue }
            apply(to: host, groupID: groupID)
        }
        lastAppliedSignatureByGroup = lastAppliedSignatureByGroup.filter { liveGroups.contains($0.key) }
    }

    private static func apply(to window: NSWindow, groupID: ObjectIdentifier) {
        guard let tabGroup = window.tabGroup,
              tabGroup.windows.count > 1,
              let tabBar = ExplorerTabBarHitTesting.findTabBarView(in: window) else {
            lastAppliedSignatureByGroup.removeValue(forKey: groupID)
            return
        }
        let buttons = ExplorerTabBarHitTesting.tabButtonViews(in: tabBar)
            .sorted { $0.frame.minX < $1.frame.minX }
        guard !buttons.isEmpty else {
            lastAppliedSignatureByGroup.removeValue(forKey: groupID)
            return
        }

        let orderedWindows = tabGroup.windows
        let activeIndex: Int = {
            if let selected = tabGroup.selectedWindow,
               let idx = orderedWindows.firstIndex(of: selected) {
                return idx
            }
            return 0
        }()

        let count = min(buttons.count, orderedWindows.count)
        let signature = AppliedSignature(
            activeIndex: activeIndex,
            buttonCount: count,
            windowCount: orderedWindows.count
        )
        if lastAppliedSignatureByGroup[groupID] == signature {
            return
        }
        lastAppliedSignatureByGroup[groupID] = signature

        for index in 0..<count {
            styleTabButton(buttons[index], isActive: index == activeIndex)
        }
    }

    private static func styleTabButton(_ button: NSView, isActive: Bool) {
        let fill: NSColor
        let titleColor: NSColor
        let weight: NSFont.Weight
        if isActive {
            fill = NSColor.controlAccentColor.withAlphaComponent(0.38)
            titleColor = .labelColor
            weight = .semibold
        } else {
            fill = NSColor.labelColor.withAlphaComponent(0.05)
            titleColor = .secondaryLabelColor
            weight = .regular
        }

        if #available(macOS 26.0, *) {
            tintGlass(
                in: button,
                color: isActive
                    ? NSColor.controlAccentColor.withAlphaComponent(0.45)
                    : NSColor.labelColor.withAlphaComponent(0.04)
            )
        }

        button.wantsLayer = true
        if let layer = button.layer {
            layer.cornerRadius = 8
            layer.masksToBounds = true
            // 仅在颜色变化时写 layer，减少无谓 display。
            let next = fill.cgColor
            if layer.backgroundColor != next {
                layer.backgroundColor = next
            }
            if layer.borderWidth != 0 {
                layer.borderWidth = 0
                layer.borderColor = nil
            }
        }

        styleTitle(of: button, color: titleColor, weight: weight)
    }

    @available(macOS 26.0, *)
    private static func tintGlass(in root: NSView, color: NSColor) {
        if let glass = root as? NSGlassEffectView {
            if glass.tintColor != color {
                glass.tintColor = color
            }
            if #available(macOS 27.0, *) {
                let interactive = color.alphaComponent > 0.2
                if glass.effectIsInteractive != interactive {
                    glass.effectIsInteractive = interactive
                }
            }
        }
        for subview in root.subviews {
            tintGlass(in: subview, color: color)
        }
    }

    private static func styleTitle(of tab: NSView, color: NSColor, weight: NSFont.Weight) {
        let object = tab as AnyObject
        guard object.responds(to: Selector(("setAttributedTitle:"))) else { return }
        let rawTitle = (object.value(forKey: "title") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let title = rawTitle, !title.isEmpty else { return }

        if let existing = object.value(forKey: "attributedTitle") as? NSAttributedString,
           existing.string == title {
            var fullRange = NSRange(location: 0, length: existing.length)
            let existingColor = existing.attribute(.foregroundColor, at: 0, effectiveRange: &fullRange) as? NSColor
            let existingFont = existing.attribute(.font, at: 0, effectiveRange: &fullRange) as? NSFont
            let desiredFont = NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: weight)
            if existingColor == color, existingFont == desiredFont {
                return
            }
        }

        let attributed = NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: weight),
            ]
        )
        object.setValue(attributed, forKey: "attributedTitle")
    }
}
