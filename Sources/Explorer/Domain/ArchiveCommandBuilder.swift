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

    static func makeExtractCommand(archive: URL, destinationDirectory: URL) -> String {
        let mkdir = "/bin/mkdir -p \(ShellQuoting.singleQuote(destinationDirectory.path))"
        let extract = "/usr/bin/tar -xf \(ShellQuoting.singleQuote(archive.path)) -C \(ShellQuoting.singleQuote(destinationDirectory.path))"
        return "\(mkdir) && \(extract)"
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
