import AppKit
import Combine
import SwiftUI

/// 单窗口 UI 布局状态：运行期各窗口互不影响，写入 UserDefaults 时以最后一次操作为准。
@MainActor
final class ExplorerWindowLayoutState: ObservableObject {
    @Published var showPreview: Bool {
        didSet { persistBool(ExplorerAppSettings.showPreviewKey, showPreview) }
    }

    @Published var showSnippets: Bool {
        didSet { persistBool(ExplorerAppSettings.showSnippetsKey, showSnippets) }
    }

    @Published private(set) var leftPanelModeRaw: String {
        didSet { persistString(AppSettings.leftPanelModeKey, leftPanelModeRaw) }
    }

    @Published private(set) var leftPanelLastVisibleModeRaw: String {
        didSet { persistString(AppSettings.leftPanelLastVisibleModeKey, leftPanelLastVisibleModeRaw) }
    }

    @Published private(set) var leftPanelSidebarWidth: Double {
        didSet { persistDouble(AppSettings.leftPanelSidebarWidthKey, leftPanelSidebarWidth) }
    }

    @Published var previewPanelWidth: Double {
        didSet { persistDouble(AppSettings.previewPanelWidthKey, previewPanelWidth) }
    }

    @Published var previewSnippetsSplitRatio: Double {
        didSet { persistDouble(ExplorerAppSettings.previewSnippetsSplitRatioKey, previewSnippetsSplitRatio) }
    }

    @Published var isOutputPanelVisible: Bool {
        didSet { persistBool(ExplorerAppSettings.outputPanelVisibleKey, isOutputPanelVisible) }
    }

    @Published var outputPanelHeight: Double {
        didSet { persistDouble(ExplorerAppSettings.outputPanelHeightKey, outputPanelHeight) }
    }

    @Published var isSnippetsContentCollapsed: Bool {
        didSet { persistBool(ExplorerAppSettings.snippetsContentCollapsedKey, isSnippetsContentCollapsed) }
    }

    @Published var isOutputPanelContentCollapsed: Bool {
        didSet { persistBool(ExplorerAppSettings.outputPanelContentCollapsedKey, isOutputPanelContentCollapsed) }
    }

    @Published var isPreviewContentCollapsed: Bool {
        didSet { persistBool(ExplorerAppSettings.previewContentCollapsedKey, isPreviewContentCollapsed) }
    }

    private let defaults: UserDefaults
    private let leftPanelConstants = LeftPanelLayoutConstants()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.loadSnapshot(from: defaults)
        showPreview = stored.showPreview
        showSnippets = stored.showSnippets
        leftPanelModeRaw = stored.leftPanelModeRaw
        leftPanelLastVisibleModeRaw = stored.leftPanelLastVisibleModeRaw
        leftPanelSidebarWidth = stored.leftPanelSidebarWidth
        previewPanelWidth = stored.previewPanelWidth
        previewSnippetsSplitRatio = stored.previewSnippetsSplitRatio
        isOutputPanelVisible = stored.isOutputPanelVisible
        outputPanelHeight = stored.outputPanelHeight
        isSnippetsContentCollapsed = stored.isSnippetsContentCollapsed
        isOutputPanelContentCollapsed = stored.isOutputPanelContentCollapsed
        isPreviewContentCollapsed = stored.isPreviewContentCollapsed
    }

    var leftPanelMode: LeftPanelMode {
        LeftPanelMode(rawValue: leftPanelModeRaw) ?? .sidebar
    }

    var leftPanelLastVisibleMode: LeftPanelVisibleMode {
        LeftPanelVisibleMode(rawValue: leftPanelLastVisibleModeRaw) ?? .sidebar
    }

    var leftPanelSidebarWidthValue: CGFloat {
        CGFloat(leftPanelSidebarWidth)
    }

    var leftPanelVisibleWidth: CGFloat {
        switch leftPanelMode {
        case .sidebar:
            return leftPanelSidebarWidthValue
        case .rail:
            return leftPanelConstants.railWidth
        case .hidden:
            return 0
        }
    }

    func setLeftPanelMode(_ mode: LeftPanelMode) {
        leftPanelModeRaw = mode.rawValue
    }

    func setLeftPanelLastVisibleMode(_ mode: LeftPanelVisibleMode) {
        leftPanelLastVisibleModeRaw = mode.rawValue
    }

    func setLeftPanelSidebarWidth(_ width: CGFloat) {
        leftPanelSidebarWidth = Double(leftPanelConstants.clampedSidebarWidth(width))
    }

    func healLeftPanelSidebarWidth() {
        setLeftPanelSidebarWidth(leftPanelSidebarWidthValue)
    }

    func applyLeftPanelDrag(proposedWidth: CGFloat, baseWidth: CGFloat) {
        let result = LeftPanelStateMachine.applyDrag(
            proposedWidth: proposedWidth,
            currentMode: leftPanelMode,
            lastVisible: leftPanelLastVisibleMode,
            sidebarWidth: leftPanelSidebarWidthValue,
            constants: leftPanelConstants
        )
        setLeftPanelMode(result.mode)
        setLeftPanelLastVisibleMode(result.lastVisible)
        setLeftPanelSidebarWidth(result.sidebarWidth)
    }

    func toggleLeftPanelVisibility() {
        if leftPanelMode == .hidden {
            setLeftPanelMode(leftPanelLastVisibleMode.asPanelMode)
            if leftPanelMode == .sidebar {
                setLeftPanelSidebarWidth(leftPanelSidebarWidthValue)
            }
            return
        }

        if leftPanelMode == .sidebar {
            setLeftPanelLastVisibleMode(.sidebar)
        } else if leftPanelMode == .rail {
            setLeftPanelLastVisibleMode(.rail)
        }
        setLeftPanelMode(.hidden)
    }

    func recordLastOpenedPath(_ path: String) {
        let standardized = (path as NSString).standardizingPath
        defaults.set(standardized, forKey: AppSettings.lastOpenedPathKey)
    }

    static func restoredLastOpenedPath(defaults: UserDefaults = .standard) -> String {
        let trimmed = (defaults.string(forKey: AppSettings.lastOpenedPathKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return FileManager.default.homeDirectoryForCurrentUser.path
        }
        let standardized = (trimmed as NSString).standardizingPath
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: standardized, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return standardized
        }
        return FileManager.default.homeDirectoryForCurrentUser.path
    }

    private struct Snapshot {
        var showPreview: Bool
        var showSnippets: Bool
        var leftPanelModeRaw: String
        var leftPanelLastVisibleModeRaw: String
        var leftPanelSidebarWidth: Double
        var previewPanelWidth: Double
        var previewSnippetsSplitRatio: Double
        var isOutputPanelVisible: Bool
        var outputPanelHeight: Double
        var isSnippetsContentCollapsed: Bool
        var isOutputPanelContentCollapsed: Bool
        var isPreviewContentCollapsed: Bool
    }

    private static func loadSnapshot(from defaults: UserDefaults) -> Snapshot {
        Snapshot(
            showPreview: defaults.object(forKey: ExplorerAppSettings.showPreviewKey) as? Bool ?? true,
            showSnippets: defaults.object(forKey: ExplorerAppSettings.showSnippetsKey) as? Bool ?? true,
            leftPanelModeRaw: defaults.string(forKey: AppSettings.leftPanelModeKey) ?? LeftPanelMode.sidebar.rawValue,
            leftPanelLastVisibleModeRaw: defaults.string(forKey: AppSettings.leftPanelLastVisibleModeKey)
                ?? LeftPanelVisibleMode.sidebar.rawValue,
            leftPanelSidebarWidth: defaults.object(forKey: AppSettings.leftPanelSidebarWidthKey) as? Double ?? 240,
            previewPanelWidth: defaults.object(forKey: AppSettings.previewPanelWidthKey) as? Double ?? 320,
            previewSnippetsSplitRatio: defaults.object(forKey: ExplorerAppSettings.previewSnippetsSplitRatioKey) as? Double ?? 0.55,
            isOutputPanelVisible: defaults.object(forKey: ExplorerAppSettings.outputPanelVisibleKey) as? Bool ?? false,
            outputPanelHeight: defaults.object(forKey: ExplorerAppSettings.outputPanelHeightKey) as? Double ?? 200,
            isSnippetsContentCollapsed: defaults.object(forKey: ExplorerAppSettings.snippetsContentCollapsedKey) as? Bool ?? false,
            isOutputPanelContentCollapsed: defaults.object(forKey: ExplorerAppSettings.outputPanelContentCollapsedKey) as? Bool ?? false,
            isPreviewContentCollapsed: defaults.object(forKey: ExplorerAppSettings.previewContentCollapsedKey) as? Bool ?? false
        )
    }

    private func persistBool(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
    }

    private func persistString(_ key: String, _ value: String) {
        defaults.set(value, forKey: key)
    }

    private func persistDouble(_ key: String, _ value: Double) {
        defaults.set(value, forKey: key)
    }
}

@MainActor
final class ActiveWindowLayoutCenter {
    static let shared = ActiveWindowLayoutCenter()

    private let layouts = NSHashTable<ExplorerWindowLayoutState>.weakObjects()
    weak var keyWindowLayout: ExplorerWindowLayoutState?

    private init() {}

    func register(_ layout: ExplorerWindowLayoutState) {
        layouts.add(layout)
    }

    func showOutputPanel(on layout: ExplorerWindowLayoutState) {
        layout.isOutputPanelVisible = true
        layout.isOutputPanelContentCollapsed = false
    }

    func hideOutputPanel(on layout: ExplorerWindowLayoutState) {
        layout.isOutputPanelVisible = false
    }

    func hideOutputPanelOnAllWindows() {
        for layout in layouts.allObjects {
            layout.isOutputPanelVisible = false
        }
    }
}

struct WindowLayoutCommands {
    var showPreview: Bool
    var showSnippets: Bool
    var isOutputPanelVisible: Bool
    var toggleLeftPanel: () -> Void
    var toggleRightPanel: () -> Void
    var togglePreview: () -> Void
    var toggleSnippets: () -> Void
    var toggleOutputPanel: () -> Void
}

struct WindowLayoutCommandsKey: FocusedValueKey {
    typealias Value = WindowLayoutCommands
}

extension FocusedValues {
    var windowLayoutCommands: WindowLayoutCommands? {
        get { self[WindowLayoutCommandsKey.self] }
        set { self[WindowLayoutCommandsKey.self] = newValue }
    }
}

private enum AppSettings {
    static let previewPanelWidthKey = "previewPanelWidth"
    static let leftPanelModeKey = "leftPanelMode"
    static let leftPanelLastVisibleModeKey = "leftPanelLastVisibleMode"
    static let leftPanelSidebarWidthKey = "leftPanelSidebarWidth"
    static let lastOpenedPathKey = "lastOpenedPath"
}

struct WindowKeyLayoutTracker: NSViewRepresentable {
    let layout: ExplorerWindowLayoutState

    func makeNSView(context: Context) -> NSView {
        let view = TrackerView()
        view.layout = layout
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let view = nsView as? TrackerView else { return }
        view.layout = layout
        view.syncKeyWindowRegistration()
    }

    final class TrackerView: NSView {
        var layout: ExplorerWindowLayoutState?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            removeObservers()
            guard let window else { return }
            guard let layout else { return }

            ActiveWindowLayoutCenter.shared.register(layout)
            WindowSnapCoordinator.shared.register(window: window)

            let center = NotificationCenter.default
            observers.append(center.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.registerAsKeyWindow()
            })
            observers.append(center.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.unregisterIfKeyWindow()
            })
            observers.append(center.addObserver(
                forName: NSWindow.didMoveNotification,
                object: window,
                queue: .main
            ) { _ in
                WindowSnapCoordinator.shared.handleWindowDidMove(window)
            })
            observers.append(center.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { _ in
                WindowSnapCoordinator.shared.handleWindowDidResize(window)
            })
            observers.append(center.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                WindowSnapCoordinator.shared.handleWindowWillClose(window)
            })
            observers.append(center.addObserver(
                forName: NSWindow.didMiniaturizeNotification,
                object: window,
                queue: .main
            ) { _ in
                WindowSnapCoordinator.shared.handleWindowDidMiniaturize(window)
            })

            syncKeyWindowRegistration()
        }

        func syncKeyWindowRegistration() {
            if window?.isKeyWindow == true {
                registerAsKeyWindow()
            }
        }

        private func registerAsKeyWindow() {
            guard let layout else { return }
            ActiveWindowLayoutCenter.shared.keyWindowLayout = layout
        }

        private func unregisterIfKeyWindow() {
            guard let layout else { return }
            if ActiveWindowLayoutCenter.shared.keyWindowLayout === layout {
                ActiveWindowLayoutCenter.shared.keyWindowLayout = nil
            }
        }

        private func removeObservers() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
            observers.removeAll()
        }

        deinit {
            removeObservers()
        }
    }
}
