import AppKit

/// 强化系统标签栏「当前标签」视觉：macOS 26+ liquid glass 下选中/未选中常几乎无差别。
/// 通过公开的 `NSGlassEffectView.tintColor` + 标题字重/颜色区分活动标签（无描边）。
@MainActor
enum ExplorerTabBarActiveAppearance {
    private static var didInstall = false
    private static var applyScheduled = false
    private static var observers: [NSObjectProtocol] = []

    static func installIfNeeded() {
        guard !didInstall else { return }
        didInstall = true
        let center = NotificationCenter.default
        let names: [Notification.Name] = [
            NSWindow.didBecomeKeyNotification,
            NSWindow.didResignKeyNotification,
            NSWindow.didUpdateNotification,
            NSWindow.didResizeNotification,
            NSWindow.didChangeOcclusionStateNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in
                    scheduleApply()
                }
            }
        }
        scheduleApply()
    }

    static func scheduleApply() {
        guard !applyScheduled else { return }
        applyScheduled = true
        DispatchQueue.main.async {
            applyScheduled = false
            applyToVisibleExplorerWindows()
            // 系统标签栏偶发晚一拍重建，再补一次。
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                applyToVisibleExplorerWindows()
            }
        }
    }

    private static func applyToVisibleExplorerWindows() {
        let candidates = NSApp.windows.filter { window in
            guard window.isVisible || window.isKeyWindow else { return false }
            guard window.tabbingMode != .disallowed else { return false }
            guard let group = window.tabGroup, group.windows.count > 1, group.isTabBarVisible else {
                return false
            }
            return true
        }
        // 每个 tabGroup 只处理一次（优先 selected / key）。
        var seenGroups = Set<ObjectIdentifier>()
        for window in candidates {
            guard let group = window.tabGroup else { continue }
            let groupID = ObjectIdentifier(group)
            guard !seenGroups.contains(groupID) else { continue }
            seenGroups.insert(groupID)
            let host = group.selectedWindow ?? (window.isKeyWindow ? window : group.windows.first)
            guard let host else { continue }
            apply(to: host)
        }
    }

    private static func apply(to window: NSWindow) {
        guard let tabGroup = window.tabGroup,
              tabGroup.windows.count > 1,
              let tabBar = ExplorerTabBarHitTesting.findTabBarView(in: window) else {
            return
        }
        let buttons = ExplorerTabBarHitTesting.tabButtonViews(in: tabBar)
            .sorted { $0.frame.minX < $1.frame.minX }
        guard !buttons.isEmpty else { return }

        let orderedWindows = tabGroup.windows
        let activeIndex: Int = {
            if let selected = tabGroup.selectedWindow,
               let idx = orderedWindows.firstIndex(of: selected) {
                return idx
            }
            return 0
        }()

        // 按钮数偶发与窗口数不一致时，按较短一侧对齐，避免越界。
        let count = min(buttons.count, orderedWindows.count)
        for index in 0..<count {
            styleTabButton(buttons[index], isActive: index == activeIndex)
        }
    }

    private static func styleTabButton(_ button: NSView, isActive: Bool) {
        let fill: NSColor
        let titleColor: NSColor
        let weight: NSFont.Weight
        if isActive {
            // 选中：只要强调色底 + 半粗标题，不要描边。
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
            layer.backgroundColor = fill.cgColor
            layer.borderWidth = 0
            layer.borderColor = nil
        }

        styleTitle(of: button, color: titleColor, weight: weight)
        button.needsDisplay = true
    }

    @available(macOS 26.0, *)
    private static func tintGlass(in root: NSView, color: NSColor) {
        if let glass = root as? NSGlassEffectView {
            glass.tintColor = color
            // 选中标签略提高交互反馈，未选中保持静态。
            if #available(macOS 27.0, *) {
                glass.effectIsInteractive = (color.alphaComponent > 0.2)
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
