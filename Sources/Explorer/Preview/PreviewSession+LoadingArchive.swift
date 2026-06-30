import Foundation

extension PreviewSession {
    func reloadArchiveListing() async {
        await consumeArchiveEntryStream(replacingExisting: true)
    }

    func consumeArchiveEntryStream(replacingExisting: Bool) async {
        let url = browseTarget.url
        let itemID = browseTarget.id

        archive.listingGeneration &+= 1
        let generation = archive.listingGeneration

        if replacingExisting {
            content.archiveEntries = []
            content.archiveTruncated = false
            archive.expandedDirectoryPaths = []
            archive.selectedEntryPaths = []
        }

        archive.isLoadingMore = true
        defer {
            if generation == archive.listingGeneration {
                archive.isLoadingMore = false
            }
        }

        do {
            for try await event in ArchivePreviewLoader.streamArchiveEntryPaths(at: url) {
                guard !Task.isCancelled, browseTarget.id == itemID else { return }
                guard generation == archive.listingGeneration else { return }

                switch event {
                case .batch(let entries):
                    content.archiveEntries.append(contentsOf: entries)
                    if content.loadPhase == .loading || content.loadPhase == .idle {
                        content.loadPhase = .loaded
                    }
                case .finished(let truncated, let timedOut):
                    content.archiveTruncated = truncated || timedOut
                    content.loadPhase = .loaded
                }
            }
        } catch {
            if error is CancellationError { return }
            guard browseTarget.id == itemID, generation == archive.listingGeneration else { return }
            if content.archiveEntries.isEmpty {
                content.loadPhase = .failed(error.localizedDescription)
            } else {
                content.archiveTruncated = true
                content.loadPhase = .loaded
            }
        }
    }
}
