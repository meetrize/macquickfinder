import Foundation
import SwiftUI

@MainActor
final class FilePropertiesWindowViewModel: ObservableObject {
    enum SaveState: Equatable {
        case idle
        case saving
        case success
        case error(String)
    }

    let items: [FileItem]

    let isMixedTags: Bool
    let isMixedComment: Bool

    @Published var tags: [String]
    @Published var comment: String

    @Published var saveState: SaveState = .idle
    @Published var saveMessage: String = ""

    var displayName: String {
        guard let first = primaryItem else { return "属性" }
        if items.count == 1 { return first.name }
        return "已选中 \(items.count) 项"
    }

    var pathSummary: String {
        guard let first = primaryItem else { return "" }
        if items.count == 1 {
            return first.url.deletingLastPathComponent().path + "/" + first.url.lastPathComponent
        }
        return first.url.deletingLastPathComponent().path
    }

    var primaryItem: FileItem? { items.first }

    private var didEditTags = false
    private var didEditComment = false

    private var commentSaveTask: Task<Void, Never>?

    init(items: [FileItem]) {
        self.items = items
        self.tags = items.first?.tags ?? []
        self.comment = items.first?.finderComment ?? ""

        if let firstTags = items.first?.tags {
            self.isMixedTags = items.contains { $0.tags != firstTags }
        } else {
            self.isMixedTags = false
        }

        let firstComment = items.first?.finderComment ?? ""
        self.isMixedComment = items.contains { $0.finderComment != firstComment } && items.count > 1
    }

    func tagTintColor(for tag: String) -> Color {
        // 由于 Finder tags -> 颜色并未直接暴露，这里用 hash 做 UI 颜色映射。
        let palette: [Color] = [
            .red, .orange, .yellow, .green, .mint, .teal, .blue, .indigo, .purple, .pink
        ]
        let idx = abs(tag.hashValue) % palette.count
        return palette[idx]
    }

    func removeTag(_ tag: String) {
        guard !tag.isEmpty else { return }
        guard let index = tags.firstIndex(of: tag) else { return }
        tags.remove(at: index)
        didEditTags = true
        saveTagsNow()
    }

    func addTag(_ raw: String) {
        let cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        guard !tags.contains(cleaned) else { return }
        tags.append(cleaned)
        didEditTags = true
        saveTagsNow()
    }

    func didChangeCommentFromUser() {
        didEditComment = true
        scheduleCommentSave()
    }

    private func saveTagsNow() {
        guard didEditTags else { return }
        let urls = items.map(\.url)
        let tagsToSave = tags

        saveState = .saving
        saveMessage = "保存中…"

        Task {
            do {
                try await Task.detached(priority: .userInitiated) {
                    for url in urls {
                        try FinderMetadataWriter.setTags(for: url, tags: tagsToSave)
                    }
                }.value

                saveState = .success
                saveMessage = "已保存"
                await invalidateParents()
            } catch {
                saveState = .error(error.localizedDescription)
                saveMessage = "保存失败"
            }
        }
    }

    private func scheduleCommentSave() {
        guard didEditComment else { return }
        let snapshot = comment

        commentSaveTask?.cancel()
        commentSaveTask = Task {
            do {
                try await Task.sleep(nanoseconds: 600_000_000) // 600ms debounce
            } catch {
                // sleep 在取消时抛 CancellationError，这里直接退出即可。
                return
            }
            guard !Task.isCancelled else { return }

            let urls = items.map(\.url)

            saveState = .saving
            saveMessage = "保存中…"

            do {
                try await Task.detached(priority: .userInitiated) {
                    for url in urls {
                        try FinderMetadataWriter.setFinderComment(for: url, comment: snapshot)
                    }
                }.value

                saveState = .success
                saveMessage = "已保存"
                await invalidateParents()
            } catch {
                saveState = .error(error.localizedDescription)
                saveMessage = "保存失败"
            }
        }
    }

    private func invalidateParents() async {
        let dirs = Set(items.map { $0.url.deletingLastPathComponent().path })
        let paths = Array(dirs)
        if paths.isEmpty { return }
        await DirectoryMetadataScheduler.invalidate(paths: paths)
    }
}

