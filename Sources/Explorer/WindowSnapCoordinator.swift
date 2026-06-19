import AppKit
import FileList
import QuartzCore

// MARK: - NSWindow Frame Hook

enum NSWindowSnapFrameHook {
    private static var isInstalled = false

    static func installIfNeeded() {
        guard !isInstalled else { return }
        isInstalled = true

        swizzle(
            NSWindow.self,
            original: #selector(NSWindow.setFrameOrigin(_:)),
            swizzled: #selector(NSWindow.mf_snap_setFrameOrigin(_:))
        )
        swizzle(
            NSWindow.self,
            original: #selector(NSWindow.setFrame(_:display:)),
            swizzled: #selector(NSWindow.mf_snap_setFrame(_:display:))
        )
    }

    private static func swizzle(_ cls: AnyClass, original: Selector, swizzled: Selector) {
        guard let originalMethod = class_getInstanceMethod(cls, original),
              let swizzledMethod = class_getInstanceMethod(cls, swizzled) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

extension NSWindow {
    @objc dynamic func mf_snap_setFrameOrigin(_ point: NSPoint) {
        mf_snap_setFrameOrigin(point)
        WindowSnapCoordinator.shared.leaderFrameUpdated(self)
    }

    @objc dynamic func mf_snap_setFrame(_ frameRect: NSRect, display flag: Bool) {
        mf_snap_setFrame(frameRect, display: flag)
        WindowSnapCoordinator.shared.leaderFrameUpdated(self)
    }
}

// MARK: - Types

enum WindowSnapEdge: Equatable {
    case leftToRight
    case rightToLeft
    case topToBottom
    case bottomToTop

    var isHorizontal: Bool {
        switch self {
        case .leftToRight, .rightToLeft: return true
        case .topToBottom, .bottomToTop: return false
        }
    }
}

struct WindowSnapLink: Equatable {
    weak var windowA: NSWindow?
    weak var windowB: NSWindow?
    var edge: WindowSnapEdge

    static func == (lhs: WindowSnapLink, rhs: WindowSnapLink) -> Bool {
        lhs.windowA === rhs.windowA
            && lhs.windowB === rhs.windowB
            && lhs.edge == rhs.edge
    }

    func contains(_ window: NSWindow) -> Bool {
        windowA === window || windowB === window
    }

    func otherWindow(than window: NSWindow) -> NSWindow? {
        if windowA === window { return windowB }
        if windowB === window { return windowA }
        return nil
    }

    func leaderIsWindowA(_ leader: NSWindow) -> Bool {
        windowA === leader
    }
}

private struct SnapCandidate: Comparable {
    var edge: WindowSnapEdge
    var distance: CGFloat
    var candidate: NSWindow

    static func < (lhs: SnapCandidate, rhs: SnapCandidate) -> Bool {
        if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
        if lhs.edge.isHorizontal != rhs.edge.isHorizontal {
            return lhs.edge.isHorizontal
        }
        return false
    }
}

// MARK: - RunLoop Sync

/// 标题栏拖动时主线程 RunLoop 处于 eventTracking 模式，必须用 .common / .eventTracking 才能持续回调
private final class DragRunLoopSync {
    private var timer: Timer?

    func start(tick: @escaping () -> Void) {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { _ in
            tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        RunLoop.main.add(timer, forMode: .eventTracking)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Coordinator

@MainActor
final class WindowSnapCoordinator {
    static let shared = WindowSnapCoordinator()

    private enum Metrics {
        static let snapThreshold: CGFloat = 12
        static let releaseThreshold: CGFloat = 56
        static let minOverlap: CGFloat = 80
        static let moveEpsilon: CGFloat = 0.25
    }

    private let windows = NSHashTable<NSWindow>.weakObjects()
    private var activeLink: WindowSnapLink?
    private var programmaticMoveWindows = Set<ObjectIdentifier>()
    private weak var dragLeader: NSWindow?
    private var mouseEventMonitor: Any?
    private let dragRunLoopSync = DragRunLoopSync()
    private var isContinuousSyncActive = false
    /// 仅标题栏拖动时为 true，避免普通点击误触发联动
    private var isTitleBarDragActive = false
    /// 无吸附时标题栏拖动的窗口，松手时用于再次检测吸附
    private weak var snapDragCandidate: NSWindow?
    /// 从标题栏按下开始的窗口拖动（含首次吸附前）
    private var isSnapTitleBarDragSession = false
    /// 文件列表内容区交互（拖文件、框选）嵌套计数
    private var contentInteractionDepth = 0
    private var contentInteractionObservers: [NSObjectProtocol] = []

    private init() {
        installContentInteractionObservers()
    }

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: ExplorerAppSettings.windowSnapEnabledKey) as? Bool ?? true
    }

    // MARK: - Registration

    func register(window: NSWindow) {
        NSWindowSnapFrameHook.installIfNeeded()
        installMouseEventMonitorIfNeeded()
        guard isEligible(window) else { return }
        windows.add(window)
        prepareWindowForLinkedMove(window)
    }

    func unregister(window: NSWindow) {
        windows.remove(window)
        programmaticMoveWindows.remove(ObjectIdentifier(window))
        if dragLeader === window {
            dragLeader = nil
        }
        if snapDragCandidate === window {
            snapDragCandidate = nil
        }
        if activeLink?.contains(window) == true {
            setActiveLink(nil)
        }
    }

    /// 最小化时仅暂停吸附，保留注册；恢复后无需重新注册即可再次吸附
    private func suspendWindowForMiniaturize(_ window: NSWindow) {
        programmaticMoveWindows.remove(ObjectIdentifier(window))
        if dragLeader === window {
            dragLeader = nil
        }
        if snapDragCandidate === window {
            snapDragCandidate = nil
        }
        if activeLink?.contains(window) == true {
            setActiveLink(nil)
        }
    }

    // MARK: - Event Handlers

    func leaderFrameUpdated(_ leader: NSWindow) {
        guard isEnabled, isEligible(leader), isRegistered(leader) else { return }
        guard !isProgrammatic(leader) else { return }

        if let link = activeLink, link.contains(leader) {
            // 拖动过程中只联动，解除吸附留给松手时处理
            if NSEvent.pressedMouseButtons & 1 != 0 {
                guard shouldPerformLinkedWindowSync() else { return }
                dragLeader = leader
                syncPartnerToLeader(flushDisplay: false)
            }
            return
        }

        if activeLink == nil {
            trySnap(moving: leader)
        }
    }

    func handleWindowDidMove(_ window: NSWindow) {
        guard isEnabled, isEligible(window), isRegistered(window) else { return }
        guard !isProgrammatic(window) else { return }

        if activeLink?.contains(window) == true {
            if isWindowTitleBarDragSession {
                dragLeader = window
            }
            return
        }

        // 窗口被拖动时兜底：不依赖标题栏命中检测也能触发吸附
        if activeLink == nil,
           contentInteractionDepth == 0,
           NSEvent.pressedMouseButtons & 1 != 0 {
            snapDragCandidate = window
            if !isSnapTitleBarDragSession {
                isSnapTitleBarDragSession = true
                startContinuousSync()
            }
        }

        leaderFrameUpdated(window)
    }

    func handleWindowDidResize(_ window: NSWindow) {
        guard isEnabled else { return }
        guard let link = activeLink, link.contains(window) else { return }
        if shouldReleaseLink(link) {
            releaseActiveLink(attemptResnapWith: window)
        }
    }

    func handleWindowWillClose(_ window: NSWindow) {
        unregister(window: window)
    }

    func handleWindowDidMiniaturize(_ window: NSWindow) {
        suspendWindowForMiniaturize(window)
    }

    func handleWindowDidDeminiaturize(_ window: NSWindow) {
        register(window: window)
    }

    // MARK: - Active Link Lifecycle

    private func setActiveLink(_ link: WindowSnapLink?, preserveTitleBarSession: Bool = false) {
        activeLink = link
        if link == nil {
            stopContinuousSync()
            dragLeader = nil
            isTitleBarDragActive = false
            if !preserveTitleBarSession {
                isSnapTitleBarDragSession = false
                snapDragCandidate = nil
            }
            return
        }
    }

    /// 解除吸附；若边缘仍足够近则立即尝试重新吸附
    private func releaseActiveLink(attemptResnapWith window: NSWindow?) {
        let preserveSession = isSnapTitleBarDragSession
            && NSEvent.pressedMouseButtons & 1 != 0
        setActiveLink(nil, preserveTitleBarSession: preserveSession)
        if let window {
            trySnap(moving: window)
        }
    }

    private func finalizeDragIfNeeded() {
        guard let link = activeLink else { return }

        let leader = dragLeader ?? link.windowA ?? link.windowB
        if shouldReleaseLink(link) {
            releaseActiveLink(attemptResnapWith: leader)
            return
        }

        syncPartnerToLeader(flushDisplay: true, ignoreContentInteraction: true)
        refreshLinkedWindowsChrome(link)
        dragLeader = nil
        isTitleBarDragActive = false
    }

    private func handleMouseDown() {
        let mouse = NSEvent.mouseLocation
        guard let leader = topmostRegisteredWindow(at: mouse),
              isEligible(leader), isRegistered(leader),
              isMouseInTitleBar(leader, at: mouse) else {
            snapDragCandidate = nil
            isSnapTitleBarDragSession = false
            if activeLink != nil {
                isTitleBarDragActive = false
                dragLeader = nil
                stopContinuousSync()
            }
            return
        }

        snapDragCandidate = leader
        isSnapTitleBarDragSession = true
        startContinuousSync()

        guard activeLink != nil else { return }

        isTitleBarDragActive = true
        dragLeader = leader
    }

    private func handleMouseUp() {
        if activeLink != nil {
            if isWindowTitleBarDragSession {
                finalizeDragIfNeeded()
            }
        } else if isEnabled, let window = snapDragCandidate {
            trySnap(moving: window)
        }
        snapDragCandidate = nil
        isSnapTitleBarDragSession = false
        isTitleBarDragActive = false
        stopContinuousSync()
    }

    // MARK: - Continuous Sync

    private func startContinuousSync() {
        guard !isContinuousSyncActive else { return }
        isContinuousSyncActive = true
        dragRunLoopSync.start { [weak self] in
            self?.continuousSyncTick()
        }
    }

    private func stopContinuousSync() {
        dragRunLoopSync.stop()
        isContinuousSyncActive = false
    }

    /// 拖动期间以 leader 真实 frame 绝对计算 partner 位置（顶/左对齐，吸附边零重叠）
    private func continuousSyncTick() {
        guard isEnabled else { return }

        if activeLink == nil {
            guard isSnapTitleBarDragSession,
                  NSEvent.pressedMouseButtons & 1 != 0,
                  let window = snapDragCandidate else { return }
            trySnap(moving: window)
            return
        }

        guard shouldPerformLinkedWindowSync() else { return }
        guard NSEvent.pressedMouseButtons & 1 != 0 else { return }
        syncPartnerToLeader(flushDisplay: false)
    }

    private func syncPartnerToLeader(flushDisplay: Bool, ignoreContentInteraction: Bool = false) {
        if !ignoreContentInteraction {
            guard shouldPerformLinkedWindowSync() else { return }
        }
        guard let link = activeLink,
              let leader = dragLeader ?? link.windowA ?? link.windowB,
              let partner = link.otherWindow(than: leader) else { return }

        let target = linkedPartnerFrame(
            leader: leader,
            partner: partner,
            edge: link.edge,
            leaderIsWindowA: link.leaderIsWindowA(leader)
        )

        movePartnerWindow(partner, to: target, flushDisplay: flushDisplay)
    }

    private func topmostRegisteredWindow(at mouse: NSPoint) -> NSWindow? {
        windows.allObjects
            .filter { isEligible($0) && $0.frame.contains(mouse) }
            .max(by: { $0.orderedIndex < $1.orderedIndex })
    }

    /// 判断点击是否落在标题栏/工具栏区域（contentLayoutRect 之上）
    private func isMouseInTitleBar(_ window: NSWindow, at mouse: NSPoint) -> Bool {
        guard window.frame.contains(mouse) else { return false }
        return mouse.y > window.contentLayoutRect.maxY
    }

    // MARK: - Private Setup

    private func installMouseEventMonitorIfNeeded() {
        guard mouseEventMonitor == nil else { return }
        mouseEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp]) { event in
            switch event.type {
            case .leftMouseDown:
                WindowSnapCoordinator.shared.handleMouseDown()
            case .leftMouseUp:
                WindowSnapCoordinator.shared.handleMouseUp()
            default:
                break
            }
            return event
        }
    }

    private func installContentInteractionObservers() {
        guard contentInteractionObservers.isEmpty else { return }
        let center = NotificationCenter.default
        contentInteractionObservers.append(center.addObserver(
            forName: .mf_contentPointerInteractionDidBegin,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WindowSnapCoordinator.shared.noteContentPointerInteractionBegan()
            }
        })
        contentInteractionObservers.append(center.addObserver(
            forName: .mf_contentPointerInteractionDidEnd,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                WindowSnapCoordinator.shared.noteContentPointerInteractionEnded()
            }
        })
    }

    func noteContentPointerInteractionBegan() {
        contentInteractionDepth += 1
        isTitleBarDragActive = false
        isSnapTitleBarDragSession = false
        snapDragCandidate = nil
        dragLeader = nil
        stopContinuousSync()
    }

    func noteContentPointerInteractionEnded() {
        contentInteractionDepth = max(0, contentInteractionDepth - 1)
    }

    private var isWindowTitleBarDragSession: Bool {
        isTitleBarDragActive || isSnapTitleBarDragSession
    }

    private func shouldPerformLinkedWindowSync() -> Bool {
        guard activeLink != nil, isWindowTitleBarDragSession else { return false }
        if contentInteractionDepth > 0 { return false }
        return true
    }

    private func prepareWindowForLinkedMove(_ window: NSWindow) {
        window.animationBehavior = .none
    }

    private func refreshWindowChrome(_ window: NSWindow) {
        window.hasShadow = true
        window.invalidateShadow()
        window.displayIfNeeded()
    }

    private func refreshLinkedWindowsChrome(_ link: WindowSnapLink) {
        if let windowA = link.windowA { refreshWindowChrome(windowA) }
        if let windowB = link.windowB { refreshWindowChrome(windowB) }
    }

    private func isEligible(_ window: NSWindow) -> Bool {
        !window.isMiniaturized && !window.styleMask.contains(.fullScreen)
    }

    private func isRegistered(_ window: NSWindow) -> Bool {
        windows.allObjects.contains { $0 === window }
    }

    private func isProgrammatic(_ window: NSWindow) -> Bool {
        programmaticMoveWindows.contains(ObjectIdentifier(window))
    }

    private func pixelAligned(_ rect: NSRect, scale: CGFloat) -> NSRect {
        guard scale > 0 else { return rect }
        var result = rect
        result.origin.x = round(result.origin.x * scale) / scale
        result.origin.y = round(result.origin.y * scale) / scale
        result.size.width = round(result.size.width * scale) / scale
        result.size.height = round(result.size.height * scale) / scale
        return result
    }

    private func pixelAlignedSize(_ size: NSSize, scale: CGFloat) -> NSSize {
        guard scale > 0 else { return size }
        return NSSize(
            width: round(size.width * scale) / scale,
            height: round(size.height * scale) / scale
        )
    }

    private func shouldMove(from current: NSRect, to target: NSRect) -> Bool {
        abs(current.origin.x - target.origin.x) >= Metrics.moveEpsilon
            || abs(current.origin.y - target.origin.y) >= Metrics.moveEpsilon
            || abs(current.size.width - target.size.width) >= Metrics.moveEpsilon
            || abs(current.size.height - target.size.height) >= Metrics.moveEpsilon
    }

    // MARK: - Snap Detection

    private func trySnap(moving: NSWindow) {
        let movingFrame = moving.frame
        var best: SnapCandidate?

        for candidate in windows.allObjects where candidate !== moving && isEligible(candidate) {
            let candidateFrame = candidate.frame
            let candidates: [(WindowSnapEdge, CGFloat)] = [
                (.rightToLeft, abs(movingFrame.maxX - candidateFrame.minX)),
                (.leftToRight, abs(movingFrame.minX - candidateFrame.maxX)),
                (.topToBottom, abs(movingFrame.maxY - candidateFrame.minY)),
                (.bottomToTop, abs(movingFrame.minY - candidateFrame.maxY)),
            ]

            for (edge, distance) in candidates where distance <= Metrics.snapThreshold {
                guard hasSufficientOverlap(movingFrame, candidateFrame, for: edge) else { continue }
                let snap = SnapCandidate(edge: edge, distance: distance, candidate: candidate)
                if let current = best {
                    if snap < current { best = snap }
                } else {
                    best = snap
                }
            }
        }

        guard let best else { return }

        let snappedFrame = snappedFrame(
            for: moving.frame.size,
            movingScale: moving.backingScaleFactor,
            candidate: best.candidate.frame,
            candidateScale: best.candidate.backingScaleFactor,
            edge: best.edge
        )
        moveWindow(moving, to: snappedFrame, flushDisplay: true)

        setActiveLink(WindowSnapLink(windowA: moving, windowB: best.candidate, edge: best.edge))
        dragLeader = moving
        if isSnapTitleBarDragSession {
            isTitleBarDragActive = true
            startContinuousSync()
        }
        syncPartnerToLeader(flushDisplay: true, ignoreContentInteraction: true)
        if let link = activeLink {
            refreshLinkedWindowsChrome(link)
        }
    }

    private func snappedFrame(
        for movingSize: NSSize,
        movingScale: CGFloat,
        candidate candidateFrame: NSRect,
        candidateScale: CGFloat,
        edge: WindowSnapEdge
    ) -> NSRect {
        let candidate = pixelAligned(candidateFrame, scale: candidateScale)
        let size = pixelAlignedSize(movingSize, scale: movingScale)
        var origin = CGPoint.zero
        switch edge {
        case .rightToLeft:
            origin.x = candidate.minX - size.width
            origin.y = candidate.maxY - size.height
        case .leftToRight:
            origin.x = candidate.maxX
            origin.y = candidate.maxY - size.height
        case .topToBottom:
            origin.x = candidate.minX
            origin.y = candidate.minY - size.height
        case .bottomToTop:
            origin.x = candidate.minX
            origin.y = candidate.maxY
        }
        return NSRect(origin: origin, size: size)
    }

    // MARK: - Linked Move Geometry

    /// 由 leader 精确推导 partner frame：吸附边贴齐（零重叠），垂直吸附左对齐、水平吸附顶对齐
    private func linkedPartnerFrame(
        leader: NSWindow,
        partner: NSWindow,
        edge: WindowSnapEdge,
        leaderIsWindowA: Bool
    ) -> NSRect {
        let leaderFrame = pixelAligned(leader.frame, scale: leader.backingScaleFactor)
        let partnerSize = pixelAlignedSize(partner.frame.size, scale: partner.backingScaleFactor)
        var origin = CGPoint.zero
        switch edge {
        case .rightToLeft:
            if leaderIsWindowA {
                origin.x = leaderFrame.maxX
                origin.y = leaderFrame.maxY - partnerSize.height
            } else {
                origin.x = leaderFrame.minX - partnerSize.width
                origin.y = leaderFrame.maxY - partnerSize.height
            }
        case .leftToRight:
            if leaderIsWindowA {
                origin.x = leaderFrame.minX - partnerSize.width
                origin.y = leaderFrame.maxY - partnerSize.height
            } else {
                origin.x = leaderFrame.maxX
                origin.y = leaderFrame.maxY - partnerSize.height
            }
        case .topToBottom:
            if leaderIsWindowA {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.maxY
            } else {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.minY - partnerSize.height
            }
        case .bottomToTop:
            if leaderIsWindowA {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.minY - partnerSize.height
            } else {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.maxY
            }
        }
        return NSRect(origin: origin, size: partnerSize)
    }

    private func movePartnerWindow(_ partner: NSWindow, to frame: NSRect, flushDisplay: Bool) {
        let id = ObjectIdentifier(partner)
        let current = partner.frame
        guard shouldMove(from: current, to: frame) else { return }

        programmaticMoveWindows.insert(id)
        defer { programmaticMoveWindows.remove(id) }

        if current.size == frame.size {
            partner.setFrameOrigin(frame.origin)
        } else {
            partner.setFrame(frame, display: flushDisplay)
        }
    }

    private func moveWindow(_ window: NSWindow, to frame: NSRect, flushDisplay: Bool) {
        let id = ObjectIdentifier(window)
        let target = pixelAligned(frame, scale: window.backingScaleFactor)
        let current = window.frame
        guard shouldMove(from: current, to: target) else { return }

        programmaticMoveWindows.insert(id)
        defer { programmaticMoveWindows.remove(id) }

        if current.size == target.size {
            window.setFrameOrigin(target.origin)
        } else {
            window.setFrame(target, display: flushDisplay)
        }

        if flushDisplay {
            window.displayIfNeeded()
        }
    }

    // MARK: - Release Detection

    private func shouldReleaseLink(_ link: WindowSnapLink) -> Bool {
        guard let a = link.windowA, let b = link.windowB else { return true }
        guard isEligible(a), isEligible(b) else { return true }

        let frameA = a.frame
        let frameB = b.frame
        let edgeDistance: CGFloat
        switch link.edge {
        case .rightToLeft:
            edgeDistance = abs(frameA.maxX - frameB.minX)
        case .leftToRight:
            edgeDistance = abs(frameA.minX - frameB.maxX)
        case .topToBottom:
            edgeDistance = abs(frameA.maxY - frameB.minY)
        case .bottomToTop:
            edgeDistance = abs(frameA.minY - frameB.maxY)
        }
        return edgeDistance > Metrics.releaseThreshold
    }

    private func hasSufficientOverlap(_ a: NSRect, _ b: NSRect, for edge: WindowSnapEdge) -> Bool {
        if edge.isHorizontal {
            let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
            return overlap >= Metrics.minOverlap
        } else {
            let overlap = min(a.maxX, b.maxX) - max(a.minX, b.minX)
            return overlap >= Metrics.minOverlap
        }
    }
}
