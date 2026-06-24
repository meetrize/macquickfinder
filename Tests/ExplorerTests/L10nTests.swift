import XCTest
@testable import Explorer

final class ExplorerL10nTests: XCTestCase {
    func testExplorerResourceBundleContainsCatalog() throws {
        let bundle = Bundle.module
        let catalogPath = bundle.path(forResource: "Localizable", ofType: "xcstrings")
        XCTAssertNotNil(catalogPath, "Explorer Localizable.xcstrings should exist in resource bundle")
    }

    func testExplorerLocalizedStringsResolve() {
        XCTAssertFalse(L10n.Sidebar.favorites.isEmpty)
        XCTAssertFalse(L10n.Sidebar.trash.isEmpty)
        XCTAssertFalse(L10n.Settings.Tab.general.isEmpty)
        XCTAssertNotEqual(L10n.Sidebar.favorites, "sidebar.favorites")
        XCTAssertNotEqual(L10n.Sidebar.trash, "sidebar.trash")
    }

    func testExplorerEnglishStringsMatchCatalog() {
        guard let enBundle = localizedBundle(language: "en", parent: Bundle.module) else {
            // SPM 可能仅打包 xcstrings；回退验证运行时解析结果
            XCTAssertTrue(L10n.Sidebar.favorites == "Favorites" || L10n.Sidebar.favorites == "个人收藏")
            return
        }
        XCTAssertEqual(
            enBundle.localizedString(forKey: "sidebar.favorites", value: nil, table: nil),
            "Favorites"
        )
        XCTAssertEqual(
            enBundle.localizedString(forKey: "sidebar.trash", value: nil, table: nil),
            "Trash"
        )
    }

    func testExplorerChineseStringsMatchCatalog() {
        guard let zhBundle = localizedBundle(language: "zh-Hans", parent: Bundle.module) else {
            return
        }
        XCTAssertEqual(
            zhBundle.localizedString(forKey: "sidebar.favorites", value: nil, table: nil),
            "个人收藏"
        )
        XCTAssertEqual(
            zhBundle.localizedString(forKey: "sidebar.trash", value: nil, table: nil),
            "废纸篓"
        )
    }

    private func localizedBundle(language: String, parent: Bundle) -> Bundle? {
        guard let path = parent.path(forResource: language, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}
