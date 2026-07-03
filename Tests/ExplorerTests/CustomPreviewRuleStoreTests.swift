import XCTest
@testable import Explorer

@MainActor
final class CustomPreviewRuleStoreTests: XCTestCase {
    private var defaultsKey: String { ExplorerAppSettings.customPreviewRulesKey }

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
        let store = CustomPreviewRuleStore.shared
        for rule in store.rules {
            store.deleteRule(id: rule.id)
        }
    }

    func testUpsertRuleSupplementsUnknownExtension() {
        let store = CustomPreviewRuleStore.shared
        store.upsertRule(forExtension: "proto", mode: .text)

        XCTAssertEqual(store.activeMode(for: "proto"), .text)
        XCTAssertNil(store.activeMode(for: "swift"))
    }

    func testSupplementRuleDoesNotOverrideBuiltIn() {
        let store = CustomPreviewRuleStore.shared
        store.upsertRule(forExtension: "swift", mode: .quickLook, overridesBuiltIn: false)

        XCTAssertNil(store.activeMode(for: "swift"))
        XCTAssertNil(store.overridingRule(for: "swift"))
        XCTAssertEqual(store.rule(forExtension: "swift")?.mode, .quickLook)
    }

    func testOverrideRuleReplacesBuiltIn() {
        let store = CustomPreviewRuleStore.shared
        store.upsertRule(forExtension: "md", mode: .text, overridesBuiltIn: true)

        XCTAssertEqual(store.activeMode(for: "md"), .text)
        XCTAssertEqual(store.overridingRule(for: "md")?.mode, .text)
    }

    func testRevisionIncrementsOnChange() {
        let store = CustomPreviewRuleStore.shared
        let initial = store.revision
        store.upsertRule(forExtension: "drawio", mode: .quickLook)
        XCTAssertEqual(store.revision, initial + 1)
    }

    func testImportExportRoundTrip() throws {
        let store = CustomPreviewRuleStore.shared
        let rule = CustomPreviewRule(extensions: ["env"], mode: .text)
        store.addRule(rule)

        let data = try store.exportJSON()
        resetStore()
        XCTAssertTrue(store.rules.isEmpty)

        try store.importJSON(data, merge: false)
        XCTAssertEqual(store.rules.count, 1)
        XCTAssertEqual(store.rules[0].normalizedExtensions, ["env"])
        XCTAssertEqual(store.rules[0].mode, .text)
    }

    func testPreviewTypeClassifierUsesCustomTextRule() {
        let store = CustomPreviewRuleStore.shared
        store.upsertRule(forExtension: "proto", mode: .text)

        XCTAssertTrue(PreviewTypeClassifier.isTextFile("proto"))
        XCTAssertFalse(PreviewTypeClassifier.isTextFile("bin"))
        XCTAssertTrue(PreviewTypeClassifier.isCodeFile("proto"))
    }

    func testPreviewTypeClassifierCodeVsPlainText() {
        XCTAssertTrue(PreviewTypeClassifier.isCodeFile("py"))
        XCTAssertTrue(PreviewTypeClassifier.isCodeFile("java"))
        XCTAssertTrue(PreviewTypeClassifier.isCodeFile("json"))
        XCTAssertFalse(PreviewTypeClassifier.isCodeFile("txt"))
        XCTAssertFalse(PreviewTypeClassifier.isCodeFile("md"))
        XCTAssertFalse(PreviewTypeClassifier.isCodeFile("log"))
    }

    func testPreviewTypeClassifierRunnableScriptTypes() {
        XCTAssertEqual(PreviewTypeClassifier.runnableScriptType(forExtension: "sh"), .shell)
        XCTAssertEqual(PreviewTypeClassifier.runnableScriptType(forExtension: "bash"), .shell)
        XCTAssertEqual(PreviewTypeClassifier.runnableScriptType(forExtension: "zsh"), .shell)
        XCTAssertEqual(PreviewTypeClassifier.runnableScriptType(forExtension: "py"), .python3)
        XCTAssertEqual(PreviewTypeClassifier.runnableScriptType(forExtension: "applescript"), .appleScript)
        XCTAssertEqual(PreviewTypeClassifier.runnableScriptType(forExtension: "scpt"), .appleScript)
        XCTAssertNil(PreviewTypeClassifier.runnableScriptType(forExtension: "swift"))
    }

    func testUpsertRuleSupportsExtensionlessFiles() {
        let store = CustomPreviewRuleStore.shared
        store.upsertRule(forExtension: "", mode: .text)

        XCTAssertEqual(store.activeMode(for: ""), .text)
        XCTAssertEqual(store.rule(forExtension: "")?.mode, .text)
        XCTAssertTrue(PreviewTypeClassifier.isTextFile(""))
    }

    func testExtensionlessTokenParsesFromSettingsInput() {
        let parsed = CustomPreviewRule.parseExtensions(from: "（无扩展名）, proto")
        XCTAssertEqual(parsed, [CustomPreviewRule.extensionlessKey, "proto"])
    }
}
