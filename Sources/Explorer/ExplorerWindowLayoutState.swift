import AppKit
import Combine
import FileList
import SwiftUI

/// 单窗口 UI 布局状态：运行期各窗口互不影响，写入 UserDefaults 时以最后一次操作为准。
/// 右侧面板显示模式：pinned 固定显示；auto 无选中时自动隐藏，有选中恢复上次显隐组合。
enum RightPanelMode: String, CaseIterable, Identifiable {
    case pinned
    case auto

    var id: String { rawValue }
}

extension Notification.Name {
    /// 设置页 / 工具栏切换右侧面板自动隐藏后广播，打开的窗口立刻同步。
    static let rightPanelModeDidChange = Notification.Name("rightPanelModeDidChange")
}

@MainActor
final class ExplorerWindowLayoutState: ObservableObject {
    @Published var showPreview: Bool {
        didSet { UserDefaultsStorage.set(showPreview, forKey: AppPreferences.Layout.showPreview, in: defaults) }
    }

    @Published var showSnippets: Bool {
        didSet { UserDefaultsStorage.set(showSnippets, forKey: AppPreferences.Layout.showSnippets, in: defaults) }
    }

    @Published var showGit: Bool {
        didSet { UserDefaultsStorage.set(showGit, forKey: AppPreferences.Layout.showGit, in: defaults) }
    }

    /// 期望显隐（持久化的用户偏好）；生效状态见 `effectiveRightPanelVisibility(hasSelection:)`。
    @Published var rightPanelModeRaw: String {
        didSet {
            guard !isApplyingExternalRightPanelMode else { return }
            UserDefaultsStorage.set(rightPanelModeRaw, forKey: AppPreferences.Layout.rightPanelMode, in: defaults)
        }
    }

    @Published private(set) var leftPanelModeRaw: String {
        didSet { UserDefaultsStorage.set(leftPanelModeRaw, forKey: AppPreferences.Layout.leftPanelMode, in: defaults) }
    }

    @Published private(set) var leftPanelLastVisibleModeRaw: String {
        didSet {
            UserDefaultsStorage.set(
                leftPanelLastVisibleModeRaw,
                forKey: AppPreferences.Layout.leftPanelLastVisibleMode,
                in: defaults
            )
        }
    }

    @Published private(set) var leftPanelSidebarWidth: Double {
        didSet {
            UserDefaultsStorage.set(
                leftPanelSidebarWidth,
                forKey: AppPreferences.Layout.leftPanelSidebarWidth,
                in: defaults
            )
        }
    }

    @Published var previewPanelWidth: Double {
        didSet { UserDefaultsStorage.set(previewPanelWidth, forKey: AppPreferences.Layout.previewPanelWidth, in: defaults) }
    }

    @Published var previewSnippetsSplitRatio: Double {
        didSet {
            UserDefaultsStorage.set(
                previewSnippetsSplitRatio,
                forKey: AppPreferences.Layout.previewSnippetsSplitRatio,
                in: defaults
            )
        }
    }

    @Published var gitPanelHeight: Double {
        didSet { UserDefaultsStorage.set(gitPanelHeight, forKey: AppPreferences.Layout.gitPanelHeight, in: defaults) }
    }

    @Published var isOutputPanelVisible: Bool {
        didSet { UserDefaultsStorage.set(isOutputPanelVisible, forKey: AppPreferences.Panels.outputVisible, in: defaults) }
    }

    @Published var outputPanelHeight: Double {
        didSet { UserDefaultsStorage.set(outputPanelHeight, forKey: AppPreferences.Panels.outputHeight, in: defaults) }
    }

    @Published var isSnippetsContentCollapsed: Bool {
        didSet {
            UserDefaultsStorage.set(
                isSnippetsContentCollapsed,
                forKey: AppPreferences.Panels.snippetsContentCollapsed,
                in: defaults
            )
        }
    }

    @Published var isOutputPanelContentCollapsed: Bool {
        didSet {
            UserDefaultsStorage.set(
                isOutputPanelContentCollapsed,
                forKey: AppPreferences.Panels.outputContentCollapsed,
                in: defaults
            )
        }
    }

    @Published var isPreviewContentCollapsed: Bool {
        didSet {
            UserDefaultsStorage.set(
                isPreviewContentCollapsed,
                forKey: AppPreferences.Panels.previewContentCollapsed,
                in: defaults
            )
        }
    }

    @Published var isGitContentCollapsed: Bool {
        didSet {
            UserDefaultsStorage.set(
                isGitContentCollapsed,
                forKey: AppPreferences.Panels.gitContentCollapsed,
                in: defaults
            )
        }
    }

    @Published private(set) var fileListViewModeRaw: String {
        didSet { UserDefaultsStorage.set(fileListViewModeRaw, forKey: AppPreferences.FileList.viewMode, in: defaults) }
    }

    @Published var thumbnailCellSize: Double {
        didSet { UserDefaultsStorage.set(thumbnailCellSize, forKey: AppPreferences.FileList.thumbnailCellSize, in: defaults) }
    }

    @Published var isDualPaneEnabled: Bool {
        didSet {
            // 持久化放到下一拍，避免开关双栏时与首帧布局抢主线程。
            let value = isDualPaneEnabled
            let defaults = self.defaults
            DispatchQueue.main.async {
                UserDefaultsStorage.set(value, forKey: AppPreferences.Layout.dualPaneEnabled, in: defaults)
            }
        }
    }

    /// 左栏宽度占比 0…1。
    @Published var dualPaneSplitRatio: Double {
        didSet {
            UserDefaultsStorage.set(
                dualPaneSplitRatio,
                forKey: AppPreferences.Layout.dualPaneSplitRatio,
                in: defaults
            )
        }
    }

    @Published var dualPaneSecondaryPath: String {
        didSet {
            UserDefaultsStorage.set(
                dualPaneSecondaryPath,
                forKey: AppPreferences.Layout.dualPaneSecondaryPath,
                in: defaults
            )
        }
    }

    private let defaults: UserDefaults
    private let leftPanelConstants = LeftPanelLayoutConstants()
    private var cancellables = Set<AnyCancellable>()
    /// 从 UserDefaults / 其它窗同步模式时跳过回写，避免通知环。
    private var isApplyingExternalRightPanelMode = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // 崩溃恢复必须在读视图模式之前执行。
        ExplorerSessionRecovery.prepareLaunchIfNeeded(defaults: defaults)
        let stored = Self.loadSnapshot(from: defaults)
        showPreview = stored.showPreview
        showSnippets = stored.showSnippets
        showGit = stored.showGit
        rightPanelModeRaw = stored.rightPanelModeRaw
        leftPanelModeRaw = stored.leftPanelModeRaw
        leftPanelLastVisibleModeRaw = stored.leftPanelLastVisibleModeRaw
        leftPanelSidebarWidth = stored.leftPanelSidebarWidth
        previewPanelWidth = stored.previewPanelWidth
        previewSnippetsSplitRatio = stored.previewSnippetsSplitRatio
        gitPanelHeight = stored.gitPanelHeight
        isOutputPanelVisible = stored.isOutputPanelVisible
        outputPanelHeight = stored.outputPanelHeight
        isSnippetsContentCollapsed = stored.isSnippetsContentCollapsed
        isOutputPanelContentCollapsed = stored.isOutputPanelContentCollapsed
        isPreviewContentCollapsed = stored.isPreviewContentCollapsed
        isGitContentCollapsed = stored.isGitContentCollapsed
        fileListViewModeRaw = stored.fileListViewModeRaw
        thumbnailCellSize = stored.thumbnailCellSize
        isDualPaneEnabled = stored.isDualPaneEnabled
        dualPaneSplitRatio = stored.dualPaneSplitRatio
        dualPaneSecondaryPath = stored.dualPaneSecondaryPath
        observeRightPanelModeDefaultsChanges()
    }

    /// 设置页 / 其它窗口改了 `rightPanel.mode` 后，当前窗口立刻跟上。
    private func observeRightPanelModeDefaultsChanges() {
        NotificationCenter.default.publisher(for: .rightPanelModeDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncRightPanelModeFromDefaultsIfNeeded()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: defaults)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.syncRightPanelModeFromDefaultsIfNeeded()
            }
            .store(in: &cancellables)

        // `UserDefaults.standard` 的变更通知 object 有时为 nil，再听一份兜底。
        if defaults === UserDefaults.standard {
            NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification, object: nil)
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.syncRightPanelModeFromDefaultsIfNeeded()
                }
                .store(in: &cancellables)
        }
    }

    func syncRightPanelModeFromDefaultsIfNeeded() {
        let stored = UserDefaultsStorage.string(
            forKey: AppPreferences.Layout.rightPanelMode,
            default: RightPanelMode.auto.rawValue,
            in: defaults
        )
        guard rightPanelModeRaw != stored else { return }
        isApplyingExternalRightPanelMode = true
        rightPanelModeRaw = stored
        isApplyingExternalRightPanelMode = false
    }

    func toggleDualPaneEnabled() {
        isDualPaneEnabled.toggle()
    }

    func equalizeDualPaneSplit() {
        dualPaneSplitRatio = 0.5
    }

    var fileListViewMode: FileListViewMode {
        FileListViewMode(rawValue: fileListViewModeRaw) ?? .list
    }

    func setFileListViewMode(_ mode: FileListViewMode) {
        fileListViewModeRaw = mode.rawValue
    }

    var thumbnailCellSizeValue: CGFloat {
        get { CGFloat(thumbnailCellSize) }
        set { thumbnailCellSize = Double(newValue) }
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

    var rightPanelMode: RightPanelMode {
        RightPanelMode(rawValue: rightPanelModeRaw) ?? .auto
    }

    func setRightPanelMode(_ mode: RightPanelMode) {
        let previous = rightPanelModeRaw
        rightPanelModeRaw = mode.rawValue
        guard previous != mode.rawValue else { return }
        NotificationCenter.default.post(name: .rightPanelModeDidChange, object: nil)
    }

    /// 工具栏菜单：勾选 = 自动隐藏；取消勾选 = 一直显示。
    func toggleRightPanelAutoHide() {
        setRightPanelMode(rightPanelMode == .auto ? .pinned : .auto)
    }

    /// 生效的右侧显隐：pinned 直接透传期望值；auto 无选中时全部隐藏，有选中恢复期望组合。
    func effectiveRightPanelVisibility(hasSelection: Bool) -> (showPreview: Bool, showSnippets: Bool, showGit: Bool) {
        guard rightPanelMode == .pinned || hasSelection else {
            return (false, false, false)
        }
        return (showPreview, showSnippets, showGit)
    }

    func isRightPanelEffectivelyVisible(hasSelection: Bool) -> Bool {
        let effective = effectiveRightPanelVisibility(hasSelection: hasSelection)
        return effective.showPreview || effective.showSnippets || effective.showGit
    }

    var isRightPanelVisible: Bool {
        showPreview || showSnippets || showGit
    }

    func toggleRightPanel() {
        if isRightPanelVisible {
            showPreview = false
            showSnippets = false
            showGit = false
        } else {
            showPreview = true
            showSnippets = true
        }
    }

    /// auto 且无选中时只改期望值（选中后生效），调用方可用返回值决定是否 toast 提示。
    /// - Returns: 面板是否实际可见变化（false 表示仅记住了偏好）。
    @discardableResult
    func setPreviewVisible(_ visible: Bool, hasSelection: Bool) -> Bool {
        showPreview = visible
        return rightPanelMode == .pinned || hasSelection
    }

    @discardableResult
    func setSnippetsVisible(_ visible: Bool, hasSelection: Bool) -> Bool {
        showSnippets = visible
        return rightPanelMode == .pinned || hasSelection
    }

    func toggleGitPanel() {
        showGit.toggle()
    }

    var gitPanelHeightValue: CGFloat {
        CGFloat(gitPanelHeight)
    }

    func setGitPanelHeight(_ height: CGFloat) {
        gitPanelHeight = Double(height)
    }

    func toggleOutputPanel() {
        if isOutputPanelVisible {
            isOutputPanelVisible = false
        } else {
            ActiveWindowLayoutCenter.shared.showOutputPanel(on: self)
        }
    }

    func recordLastOpenedPath(_ path: String) {
        let standardized = (path as NSString).standardizingPath
        UserDefaultsStorage.set(standardized, forKey: AppPreferences.Layout.lastOpenedPath, in: defaults)
    }

    static func restoredLastOpenedPath(defaults: UserDefaults = .standard) -> String {
        let trimmed = UserDefaultsStorage.string(
            forKey: AppPreferences.Layout.lastOpenedPath,
            default: "",
            in: defaults
        ).trimmingCharacters(in: .whitespacesAndNewlines)
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
        var showGit: Bool
        var rightPanelModeRaw: String
        var leftPanelModeRaw: String
        var leftPanelLastVisibleModeRaw: String
        var leftPanelSidebarWidth: Double
        var previewPanelWidth: Double
        var previewSnippetsSplitRatio: Double
        var gitPanelHeight: Double
        var isOutputPanelVisible: Bool
        var outputPanelHeight: Double
        var isSnippetsContentCollapsed: Bool
        var isOutputPanelContentCollapsed: Bool
        var isPreviewContentCollapsed: Bool
        var isGitContentCollapsed: Bool
        var fileListViewModeRaw: String
        var thumbnailCellSize: Double
        var isDualPaneEnabled: Bool
        var dualPaneSplitRatio: Double
        var dualPaneSecondaryPath: String
    }

    private static func loadSnapshot(from defaults: UserDefaults) -> Snapshot {
        Snapshot(
            showPreview: UserDefaultsStorage.bool(forKey: AppPreferences.Layout.showPreview, default: true, in: defaults),
            showSnippets: UserDefaultsStorage.bool(forKey: AppPreferences.Layout.showSnippets, default: true, in: defaults),
            showGit: UserDefaultsStorage.bool(forKey: AppPreferences.Layout.showGit, default: false, in: defaults),
            rightPanelModeRaw: UserDefaultsStorage.string(
                forKey: AppPreferences.Layout.rightPanelMode,
                default: RightPanelMode.auto.rawValue,
                in: defaults
            ),
            leftPanelModeRaw: UserDefaultsStorage.string(
                forKey: AppPreferences.Layout.leftPanelMode,
                default: LeftPanelMode.sidebar.rawValue,
                in: defaults
            ),
            leftPanelLastVisibleModeRaw: UserDefaultsStorage.string(
                forKey: AppPreferences.Layout.leftPanelLastVisibleMode,
                default: LeftPanelVisibleMode.sidebar.rawValue,
                in: defaults
            ),
            leftPanelSidebarWidth: UserDefaultsStorage.double(
                forKey: AppPreferences.Layout.leftPanelSidebarWidth,
                default: 240,
                in: defaults
            ),
            previewPanelWidth: UserDefaultsStorage.double(
                forKey: AppPreferences.Layout.previewPanelWidth,
                default: 320,
                in: defaults
            ),
            previewSnippetsSplitRatio: UserDefaultsStorage.double(
                forKey: AppPreferences.Layout.previewSnippetsSplitRatio,
                default: 0.55,
                in: defaults
            ),
            gitPanelHeight: UserDefaultsStorage.double(
                forKey: AppPreferences.Layout.gitPanelHeight,
                default: Double(GitPanelMetrics.defaultHeight),
                in: defaults
            ),
            isOutputPanelVisible: UserDefaultsStorage.bool(
                forKey: AppPreferences.Panels.outputVisible,
                default: false,
                in: defaults
            ),
            outputPanelHeight: UserDefaultsStorage.double(
                forKey: AppPreferences.Panels.outputHeight,
                default: 200,
                in: defaults
            ),
            isSnippetsContentCollapsed: UserDefaultsStorage.bool(
                forKey: AppPreferences.Panels.snippetsContentCollapsed,
                default: false,
                in: defaults
            ),
            isOutputPanelContentCollapsed: UserDefaultsStorage.bool(
                forKey: AppPreferences.Panels.outputContentCollapsed,
                default: false,
                in: defaults
            ),
            isPreviewContentCollapsed: UserDefaultsStorage.bool(
                forKey: AppPreferences.Panels.previewContentCollapsed,
                default: false,
                in: defaults
            ),
            isGitContentCollapsed: UserDefaultsStorage.bool(
                forKey: AppPreferences.Panels.gitContentCollapsed,
                default: false,
                in: defaults
            ),
            fileListViewModeRaw: UserDefaultsStorage.string(
                forKey: AppPreferences.FileList.viewMode,
                default: FileListViewMode.list.rawValue,
                in: defaults
            ),
            thumbnailCellSize: UserDefaultsStorage.double(
                forKey: AppPreferences.FileList.thumbnailCellSize,
                default: Double(FileListThumbnailMetrics.defaultCellSize),
                in: defaults
            ),
            isDualPaneEnabled: UserDefaultsStorage.bool(
                forKey: AppPreferences.Layout.dualPaneEnabled,
                default: false,
                in: defaults
            ),
            dualPaneSplitRatio: {
                let raw = UserDefaultsStorage.double(
                    forKey: AppPreferences.Layout.dualPaneSplitRatio,
                    default: 0.5,
                    in: defaults
                )
                return min(max(raw, 0.2), 0.8)
            }(),
            dualPaneSecondaryPath: UserDefaultsStorage.string(
                forKey: AppPreferences.Layout.dualPaneSecondaryPath,
                default: "",
                in: defaults
            )
        )
    }
}

@MainActor
final class ActiveWindowLayoutCenter: ObservableObject {
    static let shared = ActiveWindowLayoutCenter()

    private let layouts = NSHashTable<ExplorerWindowLayoutState>.weakObjects()
    private var keyLayoutObservation: AnyCancellable?

    weak var keyWindowLayout: ExplorerWindowLayoutState? {
        didSet {
            guard keyWindowLayout !== oldValue else { return }
            keyLayoutObservation?.cancel()
            keyLayoutObservation = keyWindowLayout?.objectWillChange
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
            objectWillChange.send()
        }
    }

    private init() {}

    func register(_ layout: ExplorerWindowLayoutState) {
        layouts.add(layout)
    }

    /// 解析应展开输出面板的窗口 layout：优先显式传入，其次 key 窗口，最后任一已注册窗口。
    func resolveLayoutForOutputPanel(preferred: ExplorerWindowLayoutState? = nil) -> ExplorerWindowLayoutState? {
        if let preferred { return preferred }
        if let keyWindowLayout { return keyWindowLayout }
        return layouts.allObjects.first
    }

    func showOutputPanel(on layout: ExplorerWindowLayoutState) {
        layout.isOutputPanelVisible = true
        layout.isOutputPanelContentCollapsed = false
        JobStore.shared.ensureShellSessionIfNeeded()
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
    var showGit: Bool
    var isOutputPanelVisible: Bool
    var toggleLeftPanel: () -> Void
    var toggleRightPanel: () -> Void
    var togglePreview: () -> Void
    var toggleSnippets: () -> Void
    var toggleGit: () -> Void
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
                MainActor.assumeIsolated {
                    self?.registerAsKeyWindow()
                    WindowSnapCoordinator.shared.handleWindowDidBecomeKey(window)
                }
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
                MainActor.assumeIsolated {
                    WindowSnapCoordinator.shared.handleWindowDidMove(window)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.didResizeNotification,
                object: window,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    WindowSnapCoordinator.shared.handleWindowDidResize(window)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    WindowSnapCoordinator.shared.handleWindowWillClose(window)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.didMiniaturizeNotification,
                object: window,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    WindowSnapCoordinator.shared.handleWindowDidMiniaturize(window)
                }
            })
            observers.append(center.addObserver(
                forName: NSWindow.didDeminiaturizeNotification,
                object: window,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    WindowSnapCoordinator.shared.handleWindowDidDeminiaturize(window)
                }
            })

            syncKeyWindowRegistration()
        }

        func syncKeyWindowRegistration() {
            guard let window, window.isKeyWindow else { return }
            registerAsKeyWindow()
            WindowSnapCoordinator.shared.handleWindowDidBecomeKey(window)
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
