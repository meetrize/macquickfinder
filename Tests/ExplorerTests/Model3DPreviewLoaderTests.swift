import XCTest
@testable import Explorer

final class Model3DPreviewLoaderTests: XCTestCase {
    private let sampleSTL = """
    solid test
      facet normal 0 0 1
        outer loop
          vertex 0 0 0
          vertex 1 0 0
          vertex 0 1 0
        endloop
      endfacet
    endsolid test
    """

    func testLoadParsesTriangleMetadata() throws {
        let url = try writeTemporarySTL(sampleSTL)
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try Model3DPreviewLoader.load(from: url)
        XCTAssertEqual(content.metadata.triangleCount, 1)
        XCTAssertGreaterThan(content.metadata.boundingBoxSize.x, 0)
        XCTAssertGreaterThan(content.metadata.boundingBoxSize.y, 0)
        XCTAssertEqual(content.sourcePath, url.path)
    }

    func testLoadRejectsEmptyFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("empty-\(UUID().uuidString).stl")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try Model3DPreviewLoader.load(from: url)) { error in
            XCTAssertTrue(error is Model3DPreviewLoader.LoaderError)
        }
    }

    func testL10nModel3DKeysAreTranslated() {
        XCTAssertNotEqual(L10n.Preview.Model3D.unitHint, "preview.model3d.unit_hint")
        XCTAssertNotEqual(L10n.Preview.Model3D.triangles(12), "preview.model3d.triangles %lld")
        XCTAssertNotEqual(
            L10n.Preview.Model3D.dimensions(1.0, 2.0, 3.0),
            "preview.model3d.dimensions %.1f %.1f %.1f"
        )
        XCTAssertNotEqual(L10n.Preview.Toolbar.copyModelInfo, "preview.toolbar.copy_model_info")
        XCTAssertNotEqual(L10n.Preview.Toolbar.model3dWireframe, "preview.toolbar.model3d_wireframe")
        XCTAssertNotEqual(L10n.Preview.Toolbar.model3dSolid, "preview.toolbar.model3d_solid")
        XCTAssertNotEqual(L10n.Preview.Toolbar.model3dRotateUp, "preview.toolbar.model3d_rotate_up")
        XCTAssertNotEqual(L10n.Preview.Toolbar.model3dRotateDown, "preview.toolbar.model3d_rotate_down")
        XCTAssertNotEqual(L10n.Error.Model3D.unableToLoad, "error.model3d.unable_to_load")
        XCTAssertNotEqual(L10n.Error.Model3D.emptyModel, "error.model3d.empty_model")
        XCTAssertNotEqual(L10n.Error.Model3D.fileTooLarge, "error.model3d.file_too_large")
        XCTAssertNotEqual(L10n.Error.Model3D.tooManyTriangles(100), "error.model3d.too_many_triangles %lld")
    }

    func testSummaryTextIncludesMetadata() throws {
        let url = try writeTemporarySTL(sampleSTL)
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try Model3DPreviewLoader.load(from: url)
        XCTAssertTrue(content.summaryText.contains("1"))
        XCTAssertFalse(content.summaryText.isEmpty)
    }

    func testStudioSceneIncludesEnvironmentNodes() throws {
        let url = try writeTemporarySTL(sampleSTL)
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try Model3DPreviewLoader.load(from: url)
        let scene = Model3DEnvironmentBuilder.makeStudioScene(
            from: url,
            boundingSize: content.metadata.boundingBoxSize,
            wireframe: false
        )

        XCTAssertNotNil(Model3DEnvironmentBuilder.modelRoot(in: scene))
        XCTAssertNotNil(scene.rootNode.childNode(withName: Model3DEnvironmentBuilder.groundGridName, recursively: false))
        XCTAssertNotNil(scene.rootNode.childNode(withName: Model3DEnvironmentBuilder.keyLightName, recursively: false))
        XCTAssertNotNil(scene.rootNode.childNode(withName: Model3DEnvironmentBuilder.ambientLightName, recursively: false))
        XCTAssertNotNil(scene.background.contents)
    }

    func testStudioSceneHidesGroundGridInWireframeMode() throws {
        let url = try writeTemporarySTL(sampleSTL)
        defer { try? FileManager.default.removeItem(at: url) }

        let content = try Model3DPreviewLoader.load(from: url)
        let scene = Model3DEnvironmentBuilder.makeStudioScene(
            from: url,
            boundingSize: content.metadata.boundingBoxSize,
            wireframe: true
        )

        let grid = scene.rootNode.childNode(withName: Model3DEnvironmentBuilder.groundGridName, recursively: false)
        XCTAssertEqual(grid?.isHidden, true)
    }

    private func writeTemporarySTL(_ contents: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("model-\(UUID().uuidString).stl")
        try contents.data(using: .utf8)?.write(to: url)
        return url
    }
}
