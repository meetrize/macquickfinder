import Foundation

/// 文件复制 / 移动 / 粘贴进度：供底部 banner 展示，并在切换目录时配合取消后台传输。
@MainActor
final class FileTransferCenter: ObservableObject {
    static let shared = FileTransferCenter()

    enum TransferMode: Equatable {
        case paste
        case copy
        case move
    }

    enum Kind: Equatable {
        case creatingFromClipboard
        case transferring(
            mode: TransferMode,
            completed: Int,
            total: Int,
            currentName: String?,
            fraction: Double?
        )
    }

    struct ActiveProgress: Equatable {
        let sessionID: UUID
        let destinationPath: String
        let kind: Kind

        var message: String {
            switch kind {
            case .creatingFromClipboard:
                return L10n.File.pasteCreatingFromClipboard
            case .transferring(let mode, let completed, let total, let name, _):
                switch mode {
                case .paste:
                    if let name, !name.isEmpty {
                        return L10n.File.pasteProgressWithName(completed, total, name)
                    }
                    return L10n.File.pasteProgress(completed, total)
                case .copy:
                    if let name, !name.isEmpty {
                        return L10n.File.transferCopyProgressWithName(completed, total, name)
                    }
                    return L10n.File.transferCopyProgress(completed, total)
                case .move:
                    if let name, !name.isEmpty {
                        return L10n.File.transferMoveProgressWithName(completed, total, name)
                    }
                    return L10n.File.transferMoveProgress(completed, total)
                }
            }
        }

        var showsDeterminateProgress: Bool {
            switch kind {
            case .creatingFromClipboard:
                return false
            case .transferring(_, _, let total, _, let fraction):
                if fraction != nil { return true }
                return total > 1
            }
        }

        var progressFraction: Double? {
            switch kind {
            case .creatingFromClipboard:
                return nil
            case .transferring(_, let completed, let total, _, let fraction):
                if let fraction { return min(max(fraction, 0), 1) }
                guard total > 0 else { return nil }
                return Double(completed) / Double(total)
            }
        }
    }

    /// 浅层体积加权：目录/未知 size 记为 1，避免全树扫描。
    struct WeightPlan: Equatable {
        let weights: [Int64]
        let totalWeight: Int64

        static func make(urls: [URL]) -> WeightPlan {
            var weights: [Int64] = []
            weights.reserveCapacity(urls.count)
            for url in urls {
                let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                if values?.isDirectory == true {
                    weights.append(1)
                } else {
                    weights.append(max(Int64(values?.fileSize ?? 0), 1))
                }
            }
            let total = max(weights.reduce(0, +), 1)
            return WeightPlan(weights: weights, totalWeight: total)
        }

        func fraction(completedCount: Int) -> Double {
            guard !weights.isEmpty else { return 0 }
            let done = weights.prefix(min(completedCount, weights.count)).reduce(Int64(0), +)
            return Double(done) / Double(totalWeight)
        }
    }

    enum RevealPolicy: Equatable {
        /// 超过约 300ms 仍未完成再展示，避免闪一下。
        case deferred
        case immediate
    }

    enum ProgressPolicy {
        private static let deferSizeThreshold: Int64 = 2 * 1024 * 1024
        private static let deferItemLimit = 3

        static func revealPolicy(
            urls: [URL],
            copy: Bool,
            destination: URL
        ) -> RevealPolicy {
            // 同卷 move 多数很快：延迟显示，避免闪一下；若超过阈值仍进行中则会出现进度条。
            // 不再使用 .hidden，否则用户会感觉「完全没有进度」。
            let hasDirectory = urls.contains { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            if hasDirectory {
                return .immediate
            }

            if urls.count > deferItemLimit {
                return .immediate
            }

            let estimated = urls.reduce(Int64(0)) { partial, url in
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
                return partial + max(size, 0)
            }
            if estimated >= deferSizeThreshold {
                return .immediate
            }

            // 小文件 / 同卷小量操作：延迟显示，避免闪一下
            return .deferred
        }
    }

    @Published private(set) var activeProgress: ActiveProgress?

    private var weightPlanBySession: [UUID: WeightPlan] = [:]
    private var lastPublishUptime: TimeInterval = 0
    private var deferredRevealTasks: [UUID: Task<Void, Never>] = [:]

    private init() {}

    func beginCreatingFromClipboard(destination: String) -> UUID {
        cancelDeferredReveals()
        weightPlanBySession.removeAll()
        pendingDeferredSession = nil
        let sessionID = UUID()
        activeProgress = ActiveProgress(
            sessionID: sessionID,
            destinationPath: destination,
            kind: .creatingFromClipboard
        )
        return sessionID
    }

    /// - Parameter deferredReveal: true 时约 300ms 后仍未结束才显示 banner。
    func beginTransfer(
        mode: TransferMode,
        total: Int,
        destination: String,
        weightPlan: WeightPlan,
        deferredReveal: Bool
    ) -> UUID {
        cancelDeferredReveals()
        weightPlanBySession.removeAll()
        pendingDeferredSession = nil
        let sessionID = UUID()
        weightPlanBySession[sessionID] = weightPlan
        let kind = Kind.transferring(
            mode: mode,
            completed: 0,
            total: max(total, 1),
            currentName: nil,
            fraction: weightPlan.fraction(completedCount: 0)
        )

        if deferredReveal {
            deferredRevealTasks[sessionID] = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                guard weightPlanBySession[sessionID] != nil else { return }
                guard activeProgress == nil || activeProgress?.sessionID == sessionID else { return }
                activeProgress = ActiveProgress(
                    sessionID: sessionID,
                    destinationPath: destination,
                    kind: kind
                )
                deferredRevealTasks[sessionID] = nil
            }
            activeProgress = nil
            pendingDeferredSession = PendingDeferred(
                sessionID: sessionID,
                destinationPath: destination,
                kind: kind
            )
        } else {
            activeProgress = ActiveProgress(
                sessionID: sessionID,
                destinationPath: destination,
                kind: kind
            )
        }
        return sessionID
    }

    private struct PendingDeferred {
        let sessionID: UUID
        let destinationPath: String
        let kind: Kind
    }

    private var pendingDeferredSession: PendingDeferred?

    func updateTransfer(
        sessionID: UUID,
        completed: Int,
        total: Int,
        currentName: String?,
        force: Bool = false
    ) {
        let plan = weightPlanBySession[sessionID]
        let fraction = plan?.fraction(completedCount: completed)

        let mode: TransferMode
        if let current = activeProgress, current.sessionID == sessionID,
           case .transferring(let existingMode, _, _, _, _) = current.kind {
            mode = existingMode
        } else if let pending = pendingDeferredSession, pending.sessionID == sessionID,
                  case .transferring(let existingMode, _, _, _, _) = pending.kind {
            mode = existingMode
        } else {
            return
        }

        let kind = Kind.transferring(
            mode: mode,
            completed: completed,
            total: total,
            currentName: currentName,
            fraction: fraction
        )
        let destinationPath = activeProgress?.destinationPath
            ?? pendingDeferredSession?.destinationPath
            ?? ""

        // 延迟展示期间：首次有进度更新则提前显示，避免大文件卡在「无反馈」。
        if activeProgress == nil,
           let pending = pendingDeferredSession,
           pending.sessionID == sessionID {
            deferredRevealTasks[sessionID]?.cancel()
            deferredRevealTasks[sessionID] = nil
            pendingDeferredSession = nil
            activeProgress = ActiveProgress(
                sessionID: sessionID,
                destinationPath: destinationPath,
                kind: kind
            )
            lastPublishUptime = ProcessInfo.processInfo.systemUptime
            return
        }

        guard let current = activeProgress, current.sessionID == sessionID else { return }

        let now = ProcessInfo.processInfo.systemUptime
        if !force, completed < total, now - lastPublishUptime < 0.05 {
            return
        }
        lastPublishUptime = now
        activeProgress = ActiveProgress(
            sessionID: sessionID,
            destinationPath: current.destinationPath,
            kind: kind
        )
    }

    func finish(sessionID: UUID) {
        deferredRevealTasks[sessionID]?.cancel()
        deferredRevealTasks[sessionID] = nil
        weightPlanBySession[sessionID] = nil
        if pendingDeferredSession?.sessionID == sessionID {
            pendingDeferredSession = nil
        }
        guard activeProgress?.sessionID == sessionID else { return }
        activeProgress = nil
    }

    func cancelAll() {
        cancelDeferredReveals()
        weightPlanBySession.removeAll()
        pendingDeferredSession = nil
        activeProgress = nil
    }

    private func cancelDeferredReveals() {
        for (_, task) in deferredRevealTasks {
            task.cancel()
        }
        deferredRevealTasks.removeAll()
    }
}

/// 兼容旧名称。
typealias PasteOperationCenter = FileTransferCenter

enum FileTransferVolume {
    static func isLikelySameVolume(sources: [URL], destination: URL) -> Bool {
        guard let destID = volumeIdentifier(for: destination) else { return false }
        for source in sources {
            guard let sourceID = volumeIdentifier(for: source),
                  sourceID.isEqual(destID) else {
                return false
            }
        }
        return true
    }

    private static func volumeIdentifier(for url: URL) -> (any NSCopying & NSObjectProtocol)? {
        let values = try? url.resourceValues(forKeys: [.volumeIdentifierKey])
        return values?.volumeIdentifier as? (any NSCopying & NSObjectProtocol)
    }
}
