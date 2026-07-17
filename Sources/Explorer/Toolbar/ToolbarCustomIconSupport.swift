import AppKit
import UniformTypeIdentifiers

/// 工具栏自定义项图标：从磁盘选择图片并复制到 Application Support，供按钮持久显示。
enum ToolbarCustomIconSupport {
    private static let fileManager = FileManager.default

    static var iconsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport
            .appendingPathComponent("Explorer", isDirectory: true)
            .appendingPathComponent("ToolbarIcons", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    /// 弹出文件选择面板；成功则返回已复制到本地存储的图标路径。
    @discardableResult
    static func pickAndImportIcon(forItemID itemID: UUID) -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedContentTypes
        panel.allowsOtherFileTypes = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = L10n.Toolbar.changeIconPrompt
        panel.prompt = L10n.Toolbar.changeIconChoose

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return importIcon(from: url, forItemID: itemID)
    }

    static func importIcon(from sourceURL: URL, forItemID itemID: UUID) -> String? {
        let access = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if access {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        removeExistingIcons(forItemID: itemID)

        if let image = NSImage(contentsOf: sourceURL), image.isValid {
            let ext = preferredExtension(for: sourceURL)
            let destination = destinationURL(forItemID: itemID, pathExtension: ext)
            do {
                try fileManager.copyItem(at: sourceURL, to: destination)
                return destination.path
            } catch {
                return writeNSImage(image, forItemID: itemID)
            }
        }

        // 部分 .icns / 系统图标文件可用 Workspace 解析
        let workspaceIcon = NSWorkspace.shared.icon(forFile: sourceURL.path)
        guard workspaceIcon.isValid, workspaceIcon.size.width > 0 else { return nil }
        return writeNSImage(workspaceIcon, forItemID: itemID)
    }

    static func removeIconFile(at path: String?) {
        guard let path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path)
        guard url.path.hasPrefix(iconsDirectory.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    static func nsImage(at path: String?) -> NSImage? {
        guard let path, !path.isEmpty,
              fileManager.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path),
              image.isValid else {
            return nil
        }
        return image
    }

    private static var allowedContentTypes: [UTType] {
        var types: [UTType] = [.png, .jpeg, .gif, .webP, .tiff, .bmp, .heic]
        if let icns = UTType(filenameExtension: "icns") {
            types.append(icns)
        }
        types.append(.image)
        return types
    }

    private static func preferredExtension(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        if ext.isEmpty { return "png" }
        return ext
    }

    private static func destinationURL(forItemID itemID: UUID, pathExtension: String) -> URL {
        // 同一项更换图标时覆盖同名前缀文件
        let base = iconsDirectory.appendingPathComponent(itemID.uuidString)
        return base.appendingPathExtension(pathExtension.isEmpty ? "png" : pathExtension)
    }

    private static func writeNSImage(_ image: NSImage, forItemID itemID: UUID) -> String? {
        removeExistingIcons(forItemID: itemID)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        let pngDestination = destinationURL(forItemID: itemID, pathExtension: "png")
        do {
            try png.write(to: pngDestination)
            return pngDestination.path
        } catch {
            return nil
        }
    }

    private static func removeExistingIcons(forItemID itemID: UUID) {
        let prefix = itemID.uuidString
        guard let contents = try? fileManager.contentsOfDirectory(
            at: iconsDirectory,
            includingPropertiesForKeys: nil
        ) else { return }
        for url in contents where url.deletingPathExtension().lastPathComponent == prefix {
            try? fileManager.removeItem(at: url)
        }
    }
}
