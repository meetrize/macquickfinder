import AppKit
import QuartzCore

// MARK: - NSWindow Frame Hook

/// 在 setFrame / setFrameOrigin 调用栈内同步跟随窗，比 didMove 更早、更连贯
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

    @MainActor
    static func notifyFrameChanged(_ window: NSWindow) {
        if Thread.isMainThread {
            WindowSnapCoordinator.shared.handleFrameChange(window)
        } else {
            DispatchQueue.main.sync {
                WindowSnapCoordinator.shared.handleFrameChange(window)
            }
        }
    }
}

extension NSWindow {
    @objc dynamic func mf_snap_setFrameOrigin(_ point: NSPoint) {
        mf_snap_setFrameOrigin(point)
        NSWindowSnapFrameHook.notifyFrameChanged(self)
    }

    @objc dynamic func mf_snap_setFrame(_ frameRect: NSRect, display flag: Bool) {
        mf_snap_setFrame(frameRect, display: flag)
        NSWindowSnapFrameHook.notifyFrameChanged(self)
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
        static let syncTimerInterval: TimeInterval = 1.0 / 120.0
    }

    private let windows = NSHashTable<NSWindow>.weakObjects()
    private var activeLink: WindowSnapLink?
    private var lastFrames: [ObjectIdentifier: NSRect] = [:]
    private var programmaticMoveWindows = Set<ObjectIdentifier>()
    private var syncTimer: Timer?
    private weak var dragLeader: NSWindow?
    private var mouseUpMonitor: Any?

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
            endLinkedDragSession()
        }
        if activeLink?.contains(window) == true {
            activeLink = nil
        }
    }

    // MARK: - Event Handlers

    /// setFrame 钩子入口：与 leader 移动同一调用栈内同步 partner
    func handleFrameChange(_ window: NSWindow) {
        guard isEnabled, isEligible(window) else { return }
        guard isRegistered(window) else { return }
        guard !programmaticMoveWindows.contains(ObjectIdentifier(window)) else {
            lastFrames[ObjectIdentifier(window)] = window.frame
            return
        }

        processUserMove(on: window)
    }

    /// didMove 兜底（部分系统路径可能绕过 setFrame 钩子）
    func handleWindowDidMove(_ window: NSWindow) {
        handleFrameChange(window)
    }

    func handleWindowDidResize(_ window: NSWindow) {
        guard isEnabled else { return }
        lastFrames[ObjectIdentifier(window)] = window.frame
        guard let link = activeLink, link.contains(window) else { return }
        if shouldReleaseLink(link) {
            endLinkedDragSession()
            activeLink = nil
        }
    }

    func handleWindowWillClose(_ window: NSWindow) {
        unregister(window: window)
    }

    func handleWindowDidMiniaturize(_ window: NSWindow) {
        unregister(window: window)
    }

    func endLinkedDragSession() {
        guard syncTimer != nil || dragLeader != nil else { return }

        syncTimer?.invalidate()
        syncTimer = nil

        if let link = activeLink, let leader = dragLeader ?? link.windowA ?? link.windowB {
            syncLinkedPartner(leader: leader, link: link, flushDisplay: true)
            leader.displayIfNeeded()
            link.otherWindow(than: leader)?.displayIfNeeded()
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
        guard let contentView = window.contentView else { return }
        contentView.wantsLayer = true
        contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        if let layer = contentView.layer {
            layer.drawsAsynchronously = true
            layer.actions = [
                "position": NSNull(),
                "bounds": NSNull(),
                "frame": NSNull(),
            ]
        }
    }

    private func isEligible(_ window: NSWindow) -> Bool {
        !window.isMiniaturized && !window.styleMask.contains(.fullScreen)
    }

    private func isRegistered(_ window: NSWindow) -> Bool {
        windows.allObjects.contains { $0 === window }
    }

    // MARK: - Move Processing

    private func processUserMove(on window: NSWindow) {
        if let link = activeLink, link.contains(window) {
            beginLinkedDragSession(leader: window)
            syncLinkedPartner(leader: window, link: link, flushDisplay: false)
            if shouldReleaseLink(link) {
                endLinkedDragSession()
                activeLink = nil
            }
        } else if activeLink == nil {
            trySnap(moving: window)
        }

        lastFrames[ObjectIdentifier(window)] = window.frame
    }

    private func beginLinkedDragSession(leader: NSWindow) {
        dragLeader = leader
        guard syncTimer == nil else { return }

        let timer = Timer(timeInterval: Metrics.syncTimerInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.linkedDragTimerTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }

    private func linkedDragTimerTick() {
        guard let link = activeLink else {
            endLinkedDragSession()
            return
        }
        guard let leader = dragLeader ?? link.windowA ?? link.windowB, isEligible(leader) else {
            endLinkedDragSession()
            return
        }
        syncLinkedPartner(leader: leader, link: link, flushDisplay: false)
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
        applyProgrammaticFrame(snappedFrame, to: moving, flushDisplay: true)

        activeLink = WindowSnapLink(windowA: moving, windowB: best.candidate, edge: best.edge)
        syncLinkedPartner(leader: moving, link: activeLink!, flushDisplay: true)
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
        return result
    }

    // MARK: - Linked Move

    private func syncLinkedPartner(leader: NSWindow, link: WindowSnapLink, flushDisplay: Bool) {
        guard let partner = link.otherWindow(than: leader) else { return }
        let partnerFrame = partnerFrame(
            leaderFrame: leader.frame,
            partnerSize: partner.frame.size,
            edge: link.edge,
            leaderIsWindowA: link.leaderIsWindowA(leader)
        )
        applyProgrammaticFrame(partnerFrame, to: partner, flushDisplay: flushDisplay)
    }

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

    private func applyProgrammaticFrame(_ frame: NSRect, to window: NSWindow, flushDisplay: Bool) {
        let id = ObjectIdentifier(window)
        let current = window.frame
        guard current != frame else {
            lastFrames[id] = frame
            return
        }

        programmaticMoveWindows.insert(id)
        defer { programmaticMoveWindows.remove(id) }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if current.size == frame.size {
                window.setFrameOrigin(frame.origin)
            } else {
                window.setFrame(frame, display: flushDisplay)
            }
            CATransaction.commit()
        }

        if flushDisplay {
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
