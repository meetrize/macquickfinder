import AppKit
import Foundation

/// EPS 预览辅助：解析 BoundingBox 获取逻辑尺寸，通过 Ghostscript 栅格化。
enum EPSPreviewSupport {
    /// Ghostscript 可执行文件路径缓存。
    private static let gsPath: String? = {
        let candidates = [
            "/Volumes/SSD4T/dev/homebrew/bin/gs",
            "/opt/homebrew/bin/gs",
            "/usr/local/bin/gs",
            "/usr/bin/gs",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        // fallback: 通过 PATH 查找
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "gs"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let found = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let found, !found.isEmpty, FileManager.default.isExecutableFile(atPath: found) {
                return found
            }
        } catch {}
        return nil
    }()

    /// 系统是否安装了 Ghostscript。
    static var isGhostscriptAvailable: Bool { gsPath != nil }

    /// Ghostscript 未安装时的友好提示信息。
    static let missingGhostscriptMessage = """
EPS 矢量图预览需要 Ghostscript 支持。

请通过 Homebrew 安装：
  brew install ghostscript

安装后重新打开文件即可预览。
"""

    static func isEPSURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext == "eps" || ext == "epsf" || ext == "epsi"
    }

    static func isEPSData(_ data: Data) -> Bool {
        // EPS 文件以 "%!PS-Adobe" 开头，但也可能有二进制前缀（如 Mac 资源分支头）
        // 因此在整个文件前 512 字节中搜索该标记
        guard data.count >= 10 else { return false }
        let searchRange = data.prefix(512)
        // 直接在二进制数据中搜索 "%!PS-Adobe"
        let marker = Data("%!PS-Adobe".utf8)
        return searchRange.range(of: marker) != nil
    }

    /// 从 EPS BoundingBox 注释提取逻辑尺寸（单位：点，1/72 英寸）。
    static func logicalSize(fromEPSData data: Data) -> CGSize? {
        // 查找 %!PS-Adobe 标记位置，从那里开始解析文本
        guard let markerRange = data.range(of: Data("%!PS-Adobe".utf8)) else { return nil }
        let headerStart = markerRange.lowerBound
        let headerData = data[headerStart...]
        let headerStr = String(data: headerData.prefix(4096), encoding: .utf8)
                ?? String(data: headerData.prefix(4096), encoding: .isoLatin1)
        guard let headerStr else { return nil }
        return logicalSize(fromEPSString: headerStr)
    }

    static func logicalSize(fromEPSString str: String) -> CGSize? {
        // 解析 %%BoundingBox: llx lly urx ury
        let pattern = #"%%BoundingBox:\s*(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: str, range: NSRange(str.startIndex..., in: str)),
              match.numberOfRanges == 5,
              let llxRange = Range(match.range(at: 1), in: str),
              let llyRange = Range(match.range(at: 2), in: str),
              let urxRange = Range(match.range(at: 3), in: str),
              let uryRange = Range(match.range(at: 4), in: str),
              let llx = Double(str[llxRange]),
              let lly = Double(str[llyRange]),
              let urx = Double(str[urxRange]),
              let ury = Double(str[uryRange]) else {
            return nil
        }
        let width = urx - llx
        let height = ury - lly
        guard width > 0, height > 0 else { return nil }
        return CGSize(width: width, height: height)
    }

    /// 从 URL 解码 EPS 文件为 NSImage（直接传文件路径给 Ghostscript，避免 pipe 死锁）。
    static func decode(from url: URL, maxPixelSize: Int?) -> NSImage? {
        guard let gsPath else { return nil }

        let logical = readLogicalSize(from: url) ?? CGSize(width: 612, height: 792)
        let renderDPI = rasterDPI(logical: logical, maxPixelSize: maxPixelSize)

        let pngData = invokeGhostscript(gsPath: gsPath, inputPath: url.path, dpi: renderDPI)
        guard let pngData, let image = NSImage(data: pngData), image.isValid else {
            return nil
        }
        image.size = logical
        return image
    }

    /// 从内存 Data 解码 EPS（写入临时文件再传给 Ghostscript）。
    static func decode(data: Data, maxPixelSize: Int?) -> NSImage? {
        guard let gsPath else { return nil }

        let logical = logicalSize(fromEPSData: data) ?? CGSize(width: 612, height: 792)
        let renderDPI = rasterDPI(logical: logical, maxPixelSize: maxPixelSize)

        // 写入临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("eps_preview_\(UUID().uuidString).eps")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        do {
            try data.write(to: tempURL, options: .atomic)
        } catch {
            return nil
        }

        let pngData = invokeGhostscript(gsPath: gsPath, inputPath: tempURL.path, dpi: renderDPI)
        guard let pngData, let image = NSImage(data: pngData), image.isValid else {
            return nil
        }
        image.size = logical
        return image
    }

    // MARK: - Private

    /// 调用 Ghostscript 将 EPS 渲染为 PNG，返回 PNG 数据。
    /// 通过 stdout 管道接收 PNG 数据，避免临时 PNG 文件。
    private static func invokeGhostscript(gsPath: String, inputPath: String, dpi: CGFloat) -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: gsPath)
        task.arguments = [
            "-dQUIET", "-dSAFER", "-dBATCH", "-dNOPAUSE", "-dNOPROMPT",
            "-dMaxBitmap=500000000",
            "-dAlignToPixels=0",
            "-dGridFitTT=2",
            "-sDEVICE=png16m",
            "-dTextAlphaBits=4",
            "-dGraphicsAlphaBits=4",
            "-r\(Int(dpi))x\(Int(dpi))",
            "-dEPSCrop",
            "-sOutputFile=%stdout",
            inputPath,
        ]

        let stdoutPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = FileHandle.nullDevice
        task.standardInput = FileHandle.nullDevice

        do {
            try task.run()
        } catch {
            return nil
        }

        let pngData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0, !pngData.isEmpty else { return nil }
        return pngData
    }

    /// 从文件读取 BoundingBox（只读文件头部，不加载全文件）。
    private static func readLogicalSize(from url: URL) -> CGSize? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 4096) else { return nil }
        return logicalSize(fromEPSData: data)
    }

    /// 根据 EPS 逻辑尺寸和预览像素预算计算渲染 DPI。
    private static func rasterDPI(logical: CGSize, maxPixelSize: Int?) -> CGFloat {
        let longest = max(logical.width, logical.height, 1)
        let budget = CGFloat(maxPixelSize ?? ImagePreviewLoader.defaultDisplayPixelBudget)
        let dpi = (budget / longest) * 72.0
        return min(max(dpi, 72), 600)
    }
}
