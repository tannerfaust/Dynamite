# Dynamite (CodeEdit) Internals

This document covers the end-to-end architecture of Dynamite (a CodeEdit fork) across key subsystems.

## 1. CEWorkspace
*   **Responsibilities:** Lazily load and cache the project's file hierarchy, model files and directories, and stream file system events.
*   **Key Types:** [`CEWorkspaceFileManager`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/CEWorkspace/Models/CEWorkspaceFileManager.swift) (central file cache/watcher), [`CEWorkspaceFile`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/CEWorkspace/Models/CEWorkspaceFile.swift) (node representing a file/folder), `DirectoryEventStream`.
*   **State Flow:** `CEWorkspaceFileManager` is initialized with a root URL. `getFile` or `childrenOfFile` lazily populates `childrenMap` and `flattenedFileItems`. FSEvents update the tree via listeners.
*   **Extension Points:** Conforming to `CEWorkspaceFileManagerObserver` to react to structural file changes.
*   **Pitfalls:** Forcing a full tree load (e.g. searching without limits) can stall the app due to massive memory use. File operations must be routed through the manager to keep the cache synced.

## 2. Documents
*   **Responsibilities:** Bridge AppKit's `NSDocument` model to CodeEdit's workspace architecture, housing all major managers.
*   **Key Types:** [`WorkspaceDocument`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/Documents/WorkspaceDocument/WorkspaceDocument.swift).
*   **State Flow:** `read(from:ofType:)` initializes `CEWorkspaceFileManager`, `SourceControlManager`, `UtilityAreaViewModel`, etc. UserDefaults stores window bounds and tool panel collapse states via `WorkspaceStateKey`.
*   **Extension Points:** Adding properties directly to `WorkspaceDocument` creates new globally-available subsystem instances.
*   **Pitfalls:** `WorkspaceDocument` acts as a massive "God Object" holding all state; deinit memory leaks are common if cancellables or delegates aren't explicitly cleaned up in `close()`.

## 3. Window & Controller Architecture
*   **Responsibilities:** Define the top-level layout (sidebar, main content, inspector) and handle macOS window actions.
*   **Key Types:** [`CodeEditWindowController`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/Documents/Controllers/CodeEditWindowController.swift), [`CodeEditSplitViewController`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/Documents/Controllers/CodeEditSplitViewController.swift).
*   **State Flow:** `WorkspaceDocument` creates the `CodeEditWindowController`. It uses an `NSSplitViewController` to host `NavigatorAreaView`, `WorkspaceView`, and `InspectorAreaView`.
*   **Extension Points:** Swapping the SwiftUI `rootView` of the split panes.
*   **Pitfalls:** Highly rigid 3-pane constraints. `CodeEditSplitViewController` uses hardcoded dimensions and `NSSplitView` delegate hacks for spring-loading, making dynamic layout modifications difficult.

## 4. SourceControl
*   **Responsibilities:** Expose Git features (commit, branch, push, stash) to the UI.
*   **Key Types:** [`SourceControlManager`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/SourceControl/SourceControlManager.swift), `GitClient`.
*   **State Flow:** Initializes via `GitClient(directoryURL:)`. Changes are fetched via shell commands and stored in published properties like `changedFiles` and `currentBranch`.
*   **Extension Points:** Commands rely on `GitClient` invoking the global `shellClient`.
*   **Pitfalls:** All git commands block or shell out async; concurrency issues arise if multiple refresh tasks run simultaneously.

## 5. InspectorArea
*   **Responsibilities:** The right-hand sidebar for context-sensitive tool tabs (e.g., File Info, History).
*   **Key Types:** [`InspectorAreaViewModel`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/InspectorArea/ViewModels/InspectorAreaViewModel.swift), `InspectorTab`.
*   **State Flow:** Maintains `@Published var selectedTab: InspectorTab?`. The main view switches content based on the active tab.
*   **Extension Points:** Adding cases to the `InspectorTab` enum and registering the corresponding view.
*   **Pitfalls:** Tight coupling between the `enum` definitions and the View switch statements requires boilerplate to add new panels.

## 6. UtilityArea
*   **Responsibilities:** Bottom drawer panel for persistent tasks like Terminal and Debugger.
*   **Key Types:** [`UtilityAreaViewModel`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/UtilityArea/ViewModels/UtilityAreaViewModel.swift), `UtilityAreaTerminal`, `UtilityAreaTab`.
*   **State Flow:** Tracks terminal instances, drawer dimensions (`currentHeight`), and toggle state (`isMaximized`, `isCollapsed`).
*   **Extension Points:** Expanding `UtilityAreaTab` or injecting new tools like `TerminalCache` wrappers.
*   **Pitfalls:** Re-ordering or closing terminal tabs requires manual lifecycle cleanup (managing `TerminalCache` references and sending UNIX `SIGKILL`s to zombies).

## 7. Settings
*   **Responsibilities:** App-wide (`CodeEdit`) and workspace-level settings.
*   **Key Types:** [`SettingsData`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/Settings/Models/SettingsData.swift), [`CEWorkspaceSettingsData`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/CEWorkspaceSettings/Models/CEWorkspaceSettingsData.swift).
*   **State Flow:** Saved as JSON on disk, decoded into `SettingsData`, and injected via the `\.settings` SwiftUI Environment key. Workspace settings load from `.codeedit/settings.json`.
*   **Extension Points:** Extending `SettingsData` requires matching defaults in `init(from decoder:)`.
*   **Pitfalls:** Forgetting to handle `decodeIfPresent` results in corrupt or overwritten settings dictionaries. Changes to App-wide settings apply instantly to all open windows.

## 8. Extensions
*   **Responsibilities:** Load 3rd-party/internal plugins using Apple's `ExtensionFoundation`.
*   **Key Types:** [`ExtensionManager`](file:///Users/mediaalamedia/dynamite/CodeEdit/Features/Extensions/ExtensionsManager.swift), `ExtensionDiscovery`, `ExtensionInfo`.
*   **State Flow:** `ExtensionDiscovery` populates available plugins which are published via `ExtensionManager.shared.extensions`.
*   **Extension Points:** Built around `AppExtensionPoint` architectures.
*   **Pitfalls:** Highly experimental. Sandboxing limits what extensions can access without explicit entitlements or permissions.

---

## What to reuse vs. avoid for:

### (a) A standalone product-doc workspace
*   **Reuse:** `CEWorkspaceFileManager` for lazy-loading folders and tracking `.md` file updates, and `WorkspaceDocument` for the core saving and state-restoration shell.
*   **Avoid:** Code-editor specific subsystems like `EditorManager`, `LSPService`, or `SourceControlManager` (unless Git syncing is a core product requirement). Strip out these managers from the NSDocument lifecycle.

### (b) A second top-level view mode per window
*   **Reuse:** The `CodeEditWindowController` architecture.
*   **Avoid:** Trying to shove new view modes inside `CodeEditSplitViewController`. Its 3-pane setup is deeply baked in with hardcoded min-widths and constraints. Instead, build a container view *above* the split view (in `CodeEditWindowController`'s content view setup) that toggles between the `NSSplitViewController` and your new top-level mode.

### (c) A backlinks inspector panel
*   **Reuse:** `InspectorAreaViewModel`. It's cleanly separated from the main content and left navigator.
*   **Avoid:** Creating a brand new floating panel or a separate sidebar architecture. Instead, simply extend the `InspectorTab` enum with a `backlinks` case and bind its SwiftUI View to the existing `InspectorAreaView` body.
