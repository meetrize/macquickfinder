import AppKit

// MARK: - Types

enum WindowSnapEdge: Equatable {
    /// moving 左边贴 candidate 右边
    case leftToRight
    /// moving 右边贴 candidate 左边
    case rightToLeft
    /// moving 上边贴 candidate 下边
    case topToBottom
    /// moving 下边贴 candidate 上边
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
}

private struct SnapCandidate: Comparable {
    var edge: WindowSnapEdge
    var distance: CGFloat
    var candidate: NSWindow

    static func < (lhs: SnapCandidate, rhs: SnapCandidate) -> Bool {
        if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
        // 距离相同时优先左右吸附
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
        static let releaseThreshold: CGFloat = 20
        static let minOverlap: CGFloat = 80
    }

    private let windows = NSHashTable<NSWindow>.weakObjects()
    private var activeLink: WindowSnapLink?
    private var lastFrames: [ObjectIdentifier: NSRect] = [:]
    private var programmaticMoveWindows = Set<ObjectIdentifier>()

    private init() {}

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: ExplorerAppSettings.windowSnapEnabledKey) as? Bool ?? true
    }

    // MARK: - Registration

    func register(window: NSWindow) {
        guard isEligible(window) else { return }
        windows.add(window)
        lastFrames[ObjectIdentifier(window)] = window.frame
    }

    func unregister(window: NSWindow) {
        windows.remove(window)
        lastFrames.removeValue(forKey: ObjectIdentifier(window))
        programmaticMoveWindows.remove(ObjectIdentifier(window))
        if activeLink?.contains(window) == true {
            activeLink = nil
        }
    }

    // MARK: - Event Handlers

    func handleWindowDidMove(_ window: NSWindow) {
        guard isEnabled, isEligible(window) else { return }
        guard !programmaticMoveWindows.contains(ObjectIdentifier(window)) else {
            lastFrames[ObjectIdentifier(window)] = window.frame
            return
        }

        let currentFrame = window.frame
        let windowID = ObjectIdentifier(window)
        let previousFrame = lastFrames[windowID] ?? currentFrame
        let dx = currentFrame.origin.x - previousFrame.origin.x
        let dy = currentFrame.origin.y - previousFrame.origin.y

        if let link = activeLink, link.contains(window) {
            if shouldReleaseLink(link) {
                activeLink = nil
            } else if dx != 0 || dy != 0, let other = link.otherWindow(than: window) {
                moveFollower(other, dx: dx, dy: dy)
            }
        }

        if activeLink == nil {
            trySnap(moving: window)
        }

        lastFrames[windowID] = window.frame
    }

    func handleWindowDidResize(_ window: NSWindow) {
        guard isEnabled else { return }
        lastFrames[ObjectIdentifier(window)] = window.frame
        guard let link = activeLink, link.contains(window) else { return }
        if shouldReleaseLink(link) {
            activeLink = nil
        }
    }

    func handleWindowWillClose(_ window: NSWindow) {
        unregister(window: window)
    }

    func handleWindowDidMiniaturize(_ window: NSWindow) {
        unregister(window: window)
    }

    // MARK: - Eligibility

    private func isEligible(_ window: NSWindow) -> Bool {
        !window.isMiniaturized && !window.styleMask.contains(.fullScreen)
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

        let snappedFrame = snappedFrame(for: movingFrame, candidate: best.candidate.frame, edge: best.edge)
        applyProgrammaticFrame(snappedFrame, to: moving)

        activeLink = WindowSnapLink(windowA: moving, windowB: best.candidate, edge: best.edge)
        lastFrames[ObjectIdentifier(moving)] = moving.frame
    }

    private func snappedFrame(for moving: NSRect, candidate: NSRect, edge: WindowSnapEdge) -> NSRect {
        var result = moving
        switch edge {
        case .rightToLeft:
            result.origin.x = candidate.minX - moving.width
        case .leftToRight:
            result.origin.x = candidate.maxX
        case .topToBottom:
            result.origin.y = candidate.minY - moving.height
        case .bottomToTop:
            result.origin.y = candidate.maxY
        }
        return result
    }

    // MARK: - Linked Move

    private func moveFollower(_ follower: NSWindow, dx: CGFloat, dy: CGFloat) {
        guard dx != 0 || dy != 0 else { return }
        var frame = follower.frame
        frame.origin.x += dx
        frame.origin.y += dy
        applyProgrammaticFrame(frame, to: follower)
    }

    private func applyProgrammaticFrame(_ frame: NSRect, to window: NSWindow) {
        let id = ObjectIdentifier(window)
        programmaticMoveWindows.insert(id)
        window.setFrame(frame, display: true)
        lastFrames[id] = window.frame
        programmaticMoveWindows.remove(id)
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

        if edgeDistance > Metrics.releaseThreshold { return true }
        if !hasSufficientOverlap(frameA, frameB, for: link.edge) { return true }
        return false
    }

    // MARK: - Geometry Helpers

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
