import XCTest
@testable import Explorer

@MainActor
final class ExternalPreviewOpenCenterTests: XCTestCase {
    override func tearDown() {
        ExternalPreviewOpenCenter.shared.clearSuppressExplorerWindows()
        let store = PreviewSessionStore.shared
        Array(store.sessions.keys).forEach { store.remove($0) }
        super.tearDown()
    }

    func testTryOpenReturnsFalseForNonPreviewableURLs() {
        let urls = [
            URL(fileURLWithPath: "/tmp/readme.xyzunknown"),
            URL(fileURLWithPath: "/tmp/folder", isDirectory: true),
        ]
        XCTAssertFalse(ExternalPreviewOpenCenter.shared.tryOpen(urls: urls))
        XCTAssertFalse(ExternalPreviewOpenCenter.shared.shouldSuppressExplorerWindows)
    }

    func testTryOpenOpensSinglePreviewWindowForFirstPreviewableURL() {
        var openedValues: [PreviewWindowValue] = []
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedValues.append(value)
        }

        let opened = ExternalPreviewOpenCenter.shared.tryOpen(urls: [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.pdf"),
        ])

        XCTAssertTrue(opened)
        XCTAssertEqual(openedValues.count, 1)
        XCTAssertTrue(openedValues[0].fitImageToScreen)
    }

    func testTryOpenUsesTypeSpecificWindowSizeForPDF() {
        var openedValue: PreviewWindowValue?
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedValue = value
        }

        XCTAssertTrue(ExternalPreviewOpenCenter.shared.tryOpen(urls: [
            URL(fileURLWithPath: "/tmp/report.pdf"),
        ]))

        XCTAssertEqual(openedValue?.initialWindowSize, CGSize(width: 800, height: 1000))
        XCTAssertFalse(openedValue?.fitImageToScreen ?? true)
    }

    func testTryOpenOpensOneWindowPerImageWhenConfigured() {
        PreviewOpenPreferences.externalMultiImageOpen = .oneWindowPerFile
        var openedValues: [PreviewWindowValue] = []
        ExternalPreviewOpenCenter.shared.setOpenPreviewWindowHandler { value in
            openedValues.append(value)
        }

        let opened = ExternalPreviewOpenCenter.shared.tryOpen(urls: [
            URL(fileURLWithPath: "/tmp/a.png"),
            URL(fileURLWithPath: "/tmp/b.png"),
        ])

        XCTAssertTrue(opened)
        XCTAssertEqual(openedValues.count, 2)
        UserDefaults.standard.removeObject(forKey: AppPreferences.Preview.externalMultiImageOpen)
    }
}
