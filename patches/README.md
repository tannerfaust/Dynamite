# Editor resize-performance patches

These patches fix the severe few-FPS stutter seen when resizing the Dynamite
window, dragging split-view dividers, or expanding/collapsing sidebars with a
real workspace open.

The issue is not primarily the macOS 26/Tahoe styling. The styling makes the
window visually different, but profiling showed the lag comes from several
resize-time layout paths that compound once the editor, jump bar, terminal, and
side panes are all present.

## Measured root causes

1. **SwiftUI split panes exported expensive intrinsic sizing into AppKit.**
   `NSHostingController` instances inside `NSSplitViewItem`s allowed SwiftUI
   min/intrinsic/max sizing to feed back into AppKit during live resize. AppKit
   repeatedly asked large hosted subtrees for fitting sizes, producing hot stacks
   through `NSHostingView.minSize()` and editor/sidebar body reconstruction.

2. **CodeEditSourceEditor find panel used resize-heavy hosted sizing.**
   The find panel was an `NSHostingView` whose fitting-size computation walked
   through `FindPanelView`, `ViewThatFits`, and `FindMethodPicker` during live
   resize. That made a tiny panel part of the resize hot path.

3. **CodeEditTextView re-typeset visible lines on every AppKit layout pass.**
   With Wrap Lines enabled, every live resize frame changed
   `maxLineLayoutWidth`, making `TextView.layout()` call
   `TextLayoutManager.layoutLines()` and re-typeset visible lines as often as
   AppKit asked for layout. The fix keeps wrapping under explicit scheduler
   control and updates live at a bounded cadence.

4. **CodeEditTextView minted cryptographic UUIDs per line fragment.**
   During the re-typeset storm, `LineFragment` and `TextLine` each called
   `UUID()`, which hit the system CSPRNG thousands of times.

5. **SwiftTerm terminal grid/buffer resize ran every AppKit frame.**
   When the terminal utility pane was visible, `CETerminalView.frame` forwarded
   every live resize frame into SwiftTerm's `Terminal.resize` and `Buffer.resize`.
   The fix throttles those expensive grid updates so terminal text changes
   during resize without overwhelming the main thread.

6. **Editor chrome animated layout state on every resize frame.**
   The jump bar animated every measured width change, and the tab bar enqueued
   animated `scrollTo` work on each window-width change.

## Fixes in the app

- Split-pane hosting controllers now disable AppKit sizing export with
  `NSHostingController.sizingOptions = []` on macOS 13+.
- Split-view items are only replaced when child identities actually change.
- The terminal view updates its visual frame immediately and throttles the
  expensive terminal grid resize during live resize, then applies a final exact
  grid resize when the drag ends.
- The jump bar now treats resize truncation as layout state instead of an
  animation stream.
- The tab bar debounces selected-tab scroll correction during resize and avoids
  storing per-tab global geometry when no tab is being dragged.

## Fixes in package patches

`codeedittextview-resize-perf.patch` targets CodeEditTextView 0.12.1
(`d7ac3f1`):

- Adds `frozenWrapWidth` so wrapped text does not re-typeset from every AppKit
  layout pass.
- Adds a bounded live re-wrap scheduler so wrapped text still changes during
  resize at a controlled rate, with a final exact re-wrap after the width
  settles.
- Adds `FastID.next()` to avoid CSPRNG-backed `UUID()` in hot line-fragment
  constructors.
- Guarantees typesetting forward progress for unsized or zero-width views so
  minimap/window-restoration paths cannot spin forever.

`codeeditsourceeditor-resize-perf.patch` targets CodeEditSourceEditor
(`ee0c00a`):

- Replaces the find-panel `NSHostingView` with a lightweight container view and
  hosted controller whose sizing options are disabled.
- Provides cheap explicit intrinsic/fitting sizes from `panelHeight`.
- Keeps the height constraint in sync with find mode changes instead of asking
  SwiftUI to recompute fitting size during every resize pass.

`codeeditsourceeditor-highlight-startup-perf.patch` also targets
CodeEditSourceEditor (`ee0c00a`):

- Builds the initial Tree-sitter state synchronously for documents under the
  package's existing synchronous-content threshold.
- Invalidates visible highlight ranges immediately when providers are installed,
  so the first editor paint does not wait for a later scroll or frame-change
  notification before requesting syntax colors.
- Refreshes visible highlight ranges again as the editor view appears, after
  AppKit has resolved the scroll view and text view geometry.
- Ignores stale async highlight results from providers that have already been
  removed, avoiding debug-build crashes in standalone document windows.
- Preserves the asynchronous setup path for large files.
- Maps additional Tree-sitter capture names used by modern grammars (for example
  `function.call`, `operator`, `constant.builtin`) so standalone markdown and
  code windows get complete syntax coloring instead of unstyled tokens.
- Routes functions and methods to the theme's command color and booleans or
  builtins to the value color, matching the main workspace editor appearance.

## Durability

The dependency patches are applied to Swift Package checkout sources and are
compiled into the built app. If you reset Swift package caches or delete
DerivedData, reapply them before building:

```sh
./scripts/apply-editor-perf-patch.sh
```

For a zero-maintenance solution, vendor `CodeEditTextView` and
`CodeEditSourceEditor` as local Swift packages and point the Xcode project at
those local package paths instead of remote package URLs.
