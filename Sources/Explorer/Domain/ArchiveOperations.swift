import AppKit
import FileList
import Foundation

enum ArchiveOperationsError: LocalizedError {
    case cancelled
    case commandFailed(exitCode: Int32)
    case shellOutput(String)
    case encryptedArchive
    case unsupportedArchive

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        case .commandFailed:
            return L10n.Archive.errorUnsupported
        case .shellOutput(let output):
            let lower = output.lowercased()
            if lower.contains("password") || lower.contains("encrypted") {
                return L10n.Archive.errorEncrypted
            }
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return L10n.Archive.errorUnsupported
            }
            return trimmed
        case .encryptedArchive:
            return L10n.Archive.errorEncrypted
        case .unsupportedArchive:
            return L10n.Archive.errorUnsupported
        }
    }
}

enum ArchiveOperations {
    static func isArchive(_ item: FileItem) -> Bool {
        isArchiveFileName(item.name)
    }

    static func isArchiveFileName(_ fileName: String) -> Bool {
        ArchivePreviewLoader.isArchiveFileName(fileName.lowercased())
    }

    static func canCompress(_ items: [FileItem], inTrash: Bool) -> Bool {
        guard !inTrash else { return false }
        let files = selectableItems(from: items)
        guard !files.isEmpty else { return false }
        return !files.allSatisfy(isArchive)
    }

    static func canExtract(_ items: [FileItem], inTrash: Bool) -> Bool {
        guard !inTrash else { return false }
        let files = selectableItems(from: items)
        guard !files.isEmpty else { return false }
        return files.allSatisfy(isArchive)
    }

    static func defaultArchiveFileName(for items: [FileItem]) -> String {
        let files = selectableItems(from: items)
        if files.count == 1, let item = files.first {
            return "\(item.name).zip"
        }
        return "Archive.zip"
    }

    static func archiveStemName(for archiveURL: URL) -> String {
        let name = archiveURL.lastPathComponent
        let lower = name.lowercased()
        if lower.hasSuffix(".tar.gz") {
            return String(name.dropLast(7))
        }
        if lower.hasSuffix(".tgz") {
            return String(name.dropLast(4))
        }
        return (name as NSString).deletingPathExtension
    }

    static func uniqueNamedPath(name: String, in directory: URL) -> URL {
        let fileManager = FileManager.default
        var candidate = directory.appendingPathComponent(name)
        if !fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }

        let baseName = (name as NSString).deletingPathExtension
        let pathExtension = (name as NSString).pathExtension
        var counter = 1
        while fileManager.fileExists(atPath: candidate.path) {
            let newName: String
            if pathExtension.isEmpty {
                newName = "\(baseName) \(counter)"
            } else {
                newName = "\(baseName) \(counter).\(pathExtension)"
            }
            candidate = directory.appendingPathComponent(newName)
            counter += 1
        }
        return candidate
    }

    static func uniqueExtractDirectory(for archiveURL: URL, in parentDirectory: URL) -> URL {
        let stem = archiveStemName(for: archiveURL)
        return uniqueNamedPath(name: stem, in: parentDirectory)
    }

    static func uniqueArchiveDestination(for items: [FileItem], in directory: URL) -> URL {
        let fileName = defaultArchiveFileName(for: items)
        return uniqueNamedPath(name: fileName, in: directory)
    }

    @MainActor
    static func compress(
        items: [FileItem],
        in directory: URL,
        onComplete: @escaping (Result<URL, Error>) -> Void
    ) {
        let files = selectableItems(from: items)
        guard !files.isEmpty else { return }

        let destination = uniqueArchiveDestination(for: files, in: directory)
        let itemURLs = files.map(\.url)
        let command = ArchiveCommandBuilder.makeCompressCommand(
            itemURLs: itemURLs,
            destinationZip: destination,
            sourceDirectory: directory
        )
        let displayCommand = compressDisplayCommand(itemCount: files.count, destination: destination)
        let estimatedBytes = estimatedByteCount(for: files)
        let volumePaths = volumePaths(for: files, baseDirectory: directory)
        let containsDirectory = files.contains(where: \.isDirectory)

        ArchiveTaskRunner.run(
            displayCommand: displayCommand,
            shellCommand: command,
            workingDirectory: directory.path,
            jobTitle: L10n.Archive.jobCompress,
            estimatedBytes: estimatedBytes,
            volumePaths: volumePaths,
            containsDirectory: containsDirectory
        ) { result in
            switch result {
            case .success:
                ArchiveOperationNotifications.postCompleted(resultPaths: [destination.path])
                onComplete(.success(destination))
            case .failure(let error):
                if case ArchiveOperationsError.cancelled = error {
                    onComplete(.failure(error))
                    return
                }
                presentFailure(error)
                onComplete(.failure(error))
            }
        }
    }

    @MainActor
    static func extract(
        archives: [FileItem],
        mode: ArchiveExtractMode,
        members: [String]? = nil,
        navigateIntoResult: Bool = false,
        onComplete: @escaping (Result<[URL], Error>) -> Void
    ) {
        let files = selectableItems(from: archives).filter(isArchive)
        guard !files.isEmpty else { return }
        if let members {
            guard files.count == 1, !members.isEmpty else { return }
        }

        let destinations = files.map { item in
            uniqueExtractDirectory(
                for: item.url,
                in: baseDirectory(for: item, mode: mode)
            )
        }
        let displayCommand = extractDisplayCommand(
            archives: files,
            destinations: destinations,
            memberCount: members?.count
        )
        let estimatedBytes = files.reduce(Int64(0)) { $0 + max(0, $1.size) }
        let volumePaths = files.map(\.url.path) + destinations.map(\.path)
        let workingDirectory = files[0].url.deletingLastPathComponent().path
        let archiveLabel = files.count == 1 ? files[0].name : L10n.Archive.jobExtract

        performExtract(
            displayCommand: displayCommand,
            jobTitle: L10n.Archive.jobExtract,
            estimatedBytes: estimatedBytes,
            volumePaths: volumePaths,
            workingDirectory: workingDirectory,
            archiveLabel: archiveLabel,
            makeCommand: { password in
                zip(files.map(\.url), destinations)
                    .map { archive, destination in
                        ArchiveCommandBuilder.makeExtractCommand(
                            archive: archive,
                            destinationDirectory: destination,
                            members: members,
                            password: password
                        )
                    }
                    .joined(separator: " && ")
            },
            resultURLs: destinations,
            navigateIntoResult: navigateIntoResult,
            onComplete: onComplete
        )
    }

    @MainActor
    static func extractPartial(
        archive: FileItem,
        memberPaths: [String],
        mode: ArchiveExtractMode,
        navigateIntoResult: Bool = false,
        onComplete: @escaping (Result<[URL], Error>) -> Void
    ) {
        extract(
            archives: [archive],
            mode: mode,
            members: memberPaths,
            navigateIntoResult: navigateIntoResult,
            onComplete: onComplete
        )
    }

    static func isPasswordProtectedError(_ error: Error) -> Bool {
        if case ArchiveOperationsError.encryptedArchive = error { return true }
        if case ArchiveOperationsError.shellOutput(let output) = error {
            let lower = output.lowercased()
            return lower.contains("password")
                || lower.contains("encrypted")
                || lower.contains("bad password")
                || lower.contains("wrong password")
                || lower.contains("incorrect password")
        }
        return false
    }

    @MainActor
    static func extractToPanel(
        archives: [FileItem],
        onComplete: @escaping (Result<[URL], Error>) -> Void
    ) {
        guard let destination = ArchiveExtractPanel.pickDestinationDirectory() else { return }
        extract(archives: archives, mode: .destination(destination), onComplete: onComplete)
    }

    // MARK: - Private

    private static func selectableItems(from items: [FileItem]) -> [FileItem] {
        items.filter { !$0.isParentDirectoryEntry }
    }

    private static func baseDirectory(for item: FileItem, mode: ArchiveExtractMode) -> URL {
        switch mode {
        case .here:
            return item.url.deletingLastPathComponent()
        case .destination(let url):
            return url.standardizedFileURL
        case .downloads:
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            return downloads?.standardizedFileURL ?? item.url.deletingLastPathComponent()
        }
    }

    private static func estimatedByteCount(for items: [FileItem]) -> Int64 {
        items.reduce(Int64(0)) { partial, item in
            partial + max(0, item.size)
        }
    }

    private static func volumePaths(for items: [FileItem], baseDirectory: URL) -> [String] {
        var paths = items.map(\.url.path)
        paths.append(baseDirectory.path)
        return paths
    }

    private static func compressDisplayCommand(itemCount: Int, destination: URL) -> String {
        if itemCount == 1 {
            return L10n.Archive.statusCompressingItem(destination.lastPathComponent)
        }
        return L10n.Archive.statusCompressingCount(itemCount)
    }

    private static func extractDisplayCommand(
        archives: [FileItem],
        destinations: [URL],
        memberCount: Int? = nil
    ) -> String {
        if let memberCount, memberCount > 0, let archive = archives.first, let destination = destinations.first {
            return L10n.Archive.statusExtractingPartial(memberCount, archive.name, destination.lastPathComponent)
        }
        if archives.count == 1, let archive = archives.first, let destination = destinations.first {
            return L10n.Archive.statusExtractingItem(archive.name, destination.lastPathComponent)
        }
        return L10n.Archive.statusExtractingCount(archives.count)
    }

    @MainActor
    private static func performExtract(
        displayCommand: String,
        jobTitle: String,
        estimatedBytes: Int64,
        volumePaths: [String],
        workingDirectory: String?,
        archiveLabel: String,
        makeCommand: @escaping (String?) -> String,
        resultURLs: [URL],
        navigateIntoResult: Bool,
        onComplete: @escaping (Result<[URL], Error>) -> Void
    ) {
        func attempt(password: String?) {
            let command = makeCommand(password)
            ArchiveTaskRunner.run(
                displayCommand: displayCommand,
                shellCommand: command,
                workingDirectory: workingDirectory,
                jobTitle: jobTitle,
                estimatedBytes: estimatedBytes,
                volumePaths: volumePaths,
                containsDirectory: false
            ) { result in
                switch result {
                case .success:
                    let paths = resultURLs.map(\.path)
                    ArchiveOperationNotifications.postCompleted(
                        resultPaths: paths,
                        navigateIntoResult: navigateIntoResult
                    )
                    onComplete(.success(resultURLs))
                case .failure(let error):
                    if case ArchiveOperationsError.cancelled = error {
                        onComplete(.failure(error))
                        return
                    }
                    if isPasswordProtectedError(error) {
                        guard let password = ArchivePasswordPanel.prompt(archiveName: archiveLabel),
                              !password.isEmpty else {
                            onComplete(.failure(ArchiveOperationsError.cancelled))
                            return
                        }
                        attempt(password: password)
                        return
                    }
                    presentFailure(error)
                    onComplete(.failure(error))
                }
            }
        }
        attempt(password: nil)
    }

    @MainActor
    private static func presentFailure(_ error: Error) {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            NSAlert(messageText: description).runModal()
        } else {
            NSAlert(error: error).runModal()
        }
    }
}

private extension NSAlert {
    convenience init(messageText: String) {
        self.init()
        self.messageText = messageText
        self.alertStyle = .warning
        addButton(withTitle: L10n.Action.ok)
    }
}
