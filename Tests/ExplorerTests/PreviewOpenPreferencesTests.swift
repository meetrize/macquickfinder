import UniformTypeIdentifiers
import XCTest
@testable import Explorer

final class PreviewOpenPreferencesTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppPreferences.Preview.doubleClickAction)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Preview.externalOpenAction)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Preview.archiveDoubleClickAction)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Preview.externalMultiImageOpen)
        super.tearDown()
    }

    func testDefaultsMatchP2Behavior() {
        XCTAssertEqual(PreviewOpenPreferences.doubleClickAction, .defaultApp)
        XCTAssertEqual(PreviewOpenPreferences.externalOpenAction, .standaloneOnly)
        XCTAssertEqual(PreviewOpenPreferences.archiveDoubleClickAction, .extract)
        XCTAssertEqual(PreviewOpenPreferences.externalMultiImageOpen, .singleWindowWithStrip)
    }

    func testDoubleClickActionRoundTrip() {
        PreviewOpenPreferences.doubleClickAction = .standalonePreview
        XCTAssertEqual(PreviewOpenPreferences.doubleClickAction, .standalonePreview)
    }

    func testExternalOpenActionRoundTrip() {
        PreviewOpenPreferences.externalOpenAction = .browserAndSelect
        XCTAssertEqual(PreviewOpenPreferences.externalOpenAction, .browserAndSelect)
    }

    func testArchiveDoubleClickActionRoundTrip() {
        PreviewOpenPreferences.archiveDoubleClickAction = .preview
        XCTAssertEqual(PreviewOpenPreferences.archiveDoubleClickAction, .preview)
    }

    func testExternalMultiImageOpenRoundTrip() {
        PreviewOpenPreferences.externalMultiImageOpen = .oneWindowPerFile
        XCTAssertEqual(PreviewOpenPreferences.externalMultiImageOpen, .oneWindowPerFile)
    }
}

final class PreviewHandlerGroupTests: XCTestCase {
    func testManagedContentTypesAreNonEmpty() {
        for group in PreviewHandlerGroup.allCases {
            XCTAssertFalse(group.managedContentTypes.isEmpty, "Missing UTTypes for \(group.rawValue)")
        }
    }

    func testImageGroupIncludesJPEGAndPNG() {
        let identifiers = Set(PreviewHandlerGroup.image.managedContentTypes.map(\.identifier))
        XCTAssertTrue(identifiers.contains(UTType.jpeg.identifier))
        XCTAssertTrue(identifiers.contains(UTType.png.identifier))
    }

    func testPDFGroupIncludesPDFType() {
        let identifiers = Set(PreviewHandlerGroup.pdf.managedContentTypes.map(\.identifier))
        XCTAssertTrue(identifiers.contains(UTType.pdf.identifier))
    }

    func testOfficeGroupIncludesDocx() {
        let identifiers = Set(PreviewHandlerGroup.office.managedContentTypes.map(\.identifier))
        XCTAssertTrue(
            identifiers.contains("org.openxmlformats.wordprocessingml.document")
                || identifiers.contains(UTType(filenameExtension: "docx")!.identifier)
        )
    }
}

final class PreviewDoubleClickActionTests: XCTestCase {
    func testAllCasesHaveDisplayNames() {
        for action in PreviewDoubleClickAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty)
            XCTAssertNotEqual(action.displayName, action.rawValue)
        }
    }
}

final class PreviewArchiveDoubleClickActionTests: XCTestCase {
    func testAllCasesHaveDisplayNames() {
        for action in PreviewArchiveDoubleClickAction.allCases {
            XCTAssertFalse(action.displayName.isEmpty)
            XCTAssertNotEqual(action.displayName, action.rawValue)
        }
    }
}

final class PreviewExternalMultiImageOpenStrategyTests: XCTestCase {
    func testAllCasesHaveDisplayNames() {
        for strategy in PreviewExternalMultiImageOpenStrategy.allCases {
            XCTAssertFalse(strategy.displayName.isEmpty)
            XCTAssertNotEqual(strategy.displayName, strategy.rawValue)
        }
    }
}
