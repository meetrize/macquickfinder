import ModelIO
import SceneKit
import simd

enum Model3DSceneBuilder {
    static func makeModelRoot(from url: URL) -> SCNNode {
        let asset = MDLAsset(url: url)
        let root = SCNNode()
        root.name = Model3DEnvironmentBuilder.modelRootName

        for index in 0..<asset.count {
            guard let mesh = asset.object(at: index) as? MDLMesh else { continue }
            mesh.addNormals(withAttributeNamed: MDLVertexAttributeNormal, creaseThreshold: 0.5)
            if let geometry = geometry(from: mesh) {
                root.addChildNode(SCNNode(geometry: geometry))
            }
        }

        return root
    }

    private static func geometry(from mesh: MDLMesh) -> SCNGeometry? {
        guard let vertices = vertexPositions(from: mesh), !vertices.isEmpty else { return nil }
        guard let submeshes = mesh.submeshes as? [MDLSubmesh], !submeshes.isEmpty else { return nil }

        let vertexSource = SCNGeometrySource(vertices: vertices)
        var elements: [SCNGeometryElement] = []

        for submesh in submeshes where submesh.geometryType == .triangles {
            guard let indices = triangleIndices(from: submesh), !indices.isEmpty else { continue }
            elements.append(SCNGeometryElement(indices: indices, primitiveType: .triangles))
        }

        guard !elements.isEmpty else { return nil }
        return SCNGeometry(sources: [vertexSource], elements: elements)
    }

    private static func vertexPositions(from mesh: MDLMesh) -> [SCNVector3]? {
        guard let vertexData = mesh.vertexAttributeData(forAttributeNamed: MDLVertexAttributePosition) else {
            return nil
        }
        let vertexCount = mesh.vertexCount
        guard vertexCount > 0, vertexData.stride > 0 else { return nil }

        var vertices: [SCNVector3] = []
        vertices.reserveCapacity(vertexCount)

        let base = vertexData.dataStart
        for index in 0..<vertexCount {
            let pointer = base.advanced(by: index * vertexData.stride)
            let position = pointer.assumingMemoryBound(to: vector_float3.self).pointee
            vertices.append(SCNVector3(position.x, position.y, position.z))
        }

        return vertices
    }

    private static func triangleIndices(from submesh: MDLSubmesh) -> [Int32]? {
        let indexCount = submesh.indexCount
        guard indexCount >= 3 else { return nil }

        let bytes = submesh.indexBuffer.map().bytes
        var indices: [Int32] = []
        indices.reserveCapacity(indexCount)

        switch submesh.indexType {
        case .uInt16:
            let raw = bytes.bindMemory(to: UInt16.self, capacity: indexCount)
            for index in 0..<indexCount {
                indices.append(Int32(raw[index]))
            }
        case .uInt32:
            let raw = bytes.bindMemory(to: UInt32.self, capacity: indexCount)
            for index in 0..<indexCount {
                indices.append(Int32(raw[index]))
            }
        default:
            return nil
        }

        return indices
    }
}
