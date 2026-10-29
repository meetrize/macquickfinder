import Testing
@testable import Explorer

@MainActor
struct RightPanelModeTests {
    private func makeLayout(
        mode: RightPanelMode = .auto,
        preview: Bool = true,
        snippets: Bool = true,
        git: Bool = false
    ) -> ExplorerWindowLayoutState {
        let defaults = UserDefaults(suiteName: "RightPanelModeTests.\(UUID().uuidString)")!
        defaults.removePersistentDomain(forName: "RightPanelModeTests")
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        layout.setRightPanelMode(mode)
        layout.showPreview = preview
        layout.showSnippets = snippets
        layout.showGit = git
        return layout
    }

    @Test func autoHidesEverythingWithoutSelection() {
        let layout = makeLayout(mode: .auto)
        let effective = layout.effectiveRightPanelVisibility(hasSelection: false)
        #expect(effective.showPreview == false)
        #expect(effective.showSnippets == false)
        #expect(effective.showGit == false)
        #expect(layout.isRightPanelEffectivelyVisible(hasSelection: false) == false)
        // 期望值（上次组合）不受影响，仍持久化。
        #expect(layout.showPreview == true)
        #expect(layout.showSnippets == true)
    }

    @Test func autoRestoresLastCombinationWithSelection() {
        let layout = makeLayout(mode: .auto, preview: true, snippets: false, git: true)
        let effective = layout.effectiveRightPanelVisibility(hasSelection: true)
        #expect(effective.showPreview == true)
        #expect(effective.showSnippets == false)
        #expect(effective.showGit == true)
        #expect(layout.isRightPanelEffectivelyVisible(hasSelection: true) == true)
    }

    @Test func pinnedIgnoresSelection() {
        let layout = makeLayout(mode: .pinned, preview: true, snippets: false, git: false)
        let hidden = layout.effectiveRightPanelVisibility(hasSelection: false)
        #expect(hidden.showPreview == true)
        #expect(layout.isRightPanelEffectivelyVisible(hasSelection: false) == true)
    }

    @Test func previewToggleKeepsPreferenceWhenAutoHidden() {
        let layout = makeLayout(mode: .auto, preview: false, snippets: true)
        let applied = layout.setPreviewVisible(true, hasSelection: false)
        #expect(applied == false)
        #expect(layout.showPreview == true)
        let effective = layout.effectiveRightPanelVisibility(hasSelection: true)
        #expect(effective.showPreview == true)
        #expect(effective.showSnippets == true)
    }

    @Test func defaultModeIsAuto() {
        let defaults = UserDefaults(suiteName: "RightPanelModeTests.default.\(UUID().uuidString)")!
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        #expect(layout.rightPanelMode == .auto)
    }

    @Test func syncsModeFromDefaultsImmediately() {
        let suiteName = "RightPanelModeTests.sync.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let layout = ExplorerWindowLayoutState(defaults: defaults)
        #expect(layout.rightPanelMode == .auto)

        defaults.set(RightPanelMode.pinned.rawValue, forKey: AppPreferences.Layout.rightPanelMode)
        layout.syncRightPanelModeFromDefaultsIfNeeded()
        #expect(layout.rightPanelMode == .pinned)

        layout.toggleRightPanelAutoHide()
        #expect(layout.rightPanelMode == .auto)
        #expect(defaults.string(forKey: AppPreferences.Layout.rightPanelMode) == RightPanelMode.auto.rawValue)
    }
}
