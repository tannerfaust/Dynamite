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

- Adds `FastID.next()` to avoid CSPRNG-backed `UUID()` in hot line-fragment
  constructors (the dominant cost of the resize re-typeset storm).
- Guarantees typesetting forward progress for unsized or zero-width views so
  minimap/window-restoration paths cannot spin forever (the launch-hang fix).
- **Fixes "ghost" duplicated text on wrapped lines** (the next line's first word
  appearing clipped at the end of the line above it, and an unreliable/unclickable
  right edge). **The actual root cause is in `Typesetter.layoutTextUntilLineBreak`:**
  `suggestLineBreak` returns an *offset relative to the run start* (`start + count`),
  but the code used it as the CTLine *length* — so every wrapped fragment after a
  run's first was built `start` characters too long. The oversized CTLine re-drew the
  next row's text past the break point (visible as duplicated text clipped at the
  right edge on lines wrapped to **3+ rows**; the last fragment self-clamps, which is
  why 2-row wraps looked fine) and corrupted hit-testing near the wrap boundary
  (clicks in the overflow region resolved to the next row's characters). Fixed by
  computing `fragmentLength = lineBreak - runRelativeStart` and using that as the
  CTLine length (and in the 0-fit pop-retry check, which previously compared the
  absolute offset to `1`). Regression test:
  `TypesetterTests.test_wrappedFragmentCTLinesMatchFragmentRanges` asserts every
  fragment's CTLine range equals the fragment's range exactly.

  Two earlier mitigations in this patch treated symptoms of the same bug and are
  kept as hardening: `ViewReuseQueue` always removes retired fragment views from
  the view hierarchy, and `LineFragmentView` gets its own backing layer.
  Reproduces on **pristine upstream CodeEditTextView 0.12.1**, so this is an
  upstream bug, not Dynamite's.

  **Note:** earlier versions of this patch added a `frozenWrapWidth` + deferred
  re-wrap scheduler (removed — it left text wrapped at a stale width) and a
  `maxLineLayoutWidth` width>0 guard (removed — it forced a momentarily-unsized
  line to typeset *unwrapped* as one wide fragment, feeding the ghost bug;
  upstream instead makes a harmless empty placeholder via the typesetter's
  `maxWidth <= 0` fast path). Resize stays smooth from `FastID` + async
  highlighting + minimap-off.

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
  synchronous-content threshold (`Constants.maxSyncContentLength`).
- Lowers that threshold from the upstream `1_000_000` to `100_000`. At 1MB,
  opening or growing a file of a few hundred KB ran a full synchronous
  Tree-sitter parse (and a synchronous highlight query on `setUp`) on the main
  thread, stalling the UI for hundreds of milliseconds — the "open a big file →
  freeze / animations jam" report. Documents above ~100KB now parse, query, and
  apply edits on the background executor (the same async path >1MB files already
  used); the visible range colors in a frame or two later. A brief uncolored
  flash on a large file is far cheaper than a frozen UI.
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
- Fixes the minimap rendering blank ("shows nothing yet there is content") and
  the visible-region box desynchronizing at certain sizes. Both stemmed from one
  guard in `MinimapView.updateContentViewHeight()` (`height < textView.frame.height`)
  that mis-fired during early layout when the editor frame height was still 0,
  leaving the minimap content view stuck at 1px. Replaced with a positive/finite
  height check; the existing `!=` guard still prevents layout loops. (The minimap
  is also now off by default in the app — it runs a second layout engine — but
  this makes it correct for users who re-enable it.)
- **Fixes the unclickable right-edge dead zone when the minimap is hidden.**
  `MinimapView.hitTest(_:)` is a custom override, which bypasses AppKit's
  built-in hidden-view check — so a minimap hidden via "Show Minimap" off still
  claimed every click inside its ~140pt frame floating over the editor's right
  edge, and its overridden `mouseDown`/`mouseDragged` (which intentionally eat
  events) silently swallowed them. Verified live via `lldb` hit-testing: points
  on the right edge returned the hidden `MinimapView` instead of the text view.
  Fixed with a `!isHidden` guard at the top of `hitTest`.

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
