import XCTest
@testable import Explorer

@MainActor
final class ToolbarCustomizationStoreTests: XCTestCase {
    private var defaultsKey: String { AppPreferences.Toolbar.layoutConfig }

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        resetStore()
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        resetStore()
        super.tearDown()
    }

    private func resetStore() {
        let store = ToolbarCustomizationStore.shared
        store.cancelCustomization()
        store.resetToDefaults()
    }

    func testDefaultLayoutMatchesBuiltinOrder() {
        let layout = ToolbarLayoutConfig.default
        XCTAssertEqual(layout.visibleItems.count, ToolbarBuiltinID.allCases.count)
        XCTAssertEqual(layout.visibleItems.first?.id, ToolbarBuiltinID.leftPanel.rawValue)
        XCTAssertEqual(layout.visibleItems.last?.id, ToolbarBuiltinID.browseSettingsMenu.rawValue)

        let leadingIDs = layout.items(in: .leading).map(\.id)
        XCTAssertEqual(leadingIDs, [ToolbarBuiltinID.leftPanel.rawValue])

        let trailingIDs = layout.items(in: .trailing).map(\.id)
        XCTAssertEqual(
            trailingIDs,
            [
                ToolbarBuiltinID.newWindow.rawValue,
                ToolbarBuiltinID.newTab.rawValue,
                ToolbarBuiltinID.showAllTabs.rawValue,
                ToolbarBuiltinID.toggleTabBar.rawValue,
                ToolbarBuiltinID.thumbnailSizeSlider.rawValue,
                ToolbarBuiltinID.sortMenu.rawValue,
                ToolbarBuiltinID.browseSettingsMenu.rawValue,
            ]
        )
    }

    func testPaletteExcludesVisibleItems() {
        var layout = ToolbarLayoutConfig.default
        layout.removeVisible(itemID: ToolbarBuiltinID.preview.rawValue)
        layout.removeVisible(itemID: ToolbarBuiltinID.delete.rawValue)

        let paletteIDs = Set(layout.paletteItemRefs().map(\.id))
        XCTAssertTrue(paletteIDs.contains(ToolbarBuiltinID.preview.rawValue))
        XCTAssertTrue(paletteIDs.contains(ToolbarBuiltinID.delete.rawValue))
        XCTAssertFalse(paletteIDs.contains(ToolbarBuiltinID.newFolder.rawValue))
    }

    func testInsertAndMoveVisibleItem() {
        var layout = ToolbarLayoutConfig.default
        layout.removeVisible(itemID: ToolbarBuiltinID.snippets.rawValue)
        layout.insertVisible(
            itemID: ToolbarBuiltinID.snippets.rawValue,
            kind: .builtin,
            zone: .main,
            at: 0
        )

        let mainIDs = layout.items(in: .main).map(\.id)
        XCTAssertEqual(mainIDs.first, ToolbarBuiltinID.snippets.rawValue)
    }

    func testCommitCustomizationPersistsLayout() throws {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        store.beginCustomization()
        store.moveToPalette(itemID: ToolbarBuiltinID.delete.rawValue)
        store.commitCustomization()

        let data = try XCTUnwrap(UserDefaults.standard.data(forKey: defaultsKey))
        let decoded = try JSONDecoder().decode(ToolbarLayoutConfig.self, from: data)
        XCTAssertFalse(decoded.visibleIDSet.contains(ToolbarBuiltinID.delete.rawValue))
    }

    func testCancelCustomizationRestoresDraft() {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        let originalContainsDelete = store.layout.visibleIDSet.contains(ToolbarBuiltinID.delete.rawValue)

        store.beginCustomization()
        store.moveToPalette(itemID: ToolbarBuiltinID.delete.rawValue)
        XCTAssertFalse(store.workingLayout.visibleIDSet.contains(ToolbarBuiltinID.delete.rawValue))

        store.cancelCustomization()
        XCTAssertEqual(
            store.layout.visibleIDSet.contains(ToolbarBuiltinID.delete.rawValue),
            originalContainsDelete
        )
    }

    func testSanitizePreservesHiddenBuiltinItems() {
        var layout = ToolbarLayoutConfig.default
        layout.removeVisible(itemID: ToolbarBuiltinID.delete.rawValue)
        layout.removeVisible(itemID: ToolbarBuiltinID.preview.rawValue)

        layout.sanitize()

        XCTAssertFalse(layout.visibleIDSet.contains(ToolbarBuiltinID.delete.rawValue))
        XCTAssertFalse(layout.visibleIDSet.contains(ToolbarBuiltinID.preview.rawValue))
    }

    func testMergeNewBuiltinItemsFromDefaultOnlyAddsMissing() {
        var layout = ToolbarLayoutConfig.default
        layout.removeVisible(itemID: ToolbarBuiltinID.delete.rawValue)

        layout.mergeNewBuiltinItemsFromDefault()

        XCTAssertFalse(layout.visibleIDSet.contains(ToolbarBuiltinID.delete.rawValue))
        XCTAssertTrue(layout.visibleIDSet.contains(ToolbarBuiltinID.preview.rawValue))
    }

    func testDeleteCustomOpenAppRemovesActionAndVisibleEntry() {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        store.beginCustomization()

        let action = CustomOpenAppAction(
            displayName: "Test App",
            applicationPath: "/Applications/Safari.app"
        )
        store.addCustomOpenApp(action)
        let itemID = ToolbarItemIdentity.customItemID(action.id)
        var layout = store.workingLayout
        layout.insertVisible(itemID: itemID, kind: .openApp, zone: .main, at: 0)
        store.workingLayout = layout

        store.deleteCustomOpenApp(id: action.id)

        XCTAssertFalse(store.workingLayout.customOpenApps.contains { $0.id == action.id })
        XCTAssertFalse(store.workingLayout.visibleIDSet.contains(itemID))
    }
}

@MainActor
final class OpenAppExecutorTests: XCTestCase {
    private func makeFileItem(name: String) -> FileItem {
        FileItem(
            id: "/tmp/\(name)",
            url: URL(fileURLWithPath: "/tmp/\(name)"),
            name: name,
            isDirectory: false,
            modificationDate: .distantPast,
            creationDate: .distantPast,
            size: 0,
            isHidden: false,
            fileType: (name as NSString).pathExtension,
            sizeDisplay: "0 B",
            dateDisplay: "",
            creationDateDisplay: "",
            finderComment: "",
            tags: []
        )
    }

    func testRequiresSelectionWhenNoItems() {
        let action = CustomOpenAppAction(
            displayName: "Test",
            applicationPath: "/Applications/Safari.app"
        )
        let context = ToolbarActionContext(cwd: "/tmp", selectedItems: [])

        XCTAssertThrowsError(try OpenAppExecutor.run(action, context: context)) { error in
            XCTAssertEqual(error as? ToolbarActionError, .requiresSelection)
        }
    }

    func testApplicationMissingThrows() {
        let action = CustomOpenAppAction(
            displayName: "Missing",
            applicationPath: "/Applications/DefinitelyMissing.app"
        )
        let item = makeFileItem(name: "example.txt")
        let context = ToolbarActionContext(cwd: "/tmp", selectedItems: [item])

        XCTAssertThrowsError(try OpenAppExecutor.run(action, context: context)) { error in
            XCTAssertEqual(error as? ToolbarActionError, .applicationMissing("Missing"))
        }
    }

    func testRequireSelectionRejectsEmptySelection() {
        let action = CustomOpenAppAction(
            displayName: "Required",
            applicationPath: "/Applications/DefinitelyMissing.app",
            selectionPolicy: .requireSelection
        )
        let context = ToolbarActionContext(cwd: "/tmp", selectedItems: [])

        XCTAssertThrowsError(try OpenAppExecutor.run(action, context: context)) { error in
            XCTAssertEqual(error as? ToolbarActionError, .requiresSelection)
        }
    }

    func testSelectionPolicyDefaultsToRequireSelection() {
        let action = CustomOpenAppAction(
            displayName: "Default",
            applicationPath: "/Applications/Safari.app"
        )
        XCTAssertEqual(action.selectionPolicy, .requireSelection)
    }

    func testPassCurrentDirectoryDoesNotRequireSelection() {
        let action = CustomOpenAppAction(
            displayName: "Folder",
            applicationPath: "/Applications/DefinitelyMissing.app",
            selectionPolicy: .passCurrentDirectory
        )
        let context = ToolbarActionContext(cwd: "/Users/test/Projects", selectedItems: [])

        XCTAssertThrowsError(try OpenAppExecutor.run(action, context: context)) { error in
            XCTAssertEqual(error as? ToolbarActionError, .applicationMissing("Folder"))
            XCTAssertNotEqual(error as? ToolbarActionError, .requiresSelection)
        }
    }

    func testCustomOpenAppDecodesMissingSelectionPolicyAsRequireSelection() throws {
        let json = """
        {
          "id": "A1B2C3D4-E5F6-7890-ABCD-EF1234567890",
          "displayName": "Legacy",
          "applicationPath": "/Applications/Safari.app",
          "deliveryMode": "openFiles",
          "useApplicationIcon": true,
          "enabled": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CustomOpenAppAction.self, from: json)
        XCTAssertEqual(decoded.selectionPolicy, .requireSelection)
    }
}
