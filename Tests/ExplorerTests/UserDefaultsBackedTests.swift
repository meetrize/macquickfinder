import XCTest
@testable import Explorer

final class UserDefaultsBackedTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "UserDefaultsBackedTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testBoolUsesDefaultWhenUnset() {
        XCTAssertTrue(
            UserDefaultsStorage.bool(forKey: "test.bool", default: true, in: defaults)
        )
        XCTAssertFalse(
            UserDefaultsStorage.bool(forKey: "test.bool", default: false, in: defaults)
        )
    }

    func testBoolPersistsFalseDistinctFromUnset() {
        UserDefaultsStorage.set(false, forKey: "test.bool", in: defaults)
        XCTAssertFalse(
            UserDefaultsStorage.bool(forKey: "test.bool", default: true, in: defaults)
        )
    }

    func testPropertyWrapperRoundTrip() {
        var flag = UserDefaultsBool(wrappedValue: false, "test.wrapper.bool", store: defaults)
        XCTAssertFalse(flag.wrappedValue)
        flag.wrappedValue = true
        XCTAssertTrue(flag.wrappedValue)

        var count = UserDefaultsInt(wrappedValue: 2, "test.wrapper.int", store: defaults)
        count.wrappedValue = 5
        XCTAssertEqual(count.wrappedValue, 5)
    }

    func testExplorerAppSettingsForwardsToAppPreferences() {
        XCTAssertEqual(
            ExplorerAppSettings.showPreviewKey,
            AppPreferences.Layout.showPreview
        )
        XCTAssertEqual(
            ExplorerAppSettings.favoritesKey,
            AppPreferences.Data.favorites
        )
    }
}
