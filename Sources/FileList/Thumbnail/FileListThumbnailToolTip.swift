import AppKit

/// 缩略图模式 tooltip 辅助：通过 UserDefaults 控制延迟，`showToolTip:forView:` 通过运行时调用。
enum FileListThumbnailToolTip {
    private static let delayUserDefaultsKey = "NSInitialToolTipDelay"
    private static let sharedManagerSelector = NSSelectorFromString("sharedToolTipManager")
    private static let showSelector = NSSelectorFromString("showToolTip:forView:")
    
    private static var manager: NSObject? {
        guard let cls = NSClassFromString("NSToolTipManager") as? NSObject.Type,
              cls.responds(to: sharedManagerSelector)
        else { return nil }
        return cls.perform(sharedManagerSelector)?.takeUnretainedValue() as? NSObject
    }
    
    static var initialDelay: TimeInterval {
        get {
            let defaults = UserDefaults.standard
            guard defaults.object(forKey: delayUserDefaultsKey) != nil else { return 1 }
            return defaults.double(forKey: delayUserDefaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: delayUserDefaultsKey)
        }
    }
    
    static func show(_ tip: String, for view: NSView) {
        guard !tip.isEmpty, let manager else { return }
        _ = manager.perform(showSelector, with: tip, with: view)
    }
}
