import Foundation

enum ArchiveCommandBuilder {
    /// 单选：`ditto -c -k --keepParent`（与 Finder 一致）。
    /// 多选：`ditto -c` 仅支持单一 src，改用同目录下 `zip -r` 打包多个 basename。
    static func makeCompressCommand(
        itemURLs: [URL],
        destinationZip: URL,
        sourceDirectory: URL
    ) -> String {
        let destination = ShellQuoting.singleQuote(destinationZip.path)

        if itemURLs.count == 1, let source = itemURLs.first {
            let quotedSource = ShellQuoting.singleQuote(source.path)
            return "/usr/bin/ditto -c -k --keepParent \(quotedSource) \(destination)"
        }

        let directory = ShellQuoting.singleQuote(sourceDirectory.path)
        let entryNames = itemURLs
            .map { ShellQuoting.singleQuote($0.lastPathComponent) }
            .joined(separator: " ")
        return "cd \(directory) && /usr/bin/zip -r \(destination) \(entryNames)"
    }

    static func makeExtractCommand(
        archive: URL,
        destinationDirectory: URL,
        members: [String]? = nil,
        password: String? = nil
    ) -> String {
        let mkdir = "/bin/mkdir -p \(ShellQuoting.singleQuote(destinationDirectory.path))"
        let extract: String
        if shouldUseUnzip(for: archive, password: password) {
            extract = makeUnzipExtractCommand(
                archive: archive,
                destinationDirectory: destinationDirectory,
                members: members,
                password: password ?? ""
            )
        } else {
            extract = makeTarExtractCommand(
                archive: archive,
                destinationDirectory: destinationDirectory,
                members: members
            )
        }
        return "\(mkdir) && \(extract)"
    }

    static func isZipArchive(_ url: URL) -> Bool {
        url.lastPathComponent.lowercased().hasSuffix(".zip")
    }

    private static func shouldUseUnzip(for archive: URL, password: String?) -> Bool {
        guard isZipArchive(archive) else { return false }
        guard let password, !password.isEmpty else { return false }
        return true
    }

    private static func makeTarExtractCommand(
        archive: URL,
        destinationDirectory: URL,
        members: [String]?
    ) -> String {
        var command = "/usr/bin/tar -xf \(ShellQuoting.singleQuote(archive.path)) -C \(ShellQuoting.singleQuote(destinationDirectory.path))"
        if let members, !members.isEmpty {
            let quotedMembers = members.map { ShellQuoting.singleQuote($0) }.joined(separator: " ")
            command += " -- \(quotedMembers)"
        }
        return command
    }

    private static func makeUnzipExtractCommand(
        archive: URL,
        destinationDirectory: URL,
        members: [String]?,
        password: String
    ) -> String {
        var command = "/usr/bin/unzip -o -q -P \(ShellQuoting.singleQuote(password)) \(ShellQuoting.singleQuote(archive.path))"
        if let members, !members.isEmpty {
            for member in members {
                command += " \(ShellQuoting.singleQuote(member))"
            }
        }
        command += " -d \(ShellQuoting.singleQuote(destinationDirectory.path))"
        return command
    }

    static func makeExtractCommands(archives: [URL], destinationResolver: (URL) -> URL) -> String {
        archives
            .map { archive in
                let destination = destinationResolver(archive)
                return makeExtractCommand(archive: archive, destinationDirectory: destination)
            }
            .joined(separator: " && ")
    }
}
