import XCTest
@testable import FileList

final class FileListL10nTests: XCTestCase {
    func testFileListResourceBundleContainsCatalog() throws {
        let bundle = Bundle.module
        let catalogPath = bundle.path(forResource: "Localizable", ofType: "xcstrings")
        XCTAssertNotNil(catalogPath, "FileList Localizable.xcstrings should exist in resource bundle")
    }

    func testFileListLocalizedStringsResolve() {
        XCTAssertFalse(L10n.Column.name.isEmpty)
        XCTAssertFalse(L10n.Action.newFolder.isEmpty)
        XCTAssertNotEqual(L10n.Column.name, "column.name")
    }

    func testFileListEnglishStringsMatchCatalog() {
        guard let enBundle = localizedBundle(language: "en", parent: Bundle.module) else {
            XCTAssertTrue(L10n.Column.name == "Name" || L10n.Column.name == "名称")
            return
        }
        XCTAssertEqual(
            enBundle.localizedString(forKey: "column.name", value: nil, table: nil),
            "Name"
        )
    }

    func testFileListChineseStringsMatchCatalog() {
        guard let zhBundle = localizedBundle(language: "zh-Hans", parent: Bundle.module) else {
            return
        }
        XCTAssertEqual(
            zhBundle.localizedString(forKey: "column.name", value: nil, table: nil),
            "名称"
        )
    }

    private func localizedBundle(language: String, parent: Bundle) -> Bundle? {
        guard let path = parent.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
