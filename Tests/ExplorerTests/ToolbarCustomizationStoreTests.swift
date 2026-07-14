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
        XCTAssertEqual(layout.visibleItems.first?.id, ToolbarBuiltinID.newFile.rawValue)
        XCTAssertEqual(layout.visibleItems.last?.id, ToolbarBuiltinID.thumbnailSizeSlider.rawValue)

        let leadingIDs = layout.items(in: .leading).map(\.id)
        XCTAssertEqual(
            leadingIDs,
            [
                ToolbarBuiltinID.newFile.rawValue,
                ToolbarBuiltinID.newFolder.rawValue,
                ToolbarBuiltinID.delete.rawValue,
                ToolbarBuiltinID.leftPanel.rawValue,
            ]
        )

        let mainIDs = layout.items(in: .main).map(\.id)
        XCTAssertEqual(
            mainIDs.prefix(4).map { $0 },
            [
                ToolbarBuiltinID.newWindow.rawValue,
                ToolbarBuiltinID.newTab.rawValue,
                ToolbarBuiltinID.showAllTabs.rawValue,
                ToolbarBuiltinID.toggleTabBar.rawValue,
            ]
        )
        XCTAssertEqual(
            mainIDs[mainIDs.firstIndex(of: ToolbarBuiltinID.thumbnailView.rawValue)! + 1],
            ToolbarBuiltinID.panoramaView.rawValue
        )

        let trailingIDs = layout.items(in: .trailing).map(\.id)
        XCTAssertEqual(
            trailingIDs,
            [
                ToolbarBuiltinID.thumbnailSizeSlider.rawValue,
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

    func testMergeNewBuiltinItemsFromDefaultInsertsAfterAnchor() {
        var layout = ToolbarLayoutConfig.default
        layout.removeVisible(itemID: ToolbarBuiltinID.newFile.rawValue)

        layout.mergeNewBuiltinItemsFromDefault()

        let leadingIDs = layout.items(in: .leading).map(\.id)
        XCTAssertEqual(leadingIDs.first, ToolbarBuiltinID.newFile.rawValue)
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

    func testAddOpenShortcutsCreatesVisibleShortcut() throws {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        store.beginCustomization()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("toolbar-shortcut-\(UUID().uuidString).txt")
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let added = store.addOpenShortcuts(urls: [tempURL], zone: .main, at: 0)
        XCTAssertEqual(added, 1)

        let shortcut = try XCTUnwrap(store.workingLayout.customOpenShortcuts.first)
        let itemID = ToolbarItemIdentity.shortcutItemID(shortcut.id)
        XCTAssertEqual(shortcut.targetKind, .file)
        XCTAssertTrue(store.workingLayout.visibleIDSet.contains(itemID))
        XCTAssertEqual(store.workingLayout.items(in: .main).first?.id, itemID)
    }

    func testAddOpenShortcutsSkipsDuplicateVisiblePath() throws {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        store.beginCustomization()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("toolbar-shortcut-dup-\(UUID().uuidString).txt")
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertEqual(store.addOpenShortcuts(urls: [tempURL], zone: .main, at: 0), 1)
        XCTAssertEqual(store.addOpenShortcuts(urls: [tempURL], zone: .main, at: 0), 0)
        XCTAssertEqual(store.workingLayout.customOpenShortcuts.count, 1)
    }

    func testAddOpenShortcutsRelocatesFromPalette() throws {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        store.beginCustomization()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("toolbar-shortcut-palette-\(UUID().uuidString).txt")
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertEqual(store.addOpenShortcuts(urls: [tempURL], zone: .main, at: 0), 1)
        let shortcut = try XCTUnwrap(store.workingLayout.customOpenShortcuts.first)
        let itemID = ToolbarItemIdentity.shortcutItemID(shortcut.id)
        store.moveToPalette(itemID: itemID)
        XCTAssertFalse(store.workingLayout.visibleIDSet.contains(itemID))

        XCTAssertEqual(store.addOpenShortcuts(urls: [tempURL], zone: .trailing, at: 0), 1)
        XCTAssertEqual(store.workingLayout.customOpenShortcuts.count, 1)
        XCTAssertEqual(store.workingLayout.items(in: .trailing).first?.id, itemID)
    }

    func testLayoutConfigDecodesMissingShortcutsAsEmpty() throws {
        let json = """
        {
          "schemaVersion": 1,
          "visibleItems": [],
          "customOpenApps": []
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(ToolbarLayoutConfig.self, from: json)
        XCTAssertTrue(decoded.customOpenShortcuts.isEmpty)
    }

    func testClassifyShortcutKinds() {
        XCTAssertEqual(
            CustomOpenShortcutAction.classify(URL(fileURLWithPath: "/Applications/Safari.app")),
            .application
        )
        XCTAssertEqual(
            CustomOpenShortcutAction.classify(URL(fileURLWithPath: "/tmp", isDirectory: true)),
            .folder
        )
    }

    func testDeleteCustomOpenShortcutRemovesActionAndVisibleEntry() throws {
        let store = ToolbarCustomizationStore.shared
        store.loadIfNeeded()
        store.beginCustomization()

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("toolbar-shortcut-delete-\(UUID().uuidString).txt")
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        XCTAssertEqual(store.addOpenShortcuts(urls: [tempURL], zone: .main, at: 0), 1)
        let shortcut = try XCTUnwrap(store.workingLayout.customOpenShortcuts.first)
        let itemID = ToolbarItemIdentity.shortcutItemID(shortcut.id)

        store.deleteCustomOpenShortcut(id: shortcut.id)
        XCTAssertFalse(store.workingLayout.customOpenShortcuts.contains { $0.id == shortcut.id })
        XCTAssertFalse(store.workingLayout.visibleIDSet.contains(itemID))
    }
}

@MainActor
final class OpenShortcutExecutorTests: XCTestCase {
    func testMissingPathThrows() {
        let action = CustomOpenShortcutAction(
            displayName: "Gone",
            path: "/tmp/definitely-missing-toolbar-shortcut-\(UUID().uuidString).txt",
            targetKind: .file
        )
        XCTAssertThrowsError(try OpenShortcutExecutor.run(action, navigate: { _ in })) { error in
            XCTAssertEqual(error as? ToolbarActionError, .shortcutMissing("Gone"))
        }
    }

    func testFolderNavigates() throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("toolbar-shortcut-nav-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let action = CustomOpenShortcutAction.make(from: dir)
        XCTAssertEqual(action.targetKind, .folder)

        var navigated: String?
        try OpenShortcutExecutor.run(action, navigate: { navigated = $0 })
        XCTAssertEqual(navigated, dir.path)
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
