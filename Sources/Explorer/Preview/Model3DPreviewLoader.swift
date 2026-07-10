import Foundation
import ModelIO
import simd

struct Model3DPreviewMetadata: Equatable {
    let triangleCount: Int
    let boundingBoxSize: SIMD3<Float>
    let fileSize: Int64
}

struct Model3DPreviewContent: Equatable {
    let sourcePath: String
    let metadata: Model3DPreviewMetadata

    var sourceURL: URL {
        URL(fileURLWithPath: sourcePath)
    }

    var summaryText: String {
        [
            L10n.Preview.Model3D.triangles(metadata.triangleCount),
            L10n.Preview.Model3D.dimensions(
                metadata.boundingBoxSize.x,
                metadata.boundingBoxSize.y,
                metadata.boundingBoxSize.z
            ),
            L10n.Preview.Model3D.unitHint,
        ].joined(separator: "\n")
    }
}

/// 使用 ModelIO 解析 STL 等三角网格并提取预览元数据。
enum Model3DPreviewLoader {
    static let maxPreviewFileSize: Int64 = 80 * 1024 * 1024
    static let maxTriangleCount = 2_000_000

    static func load(from url: URL) throws -> Model3DPreviewContent {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            throw LoaderError.emptyModel
        }
        guard fileSize <= maxPreviewFileSize else {
            throw LoaderError.fileTooLarge
        }

        let asset = MDLAsset(url: url)
        guard asset.count > 0 else {
            throw LoaderError.emptyModel
        }

        var triangleCount = 0
        var minBounds = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var maxBounds = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)

        for index in 0..<asset.count {
            guard let mesh = asset.object(at: index) as? MDLMesh else { continue }
            triangleCount += Self.countTriangles(in: mesh)

            let bounds = mesh.boundingBox
            minBounds = simd_min(minBounds, bounds.minBounds)
            maxBounds = simd_max(maxBounds, bounds.maxBounds)
        }

        guard triangleCount > 0 else {
            throw LoaderError.emptyModel
        }
        guard triangleCount <= maxTriangleCount else {
            throw LoaderError.tooManyTriangles(triangleCount)
        }

        let size = maxBounds - minBounds
        guard size.x.isFinite, size.y.isFinite, size.z.isFinite else {
            throw LoaderError.unableToLoad
        }

        return Model3DPreviewContent(
            sourcePath: url.path,
            metadata: Model3DPreviewMetadata(
                triangleCount: triangleCount,
                boundingBoxSize: size,
                fileSize: fileSize
            )
        )
    }

    private static func countTriangles(in mesh: MDLMesh) -> Int {
        guard let submeshes = mesh.submeshes as? [MDLSubmesh] else { return 0 }
        var total = 0
        for submesh in submeshes {
            let indexCount = submesh.indexCount
            switch submesh.geometryType {
            case .triangles:
                total += indexCount / 3
            default:
                continue
            }
        }
        return total
    }

    enum LoaderError: LocalizedError {
        case unableToLoad
        case emptyModel
        case fileTooLarge
        case tooManyTriangles(Int)

        var errorDescription: String? {
            switch self {
            case .unableToLoad:
                return L10n.Error.Model3D.unableToLoad
            case .emptyModel:
                return L10n.Error.Model3D.emptyModel
            case .fileTooLarge:
                return L10n.Error.Model3D.fileTooLarge
            case .tooManyTriangles(let count):
                return L10n.Error.Model3D.tooManyTriangles(count)
            }
        }
    }
}
