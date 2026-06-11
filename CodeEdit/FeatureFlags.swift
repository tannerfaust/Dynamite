//
//  FeatureFlags.swift
//  CodeEdit
//
// Compile-time gates for IDE surfaces parked pending Dynamite product relevance.
// Set a flag to `true` to restore the surface; delete the flag once the decision is permanent.
// All flags default to `false` = hidden / parked.
//
// Context: Dynamite is a product-cockpit app; the IDE is a secondary surface. Surfaces that
// exist purely for code-editing workflows (not product discovery/planning/context) are parked
// here so they can be restored quickly without a git revert.

enum FeatureFlags {
    // MARK: - App shell

    /// Enables the Cockpit/IDE two-view switcher (ADR-0006).
    ///
    /// - **Phase A (false — default):** `ShellViewController` wraps the split VC but builds only
    ///   the IDE child; no switcher UI, no ⌘1/⌘2, no keybinding remap. Pixel-identical to today.
    /// - **Phase B (true — dev):** switcher + `CockpitRootView` placeholder; default mode IDE;
    ///   ⌘1/⌘2 live; navigator tabs remapped to ⌃⌘1–⌘9.
    /// - **Phase C:** default mode flips to Cockpit for new projects; flag removed.
    static let cockpitView = true

    // MARK: - Menu items

    /// Editor > Structure submenu (Move Line Up / Down).
    /// Pure code-manipulation; not relevant to product-cockpit workflows.
    static let editorStructureMenu = false

    /// Extensions menu (Open Extensions Window).
    /// AppExtensionPoint system is experimental and out of Dynamite's current scope.
    static let extensionsMenu = false

    /// Help > "What's New in CodeEdit" and "Release Notes".
    /// CodeEdit upstream branding — not Dynamite's help surface.
    static let codeEditHelpItems = false

    /// Navigate > stub items that are already `.disabled(true)` in the menu
    /// ("Reveal Changes in Navigator", "Open in Next Editor", "Open in…").
    /// Dead weight — parked until implemented.
    static let navigateStubItems = false

    // MARK: - Utility area tabs

    /// Utility area — Debug Console tab (ladybug).
    /// Code-debugger output; not relevant to product work.
    static let utilityDebugConsoleTab = false

    /// Utility area — Output tab (build output).
    /// Build output; not relevant to product work.
    static let utilityOutputTab = false

    // MARK: - Settings pages

    /// Settings — Language Servers page.
    /// LSP configuration is an IDE-only concern; product layer doesn't need it.
    static let languageServersSettings = false
}
