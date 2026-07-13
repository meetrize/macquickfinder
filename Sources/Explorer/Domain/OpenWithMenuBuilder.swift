import AppKit
import CoreServices

@MainActor
enum OpenWithMenuBuilder {
    struct ApplicationOption: Identifiable, Equatable {
        let id: String
        let url: URL
        let displayName: String
        let isDefault: Bool
    }

    static func applicationOptions(for primaryFileURL: URL) -> [ApplicationOption] {
        let workspace = NSWorkspace.shared
        let defaultApp = defaultApplicationURL(for: primaryFileURL)
        let candidates = applicationURLs(for: primaryFileURL)
        let uniqueApps: [URL] = {
            var seen = Set<String>()
            var result: [URL] = []
            for url in candidates {
                let key = url.resolvingSymlinksInPath().path
                if seen.insert(key).inserted { result.append(url) }
            }
            return result
        }()

        var options: [ApplicationOption] = []
        if let defaultApp {
            options.append(makeOption(appURL: defaultApp, isDefault: true, workspace: workspace))
        }

        let sortedApps = uniqueApps
            .filter { $0 != defaultApp }
            .sorted { appDisplayName($0).localizedStandardCompare(appDisplayName($1)) == .orderedAscending }

        for appURL in sortedApps.prefix(10) {
            options.append(makeOption(appURL: appURL, isDefault: false, workspace: workspace))
        }
        return options
    }

    static func makeMenu(
        fileURLs: [URL],
        primaryFileURL: URL,
        onOpenWithApplication: @escaping (URL) -> Void,
        onChooseOther: @escaping () -> Void
    ) -> NSMenu {
        let submenu = NSMenu()
        submenu.showsStateColumn = false

        guard !fileURLs.isEmpty else {
            let disabled = NSMenuItem(title: L10n.Action.openWithNone, action: nil, keyEquivalent: "")
            disabled.isEnabled = false
            submenu.addItem(disabled)
            return submenu
        }

        let workspace = NSWorkspace.shared
        let options = applicationOptions(for: primaryFileURL)

        func addAppItem(option: ApplicationOption) {
            let title = option.isDefault
                ? L10n.Action.openWithDefault(option.displayName)
                : option.displayName
            let item = OpenWithCallbackMenuItem(title: title) {
                onOpenWithApplication(option.url)
            }
            item.image = workspace.icon(forFile: option.url.path)
            configureAppMenuItemAppearance(item)
            submenu.addItem(item)
        }

        if let defaultOption = options.first(where: \.isDefault) {
            addAppItem(option: defaultOption)
            let nonDefault = options.filter { !$0.isDefault }
            if !nonDefault.isEmpty {
                submenu.addItem(.separator())
            }
            for option in nonDefault {
                addAppItem(option: option)
            }
        } else {
            for option in options {
                addAppItem(option: option)
            }
        }

        submenu.addItem(.separator())
        submenu.addItem(
            OpenWithCallbackMenuItem(title: L10n.Action.openWithOther) {
                onChooseOther()
            }
        )
        return submenu
    }

    static func presentMenu(
        fileURLs: [URL],
        primaryFileURL: URL,
        positioning view: NSView?,
        onOpenWithApplication: @escaping (URL) -> Void,
        onChooseOther: @escaping () -> Void
    ) {
        let menu = makeMenu(
            fileURLs: fileURLs,
            primaryFileURL: primaryFileURL,
            onOpenWithApplication: onOpenWithApplication,
            onChooseOther: onChooseOther
        )
        if let view {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
        } else {
            menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        }
    }

    static func open(fileURLs: [URL], withApplicationAt appURL: URL) {
        guard !fileURLs.isEmpty else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.open(fileURLs, withApplicationAt: appURL, configuration: configuration)
    }

    private static func makeOption(
        appURL: URL,
        isDefault: Bool,
        workspace: NSWorkspace
    ) -> ApplicationOption {
        ApplicationOption(
            id: appURL.resolvingSymlinksInPath().path,
            url: appURL,
            displayName: appDisplayName(appURL),
            isDefault: isDefault
        )
    }

    private static func configureAppMenuItemAppearance(_ item: NSMenuItem) {
        item.indentationLevel = 0
        if let image = item.image {
            image.size = NSSize(width: 16, height: 16)
            image.isTemplate = false
            item.image = image
        }
    }

    private static func defaultApplicationURL(for fileURL: URL) -> URL? {
        if #available(macOS 12.0, *) {
            return NSWorkspace.shared.urlForApplication(toOpen: fileURL)
        }
        return LSCopyDefaultApplicationURLForURL(
            fileURL as CFURL,
            .all,
            nil
        )?.takeRetainedValue() as URL?
    }

    private static func applicationURLs(for fileURL: URL) -> [URL] {
        if #available(macOS 12.0, *) {
            return NSWorkspace.shared.urlsForApplications(toOpen: fileURL)
        }
        guard let urls = LSCopyApplicationURLsForURL(fileURL as CFURL, .all)?
            .takeRetainedValue() as? [URL] else {
            return []
        }
        return urls
    }

    private static func appDisplayName(_ appURL: URL) -> String {
        if let bundle = Bundle(url: appURL) {
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !name.isEmpty {
                return name
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
                return name
            }
        }
        return appURL.deletingPathExtension().lastPathComponent
    }
}

private final class OpenWithCallbackMenuItem: NSMenuItem {
    private let callback: () -> Void

    init(title: String, action: @escaping () -> Void) {
        callback = action
        super.init(title: title, action: #selector(performAction), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func performAction() {
        callback()
    }
}
