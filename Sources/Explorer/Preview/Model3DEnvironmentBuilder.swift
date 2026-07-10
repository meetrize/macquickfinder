import AppKit
import SceneKit
import simd

/// 3D 预览工作室环境：渐变背景、定向光、地面网格与模型落底对齐。
enum Model3DEnvironmentBuilder {
    static let modelRootName = "meofind-model-root"
    static let axisHelperName = "meofind-axis-helper"
    static let groundGridName = "meofind-env-ground"
    static let keyLightName = "meofind-env-light-key"
    static let ambientLightName = "meofind-env-light-ambient"

    static func makeStudioScene(
        from url: URL,
        boundingSize: SIMD3<Float>,
        wireframe: Bool
    ) -> SCNScene {
        let scene = SCNScene()
        let modelRoot = Model3DSceneBuilder.makeModelRoot(from: url)
        scene.rootNode.addChildNode(modelRoot)
        centerAndGround(modelRoot)

        applyStudioBackground(to: scene, boundingSize: boundingSize)
        applyStudioLighting(to: scene.rootNode)
        applyGroundGrid(to: scene.rootNode, boundingSize: boundingSize, visible: !wireframe)
        addAxisHelper(to: scene.rootNode, boundingSize: boundingSize)
        applyPreviewMaterials(to: modelRoot, wireframe: wireframe)

        return scene
    }

    static func applyPreviewMaterials(to node: SCNNode, wireframe: Bool) {
        if let geometry = node.geometry {
            geometry.materials = geometry.materials.map { material in
                let styled = (material.copy() as? SCNMaterial) ?? material
                styled.isDoubleSided = true
                styled.lightingModel = .physicallyBased
                if wireframe {
                    styled.diffuse.contents = NSColor(srgbRed: 0.28, green: 0.38, blue: 0.55, alpha: 1)
                    styled.fillMode = .lines
                } else {
                    styled.diffuse.contents = NSColor(srgbRed: 0.22, green: 0.48, blue: 0.82, alpha: 1)
                    styled.metalness.contents = 0.08
                    styled.roughness.contents = 0.58
                    styled.fillMode = .fill
                }
                return styled
            }
        }
        for child in node.childNodes where child.name != axisHelperName {
            applyPreviewMaterials(to: child, wireframe: wireframe)
        }
    }

    static func setGroundGridVisible(_ visible: Bool, in scene: SCNScene?) {
        scene?.rootNode.childNode(withName: groundGridName, recursively: false)?.isHidden = !visible
    }

    static func modelRoot(in scene: SCNScene?) -> SCNNode? {
        scene?.rootNode.childNode(withName: modelRootName, recursively: false)
    }

    // MARK: - Background

    private static func applyStudioBackground(to scene: SCNScene, boundingSize: SIMD3<Float>) {
        scene.background.contents = makeGradientBackgroundImage()
        let span = max(boundingSize.x, boundingSize.y, boundingSize.z, 1)
        scene.fogColor = NSColor(srgbRed: 0.74, green: 0.77, blue: 0.82, alpha: 1)
        scene.fogStartDistance = CGFloat(span * 2.5)
        scene.fogEndDistance = CGFloat(span * 10)
        scene.fogDensityExponent = 1.2
    }

    private static func makeGradientBackgroundImage() -> NSImage {
        let width = 4
        let height = 512
        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        defer { image.unlockFocus() }

        guard let context = NSGraphicsContext.current?.cgContext else { return image }

        let colors = [
            NSColor(srgbRed: 0.90, green: 0.92, blue: 0.95, alpha: 1).cgColor,
            NSColor(srgbRed: 0.78, green: 0.81, blue: 0.86, alpha: 1).cgColor,
            NSColor(srgbRed: 0.68, green: 0.72, blue: 0.78, alpha: 1).cgColor,
        ] as CFArray
        let locations: [CGFloat] = [0, 0.55, 1]
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        )

        context.drawLinearGradient(
            gradient!,
            start: CGPoint(x: 0, y: height),
            end: CGPoint(x: 0, y: 0),
            options: []
        )

        return image
    }

    // MARK: - Lighting

    private static func applyStudioLighting(to rootNode: SCNNode) {
        rootNode.childNode(withName: keyLightName, recursively: false)?.removeFromParentNode()
        rootNode.childNode(withName: ambientLightName, recursively: false)?.removeFromParentNode()

        let keyLightNode = SCNNode()
        keyLightNode.name = keyLightName
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 950
        keyLight.color = NSColor(srgbRed: 1.0, green: 0.98, blue: 0.95, alpha: 1)
        keyLight.castsShadow = false
        keyLightNode.light = keyLight
        keyLightNode.eulerAngles = SCNVector3(-Float.pi / 3.2, Float.pi / 5, 0)
        rootNode.addChildNode(keyLightNode)

        let fillLightNode = SCNNode()
        fillLightNode.name = "meofind-env-light-fill"
        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 280
        fillLight.color = NSColor(srgbRed: 0.88, green: 0.92, blue: 1.0, alpha: 1)
        fillLight.castsShadow = false
        fillLightNode.light = fillLight
        fillLightNode.eulerAngles = SCNVector3(-Float.pi / 5, -Float.pi / 3, 0)
        rootNode.addChildNode(fillLightNode)

        let ambientNode = SCNNode()
        ambientNode.name = ambientLightName
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.intensity = 420
        ambient.color = NSColor(srgbRed: 0.86, green: 0.88, blue: 0.92, alpha: 1)
        ambientNode.light = ambient
        rootNode.addChildNode(ambientNode)
    }

    // MARK: - Ground Grid

    private static func applyGroundGrid(
        to rootNode: SCNNode,
        boundingSize: SIMD3<Float>,
        visible: Bool
    ) {
        rootNode.childNode(withName: groundGridName, recursively: false)?.removeFromParentNode()

        let horizontalSpan = max(boundingSize.x, boundingSize.z, 1)
        let planeSize = max(horizontalSpan * 4, 12)

        let plane = SCNPlane(width: CGFloat(planeSize), height: CGFloat(planeSize))
        plane.cornerRadius = 0
        plane.firstMaterial?.diffuse.contents = makeGridTexture()
        plane.firstMaterial?.isDoubleSided = true
        plane.firstMaterial?.lightingModel = .constant
        plane.firstMaterial?.writesToDepthBuffer = true

        let gridNode = SCNNode(geometry: plane)
        gridNode.name = groundGridName
        gridNode.eulerAngles.x = -.pi / 2
        gridNode.position.y = -0.0005
        gridNode.isHidden = !visible
        rootNode.addChildNode(gridNode)
    }

    private static func makeGridTexture() -> NSImage {
        let pixelSize = 512
        let minorCell = 16
        let majorEvery = 4

        let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor(srgbRed: 0.90, green: 0.91, blue: 0.93, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()

        let minorColor = NSColor(srgbRed: 0.80, green: 0.82, blue: 0.86, alpha: 1)
        let majorColor = NSColor(srgbRed: 0.66, green: 0.70, blue: 0.76, alpha: 1)
        let cellPixels = pixelSize / minorCell

        for index in 0...minorCell {
            let coordinate = index * cellPixels
            let isMajor = index % majorEvery == 0
            let lineColor = isMajor ? majorColor : minorColor
            let lineWidth: CGFloat = isMajor ? 1.5 : 0.75

            lineColor.setStroke()
            let vertical = NSBezierPath()
            vertical.lineWidth = lineWidth
            vertical.move(to: NSPoint(x: coordinate, y: 0))
            vertical.line(to: NSPoint(x: coordinate, y: pixelSize))
            vertical.stroke()

            let horizontal = NSBezierPath()
            horizontal.lineWidth = lineWidth
            horizontal.move(to: NSPoint(x: 0, y: coordinate))
            horizontal.line(to: NSPoint(x: pixelSize, y: coordinate))
            horizontal.stroke()
        }

        return image
    }

    // MARK: - Model Placement

    private static func centerAndGround(_ modelRoot: SCNNode) {
        let bounds = modelRoot.boundingBox
        let minBounds = bounds.min
        let maxBounds = bounds.max

        let centerX = (minBounds.x + maxBounds.x) * 0.5
        let centerZ = (minBounds.z + maxBounds.z) * 0.5
        modelRoot.position = SCNVector3(-centerX, -minBounds.y, -centerZ)
    }

    // MARK: - Axis Helper

    private static func addAxisHelper(to rootNode: SCNNode, boundingSize: SIMD3<Float>) {
        rootNode.childNode(withName: axisHelperName, recursively: false)?.removeFromParentNode()

        let maxDimension = max(boundingSize.x, boundingSize.y, boundingSize.z, 1)
        let axisLength = maxDimension * 0.2
        let axisNode = SCNNode()
        axisNode.name = axisHelperName

        axisNode.addChildNode(makeAxisLine(
            from: SCNVector3(0, 0, 0),
            to: SCNVector3(axisLength, 0, 0),
            color: .systemRed
        ))
        axisNode.addChildNode(makeAxisLine(
            from: SCNVector3(0, 0, 0),
            to: SCNVector3(0, axisLength, 0),
            color: .systemGreen
        ))
        axisNode.addChildNode(makeAxisLine(
            from: SCNVector3(0, 0, 0),
            to: SCNVector3(0, 0, axisLength),
            color: .systemBlue
        ))

        rootNode.addChildNode(axisNode)
    }

    private static func makeAxisLine(from start: SCNVector3, to end: SCNVector3, color: NSColor) -> SCNNode {
        let source = SCNGeometrySource(vertices: [start, end])
        let indices: [Int32] = [0, 1]
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.isDoubleSided = true
        material.lightingModel = .constant
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.name = "meofind-axis-line"
        return node
    }
}
