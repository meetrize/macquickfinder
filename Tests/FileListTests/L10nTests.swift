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
        XCTAssertNotEqual(L10n.Column.dateAdded, "column.date_added")
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
        XCTAssertEqual(
            zhBundle.localizedString(forKey: "column.date_added", value: nil, table: nil),
            "添加日期"
        )
    }

    func testNormalizeBundleLanguageIDMatchesLprojDirectoryCase() {
        XCTAssertEqual(ModuleLocalization.normalizeBundleLanguageID("zh-Hans-CN"), "zh-Hans")
        XCTAssertEqual(ModuleLocalization.normalizeBundleLanguageID("zh-CN"), "zh-Hans")
        XCTAssertEqual(ModuleLocalization.normalizeBundleLanguageID("zh"), "zh-Hans")
        XCTAssertEqual(ModuleLocalization.normalizeBundleLanguageID("en-US"), "en")
        XCTAssertEqual(InterfaceLanguage.zhHans.bundleLanguageID, "zh-Hans")

        // Bundle.path 区分大小写：错误的 zh-hans 会找不到并导致跟随系统时回退英文
        XCTAssertNotNil(localizedBundle(language: "zh-Hans", parent: Bundle.module))
        XCTAssertNil(localizedBundle(language: "zh-hans", parent: Bundle.module))
    }

    private func localizedBundle(language: String, parent: Bundle) -> Bundle? {
        guard let path = parent.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
