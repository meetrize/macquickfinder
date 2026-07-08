import Foundation

/// 粘贴操作进度：供状态栏 overlay 展示，并在切换目录时配合取消后台粘贴。
@MainActor
final class PasteOperationCenter: ObservableObject {
    static let shared = PasteOperationCenter()

    enum Kind: Equatable {
        case creatingFromClipboard
        case copyingFiles(completed: Int, total: Int, currentName: String?)
    }

    struct ActiveProgress: Equatable {
        let sessionID: UUID
        let destinationPath: String
        let kind: Kind

        var message: String {
            switch kind {
            case .creatingFromClipboard:
                return L10n.File.pasteCreatingFromClipboard
            case .copyingFiles(let completed, let total, let name):
                if let name, !name.isEmpty {
                    return L10n.File.pasteProgressWithName(completed, total, name)
                }
                return L10n.File.pasteProgress(completed, total)
            }
        }

        var showsDeterminateProgress: Bool {
            if case .copyingFiles(_, let total, _) = kind {
                return total > 1
            }
            return false
        }

        var progressFraction: Double? {
            guard case .copyingFiles(let completed, let total, _) = kind, total > 0 else { return nil }
            return Double(completed) / Double(total)
        }
    }

    @Published private(set) var activeProgress: ActiveProgress?

    private init() {}

    func beginCreatingFromClipboard(destination: String) -> UUID {
        let sessionID = UUID()
        activeProgress = ActiveProgress(
            sessionID: sessionID,
            destinationPath: destination,
            kind: .creatingFromClipboard
        )
        return sessionID
    }

    func beginFilePaste(total: Int, destination: String) -> UUID {
        let sessionID = UUID()
        activeProgress = ActiveProgress(
            sessionID: sessionID,
            destinationPath: destination,
            kind: .copyingFiles(completed: 0, total: max(total, 1), currentName: nil)
        )
        return sessionID
    }

    func updateFilePaste(sessionID: UUID, completed: Int, total: Int, currentName: String?) {
        guard let current = activeProgress, current.sessionID == sessionID else { return }
        activeProgress = ActiveProgress(
            sessionID: sessionID,
            destinationPath: current.destinationPath,
            kind: .copyingFiles(completed: completed, total: total, currentName: currentName)
        )
    }

    func finish(sessionID: UUID) {
        guard activeProgress?.sessionID == sessionID else { return }
        activeProgress = nil
    }

    func cancelAll() {
        activeProgress = nil
    }
}
