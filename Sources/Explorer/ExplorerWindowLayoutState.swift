import AppKit
import Combine
import FileList
import SwiftUI

/// 单窗口 UI 布局状态：运行期各窗口互不影响，写入 UserDefaults 时以最后一次操作为准。
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

    @Published private(set) var thumbnailLayoutModeRaw: String {
        didSet {
            UserDefaultsStorage.set(
                thumbnailLayoutModeRaw,
                forKey: AppPreferences.FileList.thumbnailLayoutMode,
                in: defaults
            )
        }
    }

    @Published private(set) var panoramaExpandDepthPolicyRaw: String {
        didSet {
            UserDefaultsStorage.set(
                panoramaExpandDepthPolicyRaw,
                forKey: AppPreferences.Panorama.expandDepthPolicy,
                in: defaults
            )
        }
    }

    @Published var thumbnailCellSize: Double {
        didSet { UserDefaultsStorage.set(thumbnailCellSize, forKey: AppPreferences.FileList.thumbnailCellSize, in: defaults) }
    }

    private let defaults: UserDefaults
    private let leftPanelConstants = LeftPanelLayoutConstants()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.loadSnapshot(from: defaults)
        showPreview = stored.showPreview
        showSnippets = stored.showSnippets
        showGit = stored.showGit
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
        thumbnailLayoutModeRaw = stored.thumbnailLayoutModeRaw
        panoramaExpandDepthPolicyRaw = stored.panoramaExpandDepthPolicyRaw
        thumbnailCellSize = stored.thumbnailCellSize
    }

    var fileListViewMode: FileListViewMode {
        FileListViewMode(rawValue: fileListViewModeRaw) ?? .list
    }

    func setFileListViewMode(_ mode: FileListViewMode) {
        fileListViewModeRaw = mode.rawValue
    }

    var thumbnailLayoutMode: FileListThumbnailLayoutMode {
        FileListThumbnailLayoutMode(rawValue: thumbnailLayoutModeRaw) ?? .grid
    }

    func setThumbnailLayoutMode(_ mode: FileListThumbnailLayoutMode) {
        thumbnailLayoutModeRaw = mode.rawValue
    }

    var panoramaExpandDepthPolicy: PanoramaExpandDepthPolicy {
        PanoramaExpandDepthPolicy(rawValue: panoramaExpandDepthPolicyRaw) ?? .automatic
    }

    func setPanoramaExpandDepthPolicy(_ policy: PanoramaExpandDepthPolicy) {
        panoramaExpandDepthPolicyRaw = policy.rawValue
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
        var thumbnailLayoutModeRaw: String
        var panoramaExpandDepthPolicyRaw: String
        var thumbnailCellSize: Double
    }

    private static func loadSnapshot(from defaults: UserDefaults) -> Snapshot {
        Snapshot(
            showPreview: UserDefaultsStorage.bool(forKey: AppPreferences.Layout.showPreview, default: true, in: defaults),
            showSnippets: UserDefaultsStorage.bool(forKey: AppPreferences.Layout.showSnippets, default: true, in: defaults),
            showGit: UserDefaultsStorage.bool(forKey: AppPreferences.Layout.showGit, default: false, in: defaults),
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
            thumbnailLayoutModeRaw: UserDefaultsStorage.string(
                forKey: AppPreferences.FileList.thumbnailLayoutMode,
                default: FileListThumbnailLayoutMode.grid.rawValue,
                in: defaults
            ),
            panoramaExpandDepthPolicyRaw: UserDefaultsStorage.string(
                forKey: AppPreferences.Panorama.expandDepthPolicy,
                default: PanoramaExpandDepthPolicy.automatic.rawValue,
                in: defaults
            ),
            thumbnailCellSize: UserDefaultsStorage.double(
                forKey: AppPreferences.FileList.thumbnailCellSize,
                default: Double(FileListThumbnailMetrics.defaultCellSize),
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
