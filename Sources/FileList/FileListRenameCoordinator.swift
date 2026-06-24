import AppKit
import Foundation

/// 列表与缩略图共用的重命名状态机（二次点击改名、选中时间戳）。
final class FileListRenameCoordinator {
    var renamingRowID: String?
    private(set) var rowRenameEligibleSince: [String: Date] = [:]
    private var lastKnownSelectionIDs: Set<String> = []

    var isRenaming: Bool { renamingRowID != nil }

    enum CommitDecision {
        case cancel
        case commit(String)
    }

    static func evaluateCommit(newName: String, originalName: String) -> CommitDecision {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == originalName {
            return .cancel
        }
        return .commit(trimmed)
    }

    func cancelForDataUpdate(onEditingChanged: (Bool) -> Void) {
        guard renamingRowID != nil else { return }
        renamingRowID = nil
        onEditingChanged(false)
    }

    func isSecondClickEligible(itemID: String) -> Bool {
        guard let selectedAt = rowRenameEligibleSince[itemID] else { return false }
        return Date().timeIntervalSince(selectedAt) > NSEvent.doubleClickInterval
    }

    func recordSelectionTimestamps(currentIDs: Set<String>) {
        let now = Date()
        for id in currentIDs.subtracting(lastKnownSelectionIDs) {
            rowRenameEligibleSince[id] = now
        }
        for id in lastKnownSelectionIDs.subtracting(currentIDs) {
            rowRenameEligibleSince.removeValue(forKey: id)
        }
        lastKnownSelectionIDs = currentIDs
    }

    func shouldBeginRenameOnMouseUp(
        isSoleSelection: Bool,
        isNameClickPoint: Bool,
        canRename: Bool,
        isParentDirectory: Bool,
        itemID: String
    ) -> Bool {
        guard !isRenaming else { return false }
        guard !isParentDirectory else { return false }
        guard isSoleSelection, isNameClickPoint, canRename else { return false }
        return isSecondClickEligible(itemID: itemID)
    }

    func armEligibleAfterClickIfNeeded(
        wasAlreadySelectedAtMouseDown: Bool,
        event: NSEvent,
        hasPendingRename: Bool,
        isSoleSelection: Bool,
        isNameClickPoint: Bool,
        canRename: Bool,
        isParentDirectory: Bool,
        itemID: String
    ) {
        guard renamingRowID == nil, !hasPendingRename else { return }
        guard wasAlreadySelectedAtMouseDown else { return }
        guard event.clickCount == 1 else { return }
        let flags = event.modifierFlags
        guard !flags.contains(.command), !flags.contains(.shift) else { return }
        guard isSoleSelection, isNameClickPoint, !isParentDirectory, canRename else { return }
        rowRenameEligibleSince[itemID] = Date()
    }
}
