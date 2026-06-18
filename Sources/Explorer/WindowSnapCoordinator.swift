import AppKit
import QuartzCore

// MARK: - NSWindow Frame Hook

/// 在 leader 的 setFrame 生效前先移动 follower，避免 follower 永远慢一帧
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
        let targetFrame = NSRect(origin: point, size: frame.size)
        WindowSnapCoordinator.shared.willMoveLeader(self, to: targetFrame)
        mf_snap_setFrameOrigin(point)
        WindowSnapCoordinator.shared.didMoveLeader(self)
    }

    @objc dynamic func mf_snap_setFrame(_ frameRect: NSRect, display flag: Bool) {
        WindowSnapCoordinator.shared.willMoveLeader(self, to: frameRect)
        mf_snap_setFrame(frameRect, display: flag)
        WindowSnapCoordinator.shared.didMoveLeader(self)
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

// MARK: - Coordinator

@MainActor
final class WindowSnapCoordinator {
    static let shared = WindowSnapCoordinator()

    private enum Metrics {
        static let snapThreshold: CGFloat = 12
        static let releaseThreshold: CGFloat = 56
        static let minOverlap: CGFloat = 80
    }

    private let windows = NSHashTable<NSWindow>.weakObjects()
    private var activeLink: WindowSnapLink?
    private var lastFrames: [ObjectIdentifier: NSRect] = [:]
    private var programmaticMoveWindows = Set<ObjectIdentifier>()
    private weak var dragLeader: NSWindow?
    private var mouseUpMonitor: Any?
    private var isBatchingScreenUpdate = false

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: ExplorerAppSettings.windowSnapEnabledKey) as? Bool ?? true
    }

    // MARK: - Registration

    func register(window: NSWindow) {
        NSWindowSnapFrameHook.installIfNeeded()
        installMouseUpMonitorIfNeeded()
        guard isEligible(window) else { return }
        windows.add(window)
        prepareWindowForLinkedMove(window)
        lastFrames[ObjectIdentifier(window)] = window.frame
    }

    func unregister(window: NSWindow) {
        windows.remove(window)
        lastFrames.removeValue(forKey: ObjectIdentifier(window))
        programmaticMoveWindows.remove(ObjectIdentifier(window))
        if dragLeader === window {
            dragLeader = nil
        }
        if activeLink?.contains(window) == true {
            activeLink = nil
        }
    }

    // MARK: - Frame Hook Entry Points

    /// leader 即将移动：根据目标 frame 先移动 follower，再让 leader 移动
    func willMoveLeader(_ leader: NSWindow, to targetLeaderFrame: NSRect) {
        guard isEnabled, isEligible(leader), isRegistered(leader) else { return }
        guard !isProgrammatic(leader) else { return }

        guard let link = activeLink, link.contains(leader), let partner = link.otherWindow(than: leader) else {
            return
        }

        dragLeader = leader
        let partnerTarget = pixelAligned(partnerFrame(
            leaderFrame: pixelAligned(targetLeaderFrame),
            partnerSize: partner.frame.size,
            edge: link.edge,
            leaderIsWindowA: link.leaderIsWindowA(leader)
        ))

        guard partner.frame != partnerTarget else { return }

        isBatchingScreenUpdate = true
        moveWindow(partner, to: partnerTarget)
        isBatchingScreenUpdate = false
    }

    /// leader 移动完成：更新状态、检测解除吸附或尝试新吸附
    func didMoveLeader(_ window: NSWindow) {
        guard isEnabled, isEligible(window), isRegistered(window) else { return }
        guard !isProgrammatic(window) else {
            lastFrames[ObjectIdentifier(window)] = window.frame
            return
        }

        lastFrames[ObjectIdentifier(window)] = window.frame

        if let link = activeLink, link.contains(window) {
            dragLeader = window
            if shouldReleaseLink(link) {
                activeLink = nil
                dragLeader = nil
            }
            return
        }

        if activeLink == nil {
            trySnap(moving: window)
        }
    }

    /// didMove 兜底：仅处理 hook 未覆盖的路径
    func handleWindowDidMove(_ window: NSWindow) {
        guard isEnabled, isEligible(window), isRegistered(window) else { return }
        guard !isProgrammatic(window) else {
            lastFrames[ObjectIdentifier(window)] = window.frame
            return
        }

        guard let link = activeLink, link.contains(window), let partner = link.otherWindow(than: window) else {
            didMoveLeader(window)
            return
        }

        // hook 已处理常规拖动；此处仅修正漂移
        dragLeader = window
        let expected = pixelAligned(partnerFrame(
            leaderFrame: pixelAligned(window.frame),
            partnerSize: partner.frame.size,
            edge: link.edge,
            leaderIsWindowA: link.leaderIsWindowA(window)
        ))
        if partner.frame != expected {
            moveWindow(partner, to: expected)
        }
        lastFrames[ObjectIdentifier(window)] = window.frame
    }

    func handleWindowDidResize(_ window: NSWindow) {
        guard isEnabled else { return }
        lastFrames[ObjectIdentifier(window)] = window.frame
        guard let link = activeLink, link.contains(window) else { return }
        if shouldReleaseLink(link) {
            activeLink = nil
            dragLeader = nil
        }
    }

    func handleWindowWillClose(_ window: NSWindow) {
        unregister(window: window)
    }

    func handleWindowDidMiniaturize(_ window: NSWindow) {
        unregister(window: window)
    }

    func endLinkedDragSession() {
        guard dragLeader != nil else { return }

        if let link = activeLink, let leader = dragLeader ?? link.windowA ?? link.windowB {
            if let partner = link.otherWindow(than: leader) {
                let expected = pixelAligned(partnerFrame(
                    leaderFrame: pixelAligned(leader.frame),
                    partnerSize: partner.frame.size,
                    edge: link.edge,
                    leaderIsWindowA: link.leaderIsWindowA(leader)
                ))
                moveWindow(partner, to: expected, flushDisplay: true)
                leader.displayIfNeeded()
                partner.displayIfNeeded()
            }
        }
        dragLeader = nil
    }

    // MARK: - Private Setup

    private func installMouseUpMonitorIfNeeded() {
        guard mouseUpMonitor == nil else { return }
        mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { event in
            WindowSnapCoordinator.shared.endLinkedDragSession()
            return event
        }
    }

    private func prepareWindowForLinkedMove(_ window: NSWindow) {
        window.disableSnapshotRestoration()
        window.animationBehavior = .none
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

    private func pixelAligned(_ rect: NSRect) -> NSRect {
        var result = rect
        result.origin.x = round(result.origin.x)
        result.origin.y = round(result.origin.y)
        result.size.width = round(result.size.width)
        result.size.height = round(result.size.height)
        return result
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

        activeLink = WindowSnapLink(windowA: moving, windowB: best.candidate, edge: best.edge)
        dragLeader = moving

        if let link = activeLink {
            let partnerFrame = pixelAligned(partnerFrame(
                leaderFrame: pixelAligned(moving.frame),
                partnerSize: best.candidate.frame.size,
                edge: link.edge,
                leaderIsWindowA: true
            ))
            moveWindow(best.candidate, to: partnerFrame, flushDisplay: true)
        }

        lastFrames[ObjectIdentifier(moving)] = moving.frame
        lastFrames[ObjectIdentifier(best.candidate)] = best.candidate.frame
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
        return pixelAligned(result)
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

    private func moveWindow(_ window: NSWindow, to frame: NSRect, flushDisplay: Bool = false) {
        let id = ObjectIdentifier(window)
        let target = pixelAligned(frame)
        let current = window.frame
        guard current != target else {
            lastFrames[id] = target
            return
        }

        programmaticMoveWindows.insert(id)
        defer { programmaticMoveWindows.remove(id) }

        // 拖动中批量更新时不立即刷新，减少跟随窗跳动感
        let shouldDisplay = flushDisplay && !isBatchingScreenUpdate

        if current.size == target.size {
            window.setFrameOrigin(target.origin)
        } else {
            window.setFrame(target, display: shouldDisplay)
        }

        if shouldDisplay {
            window.displayIfNeeded()
        }
        lastFrames[id] = window.frame
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
