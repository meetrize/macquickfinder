import AppKit
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
    private var lastMouseLocation: NSPoint?
    /// 拖动中 leader 的估算 frame（鼠标增量更新，setFrame 时与真实 frame 校准）
    private var sessionLeaderFrame: NSRect?
    /// 仅标题栏拖动时为 true，避免普通点击误触发联动
    private var isTitleBarDragActive = false
    /// 无吸附时标题栏拖动的窗口，松手时用于再次检测吸附
    private weak var snapDragCandidate: NSWindow?

    private init() {}

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
            let mayRelease = !isTitleBarDragActive || NSEvent.pressedMouseButtons & 1 == 0
            if mayRelease, shouldReleaseLink(link) {
                releaseActiveLink(attemptResnapWith: leader)
                return
            }
            if isTitleBarDragActive, NSEvent.pressedMouseButtons & 1 != 0 {
                dragLeader = leader
                sessionLeaderFrame = leader.frame
                syncLayoutFromSession(flushDisplay: false)
            } else if NSEvent.pressedMouseButtons & 1 == 0 {
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
            if isTitleBarDragActive {
                dragLeader = window
            }
            return
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

    private func setActiveLink(_ link: WindowSnapLink?) {
        activeLink = link
        if link == nil {
            stopContinuousSync()
            dragLeader = nil
            sessionLeaderFrame = nil
            isTitleBarDragActive = false
            lastMouseLocation = nil
            return
        }
        startContinuousSync()
        lastMouseLocation = nil
        sessionLeaderFrame = nil
    }

    /// 解除吸附；若边缘仍足够近则立即尝试重新吸附
    private func releaseActiveLink(attemptResnapWith window: NSWindow?) {
        setActiveLink(nil)
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

        if let leader {
            sessionLeaderFrame = leader.frame
        }
        syncPartnerToLeader(flushDisplay: true)
        refreshLinkedWindowsChrome(link)
        dragLeader = nil
        lastMouseLocation = nil
        sessionLeaderFrame = nil
        isTitleBarDragActive = false
    }

    private func handleMouseDown() {
        let mouse = NSEvent.mouseLocation
        guard let leader = topmostRegisteredWindow(at: mouse),
              isEligible(leader), isRegistered(leader),
              isMouseInTitleBar(leader, at: mouse) else {
            snapDragCandidate = nil
            if activeLink != nil {
                isTitleBarDragActive = false
                lastMouseLocation = nil
            }
            return
        }

        snapDragCandidate = leader

        guard activeLink != nil else { return }

        isTitleBarDragActive = true
        dragLeader = leader
        sessionLeaderFrame = leader.frame
        lastMouseLocation = mouse
    }

    private func handleMouseUp() {
        if activeLink != nil {
            finalizeDragIfNeeded()
            return
        }
        guard isEnabled, let window = snapDragCandidate else { return }
        snapDragCandidate = nil
        trySnap(moving: window)
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

    /// 用鼠标增量更新 leader 估算位置，再绝对计算另一扇窗位置（顶/左对齐，无累积误差）
    private func continuousSyncTick() {
        guard isEnabled, let link = activeLink else { return }
        guard isTitleBarDragActive else { return }
        guard NSEvent.pressedMouseButtons & 1 != 0 else { return }
        guard let leader = dragLeader ?? link.windowA ?? link.windowB,
              link.otherWindow(than: leader) != nil else { return }

        if sessionLeaderFrame == nil {
            sessionLeaderFrame = leader.frame
        }
        guard var estimatedLeader = sessionLeaderFrame else { return }

        let mouse = NSEvent.mouseLocation
        if let lastMouse = lastMouseLocation {
            let dx = mouse.x - lastMouse.x
            let dy = mouse.y - lastMouse.y
            if hypot(dx, dy) >= Metrics.moveEpsilon {
                estimatedLeader.origin.x += dx
                estimatedLeader.origin.y += dy
                sessionLeaderFrame = estimatedLeader
            }
        }
        lastMouseLocation = mouse

        syncLayoutFromSession(flushDisplay: false)
    }

    /// 根据 session 中 leader 的估算 frame，绝对定位另一扇窗
    private func syncLayoutFromSession(flushDisplay: Bool) {
        guard let link = activeLink,
              let leader = dragLeader ?? link.windowA ?? link.windowB,
              let partner = link.otherWindow(than: leader),
              let leaderFrame = sessionLeaderFrame else { return }

        let target = pixelAligned(
            partnerFrame(
                leaderFrame: leaderFrame,
                partnerSize: partner.frame.size,
                edge: link.edge,
                leaderIsWindowA: link.leaderIsWindowA(leader)
            ),
            scale: partner.backingScaleFactor
        )

        movePartnerWindow(partner, to: target, flushDisplay: flushDisplay)
    }

    private func syncPartnerToLeader(flushDisplay: Bool) {
        guard let link = activeLink,
              let leader = dragLeader ?? link.windowA ?? link.windowB,
              let partner = link.otherWindow(than: leader) else { return }

        sessionLeaderFrame = leader.frame

        let target = pixelAligned(
            partnerFrame(
                leaderFrame: leader.frame,
                partnerSize: partner.frame.size,
                edge: link.edge,
                leaderIsWindowA: link.leaderIsWindowA(leader)
            ),
            scale: partner.backingScaleFactor
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
            for: movingFrame,
            candidate: best.candidate.frame,
            edge: best.edge
        )
        moveWindow(moving, to: snappedFrame, flushDisplay: true)

        setActiveLink(WindowSnapLink(windowA: moving, windowB: best.candidate, edge: best.edge))
        dragLeader = moving
        syncPartnerToLeader(flushDisplay: true)
        if let link = activeLink {
            refreshLinkedWindowsChrome(link)
        }
    }

    private func snappedFrame(for moving: NSRect, candidate: NSRect, edge: WindowSnapEdge) -> NSRect {
        var result = moving
        switch edge {
        case .rightToLeft:
            result.origin.x = candidate.minX - moving.width
            result.origin.y = candidate.maxY - moving.height
        case .leftToRight:
            result.origin.x = candidate.maxX
            result.origin.y = candidate.maxY - moving.height
        case .topToBottom:
            result.origin.x = candidate.minX
            result.origin.y = candidate.minY - moving.height
        case .bottomToTop:
            result.origin.x = candidate.minX
            result.origin.y = candidate.maxY
        }
        return result
    }

    // MARK: - Linked Move Geometry

    private func partnerFrame(
        leaderFrame: NSRect,
        partnerSize: NSSize,
        edge: WindowSnapEdge,
        leaderIsWindowA: Bool
    ) -> NSRect {
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
                origin.y = leaderFrame.minY - partnerSize.height
            } else {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.maxY
            }
        case .bottomToTop:
            if leaderIsWindowA {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.maxY
            } else {
                origin.x = leaderFrame.minX
                origin.y = leaderFrame.minY - partnerSize.height
            }
        }
        return NSRect(origin: origin, size: partnerSize)
    }

    private func movePartnerWindow(_ partner: NSWindow, to frame: NSRect, flushDisplay: Bool) {
        let id = ObjectIdentifier(partner)
        let target = pixelAligned(frame, scale: partner.backingScaleFactor)
        let current = partner.frame
        guard shouldMove(from: current, to: target) else { return }

        programmaticMoveWindows.insert(id)
        defer { programmaticMoveWindows.remove(id) }

        if flushDisplay {
            partner.setFrame(target, display: true)
        } else {
            partner.setFrameOrigin(target.origin)
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
