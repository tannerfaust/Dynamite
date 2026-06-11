# Performance Audit & Development Plan — IDE Side

> Date: 2026-06-11. Scope: IDE-side performance and the four reported bugs. Cockpit/product layer intentionally out of scope. Each task below is **one prompt for one AI model**, with the model chosen for token economy. Tasks are ordered; respect the dependency notes.

---

## Part 1 — Audit findings

### F1. The patch system is the root cause of bugs #2 and #3 still being visible

The repo already diagnosed and patched the two markdown bugs (`patches/README.md`):

- **Word duplicated across wrapped lines** ("ghost" text) and the **unclickable right edge** are one upstream bug in **CodeEditTextView 0.12.1** `ViewReuseQueue`: retired line-fragment views were kept in the view hierarchy as hidden subviews and resurface, rendering on top of the current layout and eating hit-tests. Reproduces on pristine upstream. Upstream's latest release is *still* 0.12.1 (checked 2026-06-11) — no upstream fix exists.
- The fix exists in `patches/codeedittextview-resize-perf.patch` and **is applied** to `.SourcePackages/checkouts/CodeEditTextView` (verified: `ViewReuseQueue.swift` removes retired views; `LineFragmentView` has per-fragment layers; `FastID` present).

**Conclusion:** since the bugs still appear at runtime, the running binary is almost certainly built from an **unpatched** package copy (Xcode resolves packages into DerivedData; "Reset Package Caches"/DerivedData wipes silently restore broken upstream sources). Patch-on-checkout is structurally fragile. The fix is to **vendor** the two packages as local Swift packages with the patches baked in (the patches README itself recommends this). → Tasks T0.1, T0.2, T1.1.

### F2. Custom WYSIWYG markdown editor (Dynamite code) has its own correctness + perf bugs

`CodeEdit/Features/Editor/MarkdownEditor/` (used when Markdown Preview ⇧⌘R is on):

- `MarkdownEditorView.makeNSView` hardcodes `width: 600` for `MarkdownTextView`; the text view does not reliably track the clip-view width → **dead, unclickable region to the right** of the 600pt column.
- `MarkdownTextView.applyStyling()` runs on **every keystroke and every caret move** (`didChangeText` + `setSelectedRanges`), and does: `setAttributes` over the **entire document**, a regex pass over **every line** (`MarkdownSyntaxStyler.applyStyles`), then `invalidateGlyphs(forCharacterRange: fullRange)`. O(document) per keystroke; on large docs this is the lag, and glyph invalidation without matching layout invalidation is a second plausible source of duplicated/ghost line rendering in TextKit 1.
- Every keystroke is also mirrored synchronously into a second `NSTextStorage` (the `CodeFileDocument` content) — double work per keystroke.

### F3. Tab switching / file open is synchronous and rebuilds the world (inherited)

- `Editor.openFile` → `CEWorkspaceFile.loadCodeFile()` → `CodeFileDocument(contentsOf:)` — **synchronous file read on the main thread** on every click in the navigator.
- Tab switch swaps `EditorAreaFileView(editorInstance:)` identity → SwiftUI **tears down and rebuilds the entire editor** (`CodeFileView` → new `TextViewController`, full text layout, full Tree-sitter re-parse). No per-tab editor caching (Xcode keeps these alive).
- `CodeFileView` allocates **two** `TreeSitterClient` instances per init (`treeSitterClient` and unused duplicate `treeSitter`) — and SwiftUI `@State` initial values are computed on *every* init of the struct, i.e. on every parent body evaluation.
- `CodeFileView` observes ~20 separate `@AppSettings` keys; any settings write invalidates every open editor.
- `EditorAreaFileView.onHover` pushes/pops `NSCursor` via `DispatchQueue.main.async` per hover event.

### F4. Big-project lag: FSEvents → main-thread IO → outline-view reload storms (inherited)

`CEWorkspaceFileManager+DirectoryEvents.swift` / `SourceControlManager+GitClient.swift` / `ProjectNavigatorOutlineView.swift`:

- `fileSystemEventReceived` does **all** work on the main thread: `FileManager.contentsOfDirectory` (sync IO), child diffing, and sorting, per event batch. With an agent (Claude Code/Codex) writing files or a build running, FSEvents storms translate directly into main-thread stalls — this is the "big project = laggy animations, sidebar, resizing" feel.
- `rebuildFiles` is O(children²): `Array.contains` inside loops over directory contents.
- **Every** non-`.git` file change triggers `refreshAllChangedFiles()` → spawns `git status` → `refreshStatusInFileManager()` iterates **all** of `flattenedFileItems` (entire indexed tree) and then calls `notifyObservers` with the full updated set → `fileManagerUpdated` calls `outlineView.reloadItem($0, reloadChildren: true)` **per item** on the main thread. In a large repo this is thousands of row reloads per FS batch.
- Settings observers (`iconColor`, `rowHeight`) call full `outlineView.reloadData()`.

### F5. Resize/animation work already done — keep it, verify it

The app-side resize fixes (hosting-controller `sizingOptions = []`, terminal grid resize throttling, jump-bar/tab-bar animation fixes) and the package patches (FastID, async highlight init, 100KB sync-parse threshold) are good engineering and address the resize-stutter class. They only fully count once the build provably contains them (T0.1) and survive package resets (T0.2).

### Out of scope (per instructions)

Run/play-button surfaces (`Features/Tasks` UI), Cockpit/product layer, anything slated for deletion.

---

## Part 2 — Development plan

One task = one prompt = one model. Acceptance criteria are part of each prompt. Every task must end with: build passes, SwiftLint clean, no new violations.

**Model economy rationale:** trivial mechanical edits → Composer 2.5 / Gemini 3.5 High flash / GPT 5.5 Low. Focused single-subsystem refactors → Sonnet 4.6 / GPT 5.5 Medium–High. Cross-cutting concurrency or AppKit/SwiftUI lifecycle architecture (expensive to get wrong) → Opus 4.8 / Fable 5. Analysis/report writing over large context → Gemini 3.1 pro.

### Dependency order

```
T0.1 → T0.2 → T1.1 (verify ghost bug fixed before deeper work)
T0.3 (instrumentation) before Phase 2 measurement claims
T1.4 → T1.5 (async open before/alongside editor caching)
T2.1 → T2.3 → T2.4 (event pipeline before UI batching before git batching)
Everything else independent.
```

---

### Phase 0 — Ground truth & build hygiene

#### T0.1 — Verify the running build contains the editor patches
**Model:** Composer 2.5 · **Effort:** trivial/agentic · **Files:** `scripts/apply-editor-perf-patch.sh`, DerivedData

**Prompt:**
> In the Dynamite repo, verify that the editor performance patches are present in every package checkout the build can use, then produce a clean build. Steps: (1) Run `./scripts/apply-editor-perf-patch.sh` and capture its output — it patches both `.SourcePackages/checkouts/` and any `~/Library/Developer/Xcode/DerivedData/Dynamite-*/SourcePackages/checkouts/` copies, and skips already-patched checkouts. (2) For each checkout of CodeEditTextView found, verify `Sources/CodeEditTextView/Utils/ViewReuseQueue.swift` contains the comment "Always remove a retired view" and `Sources/CodeEditTextView/TextLine/FastID.swift` exists. (3) Build the Dynamite scheme (Debug) from a clean state. (4) Report which checkouts were unpatched before you started — that tells us whether the user's "word duplicates on wrapped lines" and "unclickable right edge in markdown" bugs were simply a stale/unpatched build. Acceptance: all checkouts patched, build succeeds, report written to `Dynamite Docs/reports/T0.1-patch-verification.md`.

#### T0.2 — Vendor CodeEditTextView & CodeEditSourceEditor as local packages
**Model:** Sonnet 4.6 (medium reasoning) · **Files:** `Dynamite.xcodeproj`, new `LocalPackages/`, `patches/`, `scripts/`

**Prompt:**
> In the Dynamite repo (macOS Swift app, forked from CodeEdit), convert two remote SPM dependencies into vendored local packages so our patches can never be silently lost to a package-cache reset. (1) Copy the **already-patched** checkouts `.SourcePackages/checkouts/CodeEditTextView` (0.12.1 + `patches/codeedittextview-resize-perf.patch`) and `.SourcePackages/checkouts/CodeEditSourceEditor` (0.15.1 + both sourceeditor patches) into `LocalPackages/CodeEditTextView` and `LocalPackages/CodeEditSourceEditor`. Strip their `.git` dirs; add a `VENDORED.md` to each noting upstream version, commit, and applied patches. (2) In `Dynamite.xcodeproj`, replace the remote package references for these two packages with local package references to those paths. CodeEditSourceEditor's dependency on CodeEditTextView must resolve to the local copy — update its `Package.swift` dependency to a relative local path. Other deps (CodeEditLanguages, etc.) stay remote. (3) Verify `swift package describe` works in each local package and the app builds clean. (4) Update `patches/README.md`: patches are now baked into `LocalPackages/`, the apply script is retired for these two packages (keep it for reference). (5) Update `CLAUDE.md` Tech stack section with one line about `LocalPackages/`. Acceptance: clean build with NO checkout of CodeEditTextView/CodeEditSourceEditor in `.SourcePackages/checkouts` being compiled; ghost-text fix (`ViewReuseQueue` "Always remove a retired view") present in compiled sources; SwiftLint clean.

#### T0.3 — Performance instrumentation: signposts + a big-repo stress fixture
**Model:** GPT 5.5 (Medium) · **Files:** new `CodeEdit/Utils/PerfSignposts.swift`, `CodeEditTests`, `scripts/`

**Prompt:**
> Add lightweight performance instrumentation to the Dynamite macOS app so regressions are measurable in Instruments. (1) Create `CodeEdit/Utils/PerfSignposts.swift` with a thin `OSSignposter` wrapper (subsystem `app.dynamite.perf`) exposing static categories: `fileOpen`, `tabSwitch`, `fsEvents`, `gitStatus`, `outlineReload`, `markdownStyle`. (2) Instrument these exact spots with interval signposts: `Editor.openFile(item:)` (Features/Editor/Models/Editor/Editor.swift), `CEWorkspaceFile.loadCodeFile()`, `CEWorkspaceFileManager.fileSystemEventReceived(events:)` (annotate event count), `SourceControlManager.refreshAllChangedFiles()`, `ProjectNavigatorOutlineView` `fileManagerUpdated` (annotate item count), and `MarkdownTextView.applyStyling()` (annotate document length). (3) Add `scripts/make-stress-fixture.sh` that generates a throwaway repo with 10,000 files across 800 dirs, a git history, and a 2MB markdown file, for manual profiling. (4) No behavior changes; signposts must be no-ops in release if `#if DEBUG` is the repo convention — match surrounding style. Acceptance: build + lint clean; `xcrun xctrace` can record the signposts; brief usage notes in `Dynamite Docs/reports/T0.3-instrumentation.md`.

---

### Phase 1 — The four reported bugs

#### T1.1 — Regression-test the wrapped-line ghost bug & unclickable right edge
**Model:** Opus 4.8 (high reasoning) · **Depends on:** T0.2 · **Files:** `LocalPackages/CodeEditTextView`

**Prompt:**
> In the vendored `LocalPackages/CodeEditTextView` (patched fork of upstream 0.12.1) inside the Dynamite repo: the historical bug was that retired line-fragment views queued in `ViewReuseQueue` stayed in the view hierarchy and resurfaced, drawing duplicated "ghost" words on wrapped lines and blocking clicks near the right edge. Our patch removes retired views from their superview (`enqueueView(forKey:)`) and gives fragments their own backing layers (`LineFragmentView.configureLayer`). Your job: (1) Write unit tests in the package's test target proving: after `enqueueView`, the view has no superview; after `enqueueViews(notInSet:)` during a simulated re-wrap (width change on a wrapped multi-line document via `TextLayoutManager`), no two visible `LineFragmentView`s overlap in frame and every visible fragment's `lineFragment` range is disjoint. (2) Audit the full re-wrap path for any *other* place a stale fragment view could remain visible or hit-testable: `TextLayoutManager.layoutLines`, fragment view positioning, `ViewReuseQueue` callers, and `LineFragmentView.hitTest` (returns nil — confirm the text view itself, not fragments, owns hit-testing all the way to the scroll view's right edge when `wrapLines` is on; specifically verify the text view's frame width equals the clip view width under wrapping so there is no dead strip). (3) Fix anything you find, smallest possible diffs, comment why. Do not refactor unrelated code. Acceptance: new tests pass, existing package tests pass, Dynamite app builds; write findings to `Dynamite Docs/reports/T1.1-ghost-audit.md`.

#### T1.2 — Markdown WYSIWYG editor: kill the hardcoded 600pt width / dead click zone
**Model:** Gemini 3.5 High flash · **Files:** `CodeEdit/Features/Editor/MarkdownEditor/MarkdownEditorView.swift`, `MarkdownTextView.swift`

**Prompt:**
> In the Dynamite macOS app, `MarkdownEditorView.makeNSView` creates `MarkdownTextView(theme:initialText:width: 600)` as the document view of an `NSScrollView`. The hardcoded 600pt width leaves an unclickable dead region to the right of the text column. Fix: the text view must always fill the scroll view's content width. (1) In `makeNSView`, after setting `documentView`, set the text view frame to the clip view bounds width and ensure `autoresizingMask = [.width]` actually takes effect (set `scrollView.contentView.autoresizesSubviews = true` if needed, or observe `NSView.frameDidChangeNotification` on the clip view and update the text view frame width). (2) Keep `textContainer.widthTracksTextView = true` so wrapping follows. (3) If a centered readable column is desired later, that's a `textContainerInset` concern — do NOT implement it now; full-width is the goal. (4) Remove the now-meaningless `width` init parameter or default it from the scroll view. Test: open a `.md` file with Markdown Preview on, resize the window — clicking anywhere right of the text places the caret on that line, and text re-wraps to the new width. Match surrounding SwiftUI/AppKit style; SwiftLint clean.

#### T1.3 — Markdown WYSIWYG editor: incremental restyling instead of whole-document passes
**Model:** GPT 5.5 (High) · **Files:** `MarkdownTextView.swift`, `MarkdownSyntaxStyler.swift`, `MarkdownConcealLayoutDelegate.swift`

**Prompt:**
> In the Dynamite macOS app's live markdown editor (`CodeEdit/Features/Editor/MarkdownEditor/`, TextKit 1): `MarkdownTextView.applyStyling()` currently runs on every keystroke (`didChangeText`) and every caret-paragraph change (`setSelectedRanges`), doing `setAttributes` over the full document, a regex pass over every line (`MarkdownSyntaxStyler.applyStyles`), then `layoutManager.invalidateGlyphs(forCharacterRange: fullRange)`. This is O(document) per keystroke and the blunt glyph invalidation without paired layout invalidation risks stale/duplicated line rendering. Refactor to incremental: (1) Add `MarkdownSyntaxStyler.applyStyles(to:in range:revealedParagraph:)` that styles only a given character range, where the range is expanded to whole paragraphs; keep the existing full-document method for initial load/theme change/`replaceContents`. Fenced code blocks make line styling context-dependent — maintain a cached line-index → in-fence flag (recomputed lazily from the nearest fence above the edit; full rescan only when a line containing a fence marker (``` or ~~~) is itself edited). (2) On `didChangeText`, restyle only the edited paragraph range (from `NSTextStorage` edited range, extended to paragraph boundaries). On caret paragraph change, restyle only the previously-revealed paragraph and the newly-revealed paragraph (concealment toggling), not the document. (3) Replace `invalidateGlyphs(fullRange)` with `invalidateGlyphs` + `invalidateLayout(forCharacterRange:actualCharacterRange:)` on exactly the restyled ranges — both calls, paired, to prevent stale line fragments. (4) Keep `applyStyles`'s attribute semantics identical (the conceal delegate depends on `.markdownConceal`). Acceptance: typing in a 1MB markdown file shows no full-document signpost (`markdownStyle` signpost from T0.3 reports range length ≪ doc length); bold/heading/fence rendering identical before/after on the repo's own `Dynamite Docs/*.md` files; no ghost or mis-wrapped lines after rapid editing around line-wrap boundaries; build + lint clean.

#### T1.4 — Open files asynchronously (kill main-thread file IO on navigator click)
**Model:** Opus 4.8 (medium reasoning) · **Files:** `Editor.swift`, `CEWorkspaceFile.swift`, `EditorAreaView.swift`, `CodeFileDocument`

**Prompt:**
> In the Dynamite macOS app (CodeEdit fork), clicking a file in the project navigator runs `Editor.openFile(item:)` → `CEWorkspaceFile.loadCodeFile()` → `CodeFileDocument(contentsOf:ofType:)` — a synchronous disk read + string decode on the main thread. Large files visibly freeze the UI; this is the biggest cause of "slow tabs". Make file opening async while preserving NSDocument semantics: (1) Add `CEWorkspaceFile.loadCodeFileAsync() async throws` that performs `CodeFileDocument(contentsOf:ofType:)` on a background task (NSDocument init with contentsOf is thread-safe for reading; registration with `CodeEditDocumentController.shared.addDocument` and the `fileDocument` assignment must hop back to `@MainActor`). (2) In `Editor.openFile(item:)`/`openTab`, set the tab immediately (the UI already shows `LoadingFileView` while `fileDocument == nil` and listens via `fileDocumentPublisher` — see `EditorAreaView.swift` lines 60–82), then kick the async load in a `Task`; on failure, surface the existing error path (`logger.error`) plus close-the-tab handling. (3) Guard against double-loads when a user clicks the same file twice quickly (in-flight task per `CEWorkspaceFile`). (4) Preserve `openOptions`/cursor-position behavior in `CodeFileView.init`. (5) Audit all `loadCodeFile()` call sites and migrate them. Acceptance: opening a 50MB file never blocks the main thread >16ms before the loading view appears (verify with the T0.3 `fileOpen` signpost); no regressions opening files via Open Quickly, history navigation, or drag-drop; `CodeEditTests` pass; build + lint clean.

#### T1.5 — Cache editor views across tab switches (stop rebuilding the editor per switch)
**Model:** Fable 5 (high reasoning) · **Depends on:** T1.4 · **Files:** `EditorAreaView.swift`, `EditorAreaFileView.swift`, `CodeFileView.swift`, `Features/Editor/Models/`

**Prompt:**
> In the Dynamite macOS app (Swift/SwiftUI/AppKit, CodeEdit fork): switching editor tabs swaps the SwiftUI identity of `EditorAreaFileView(editorInstance:codeFile:)`, so the entire `CodeFileView` → CodeEditSourceEditor `TextViewController` stack is torn down and rebuilt — full text layout and full Tree-sitter re-parse on every tab switch. Xcode-class IDEs keep per-tab editor views alive. Design and implement editor view caching: (1) Introduce a per-`Editor`-group cache (e.g. on `EditorInstance` or a new `EditorViewCache`) keyed by tab, holding the live editor view/controller for open tabs, with an LRU cap (suggest 10 per split; make it a constant) and eviction that properly tears down coordinators/highlight providers. (2) Restructure `EditorAreaView`/`EditorAreaFileView` so tab switches reuse the cached AppKit view (likely via an `NSViewRepresentable`/`NSViewControllerRepresentable` host whose identity is stable per editor-split, swapping the hosted view) instead of recreating SwiftUI subtrees. SwiftUI `@State` in `CodeFileView` (two `TreeSitterClient`s — note one, `treeSitter`, is an unused duplicate; delete it) must move into the cached per-tab object so parsers survive switches. (3) Closing a tab releases its cached view and its `CodeFileDocument` per existing close semantics; settings/theme changes must still propagate to cached (including non-frontmost) editors — verify via the existing `@AppSettings` bindings or by applying on cache-restore. (4) Honor the repo invariant: no orchestration, product layer untouched; keep changes inside `Features/Editor`. This is the highest-risk change in the plan — propose the design in a short doc comment block at the top of the cache type, keep the diff reviewable, and do NOT bundle unrelated cleanups. Acceptance: switching between two already-open large files is <50ms (T0.3 `tabSwitch` signpost), no re-parse on switch (Tree-sitter signposts/logs), memory stays bounded with 30 tabs open (eviction works), all `CodeEditTests`/`CodeEditUITests` pass, build + lint clean.

#### T1.6 — CodeFileView init hygiene (duplicate TreeSitterClient, hover-cursor churn)
**Model:** Composer 2.5 · **Files:** `CodeFileView.swift`, `EditorAreaFileView.swift` · **Note:** skip the TreeSitterClient part if T1.5 already landed it.

**Prompt:**
> Two small fixes in the Dynamite macOS app, `CodeEdit/Features/Editor/Views/`: (1) `CodeFileView.swift` declares two `@State` Tree-sitter clients: `treeSitterClient` (used in `highlightProviders`) and `treeSitter` (never read). Delete the unused `treeSitter`. Both are allocated on every struct init because `@State` initial values are evaluated per-init — confirm `TreeSitterClient()` construction is cheap; if it does nontrivial setup, lazily create it on first use instead. (2) `EditorAreaFileView.swift` `body` has `.onHover { hover in DispatchQueue.main.async { NSCursor.iBeam.push() / NSCursor.pop() } }` — this churns the cursor stack on every hover transition and can desync push/pop. Replace with `.onContinuousHover`-free, non-async direct push/pop guarded so pop only runs if we pushed (track with a small `@State` bool), or remove entirely if the underlying NSTextView already sets the I-beam cursor (test: hover over an open code file — if the cursor is already an I-beam without our modifier, delete the modifier). Build + SwiftLint clean; no behavior change beyond cursor correctness.

---

### Phase 2 — Big-project scalability (sidebar, animations, resizing under load)

#### T2.1 — Move FSEvents processing off the main thread
**Model:** Opus 4.8 (high reasoning) · **Files:** `CEWorkspaceFileManager+DirectoryEvents.swift`, `CEWorkspaceFileManager.swift`, `DirectoryEventStream.swift`

**Prompt:**
> In the Dynamite macOS app (CodeEdit fork), `CEWorkspaceFileManager.fileSystemEventReceived(events:)` (`Features/CEWorkspace/Models/CEWorkspaceFileManager+DirectoryEvents.swift`) wraps ALL work in `DispatchQueue.main.async`: per-event `rebuildFiles(fromItem:)` does synchronous `FileManager.contentsOfDirectory`, child diffing, and sorting on the main thread. When a coding agent or build writes many files, these batches stall the UI (laggy sidebar/animations/resizing — our top complaint on big projects). Rework: (1) Process events on a dedicated serial background queue/actor: directory listing, diffing against `childrenMap`, and sort happen off-main; produce a compact change-set (created/removed/updated `CEWorkspaceFile` ids + parents). Then apply mutations to `flattenedFileItems`/`childrenMap` and call `notifyObservers` in a single main-thread hop per batch. Beware: `flattenedFileItems`/`childrenMap` are currently main-confined and read by the outline view data source synchronously — keep ALL mutation on the main thread; only the IO + diff computation moves off-main (compute candidate child URL lists in the background, then reconcile quickly on main). (2) Coalesce: if a new FSEvents batch arrives while one is being processed, merge paths and process once (latest wins). (3) Also fix `rebuildFiles` O(n²): build a `Set` of `directoryContentsUrlsRelativePaths` and a `Set` of existing child ids instead of `Array.contains` in loops. (4) Git-event handling (`handleGitEvents`) stays as-is here (T2.4 owns it) but must still be called after the batch. Use the T0.3 `fsEvents` signpost to annotate batch size and main-thread time. Acceptance: with the T0.3 stress fixture and `touch`-storms of 1,000 files, main-thread time per batch <10ms (signpost), navigator state stays correct (create/delete/rename reflected), `CodeEditTests` pass, build + lint clean.

#### T2.2 — (Folded into T2.1 step 3 — no separate task.)

#### T2.3 — Batch project-navigator updates; stop per-item reloadItem storms
**Model:** Sonnet 4.6 (high reasoning) · **Depends on:** T2.1 · **Files:** `ProjectNavigatorOutlineView.swift`, `ProjectNavigatorViewController*.swift`

**Prompt:**
> In the Dynamite macOS app, `ProjectNavigatorOutlineView.swift`'s `fileManagerUpdated(updatedItems:)` calls `outlineView.reloadItem(item, reloadChildren: true)` in a loop — one reload per updated item, each rebuilding a whole subtree. After git-status refreshes (which can pass thousands of items in a big repo) this is the dominant sidebar stall. Fix: (1) Wrap updates in `outlineView.beginUpdates()/endUpdates()`. (2) Skip items that are not visible: if the item's parent chain isn't expanded (`outlineView.isItemExpanded`) or `outlineView.row(forItem:) == -1`, skip — collapsed folders get correct state on expand anyway because the data source reads live model state. (3) Deduplicate: if both a parent and its descendant are in `updatedItems`, reload only the topmost ancestor. (4) For *status-only* changes (file's `gitStatus` changed, structure unchanged), prefer `reloadData(forRowIndexes:columnIndexes:)` on the affected visible rows instead of `reloadItem(_:reloadChildren: true)` — add a parameter to `fileManagerUpdated`/`notifyObservers` distinguishing structural vs. status updates (`CEWorkspaceFileManager.notifyObservers` callers: FS events = structural, `SourceControlManager.refreshStatusInFileManager` = status-only). (5) Keep the existing first-responder/rename deferral and selection-restoration logic intact. Also: `iconColor` and `rowHeight` setting observers in `ProjectNavigatorViewController` call full `reloadData()` — acceptable for explicit settings changes, leave them, but add a guard so they don't fire when the value is unchanged (rowHeight already guards; mirror for iconColor — verify). Acceptance: with 2,000 changed-status files, `outlineReload` signpost (T0.3) shows one batched update touching only visible rows; expanding folders still shows correct git badges; rename-in-place still works; build + lint clean.

#### T2.4 — Debounce, serialize, and scope git status refresh
**Model:** Sonnet 4.6 (medium reasoning) · **Depends on:** T2.1 · **Files:** `CEWorkspaceFileManager+DirectoryEvents.swift` (`handleGitEvents`), `SourceControlManager+GitClient.swift`

**Prompt:**
> In the Dynamite macOS app: every FSEvents batch with any non-`.git` change calls `SourceControlManager.refreshAllChangedFiles()` (spawns `git status`), and `refreshStatusInFileManager()` then iterates the ENTIRE `fileManager.flattenedFileItems` dictionary to clear stale statuses, then notifies observers with every touched file. During agent/build write-storms this spawns overlapping `git status` processes and floods the UI. Fix in `Features/CEWorkspace/Models/CEWorkspaceFileManager+DirectoryEvents.swift` and `Features/SourceControl/SourceControlManager+GitClient.swift`: (1) Debounce `refreshAllChangedFiles` calls triggered by FS events to at most one per 500ms (trailing edge), and serialize: if a refresh is running, mark dirty and run once more when it finishes — never concurrently (use an actor or a flag on the existing `@MainActor`-ish flow, matching the file's concurrency style). (2) In `refreshStatusInFileManager`, replace the full `flattenedFileItems` sweep with a maintained index: keep a `Set<String>` of file keys that currently have non-nil `gitStatus` (update it where `gitStatus` is set); stale-clearing then touches only that set minus the new changed set. (3) Only include files whose status actually changed in the `notifyObservers(updatedItems:)` set (currently every changed file is included even if status is identical — the `if file.gitStatus != changedFile.anyStatus()` guard sets but still inserts; insert only on real change). (4) Mark these notifications as status-only per T2.3's API. Acceptance: a storm of 500 file writes over 5s produces ≤ ~10 `git status` spawns (`gitStatus` signpost), UI badges end correct, no refresh is lost (final state matches `git status` output), build + lint clean.

#### T2.5 — Instruments pass: verify resize/animation fixes hold under the stress fixture
**Model:** Gemini 3.1 pro · **Depends on:** T0.1–T0.3, ideally after T2.1/T2.3 · **Deliverable:** report only, no code

**Prompt:**
> You are profiling the Dynamite macOS app (CodeEdit fork). Context: `patches/README.md` documents past fixes for resize stutter (NSHostingController `sizingOptions = []`, find-panel hosting, terminal grid resize throttling, jump-bar/tab-bar animation fixes, FastID, async tree-sitter init with a 100KB sync threshold). Your job is to verify these hold and find what's left. Using the stress fixture from `scripts/make-stress-fixture.sh`: (1) Record Instruments traces (Time Profiler + the `app.dynamite.perf` signposts + Hangs instrument) for: window live-resize for 10s, sidebar expand/collapse repeatedly, divider drags with terminal pane open, opening a 500KB and a 5MB source file, tab switching among 10 tabs, and a 1,000-file touch-storm while idle in the editor. (2) For every main-thread hang >100ms, attribute the heaviest stack and map it to a file/feature in the repo (source layout: `CodeEdit/Features/...`; key suspects documented in `Dynamite Docs/PERF-DEVPLAN.md` Part 1). (3) Explicitly check the known-fixed paths for regression: `NSHostingView.minSize` in resize stacks, `TextLayoutManager.layoutLines` re-typeset storms, SwiftTerm `Buffer.resize`, synchronous tree-sitter parse >100KB. (4) Write `Dynamite Docs/reports/T2.5-instruments-findings.md`: table of hangs (duration, stack summary, owning file, suggested fix, suggested model per this plan's economy rules). Do not change code.

---

### Phase 3 — Inherited cleanups & upstream hygiene

#### T3.1 — Consolidate CodeFileView's ~20 @AppSettings observers
**Model:** GPT 5.5 (Medium) · **Files:** `CodeFileView.swift`, `Features/Settings/`

**Prompt:**
> In the Dynamite macOS app, `CodeEdit/Features/Editor/Views/CodeFileView.swift` declares ~20 individual `@AppSettings(\.textEditing.*)` / `@AppSettings(\.theme.*)` property wrappers. Each is a separate publisher subscription per open editor; any settings write re-evaluates every editor body. Consolidate: (1) Inspect the `AppSettings` property wrapper implementation (`Features/Settings`) to see what it subscribes to. (2) Create one observed view-model (e.g. `EditorConfigModel`) that exposes the needed `textEditing` + `theme` sub-structs as `@Published` values driven by a single Settings subscription with `removeDuplicates()` on the relevant sub-structs, and refactor `CodeFileView` to consume it. The editor representable's `configuration` should be rebuilt only when one of its inputs actually changed. (3) Behavior must be identical: changing font, wrap, minimap, gutter, theme, etc. in Settings still live-updates all open editors. Keep the diff scoped to `CodeFileView` + the new model; do not migrate other views. Acceptance: toggling an unrelated setting (e.g. terminal setting) triggers zero `CodeFileView` body re-evaluations (verify with `Self._printChanges()` during dev, removed before commit); all editor settings still apply live; build + lint clean.

#### T3.2 — Markdown editor: single source of truth for text storage
**Model:** Sonnet 4.6 (medium reasoning) · **Depends on:** T1.2, T1.3 · **Files:** `MarkdownEditorView.swift`, `MarkdownTextView.swift`, `CodeFileDocument`

**Prompt:**
> In the Dynamite macOS app's live markdown editor (`CodeEdit/Features/Editor/MarkdownEditor/`): `MarkdownTextView` owns its own `NSTextStorage`, and every keystroke is mirrored synchronously into the `CodeFileDocument.content` storage via `onEdit`/`mirrorEdit` (and external changes flow back via `replaceContents` string comparison in `updateNSView` — an O(n) `string !=` compare per SwiftUI update). Evaluate and implement the cleaner architecture: have `MarkdownTextView` use the document's existing `NSTextStorage` (`codeFile.content`) directly as its storage (TextKit 1 allows attaching a layout manager to an existing storage — the raw source editor already shares it via `contentCoordinator`; check `CodeFileDocument` for how `content` is shared and whether attributes applied by our styler would leak into the raw editor view — if they would, keep dual storage but replace the O(n) sync: mirror via the existing edited-range callback both directions with a version counter instead of full-string comparison). Whichever path you take, document why in a header comment. Acceptance: typing latency unchanged or better (T0.3 `markdownStyle` signpost), toggling Markdown Preview (⇧⌘R) back and forth preserves content and undo stack sanely, autosave still works, external file changes still propagate, build + lint clean.

#### T3.3 — Upstream the ViewReuseQueue / minimap / typesetter fixes
**Model:** Gemini 3.1 pro · **Depends on:** T1.1 · **Deliverable:** PR branches + writeups, no Dynamite code changes

**Prompt:**
> Prepare upstream contributions from the Dynamite repo's vendored editor packages. Source material: `patches/codeedittextview-resize-perf.patch`, `patches/codeeditsourceeditor-highlight-startup-perf.patch`, `patches/README.md` (full root-cause analysis), and the tests added in `LocalPackages/CodeEditTextView` by task T1.1. Produce three self-contained patch series against upstream `CodeEditApp/CodeEditTextView` (0.12.1) and `CodeEditApp/CodeEditSourceEditor`: (1) ViewReuseQueue retired-view removal + per-fragment backing layers + the T1.1 regression tests (bug: ghost duplicated text on wrapped lines, unclickable right edge — reproduces on pristine upstream). (2) Typesetter forward-progress guarantee (`clusterBreakEnsuringProgress`) fixing the zero-width infinite loop hang. (3) Minimap `updateContentViewHeight` zero-height guard fix. Exclude Dynamite-specific choices (FastID, the 100KB threshold change, capture-name mappings) unless trivially separable — list them as "optional follow-ups". For each series write a PR description: symptom, root cause, fix, repro steps, test coverage. Output to `Dynamite Docs/reports/T3.3-upstream-prs/`. Getting these merged upstream shrinks our vendored diff permanently.

---

## Part 3 — Summary table

| ID | Task | Model (effort) | Size | Fixes |
|----|------|----------------|------|-------|
| T0.1 | Verify patches in build | Composer 2.5 | XS | Bugs 2+3 (likely stale build) |
| T0.2 | Vendor editor packages | Sonnet 4.6 (med) | M | Patch durability |
| T0.3 | Signposts + stress fixture | GPT 5.5 (Med) | S | Measurement |
| T1.1 | Ghost-bug tests + audit | Opus 4.8 (high) | M | Bugs 2+3 root |
| T1.2 | WYSIWYG width/dead zone | Gemini 3.5 High flash | XS | Bug 2 (preview mode) |
| T1.3 | Incremental md restyle | GPT 5.5 (High) | M | Bug 3 (preview) + md perf |
| T1.4 | Async file open | Opus 4.8 (med) | M | Bug 4 |
| T1.5 | Editor view caching | Fable 5 (high) | L | Bug 4 |
| T1.6 | Init hygiene, cursor | Composer 2.5 | XS | Bug 4 (minor) |
| T2.1 | FSEvents off main + O(n²) | Opus 4.8 (high) | L | Bug 1 |
| T2.3 | Batched outline updates | Sonnet 4.6 (high) | M | Bug 1 |
| T2.4 | Git status debounce/scope | Sonnet 4.6 (med) | M | Bug 1 |
| T2.5 | Instruments verification | Gemini 3.1 pro | S | Bug 1 verification |
| T3.1 | @AppSettings consolidation | GPT 5.5 (Med) | S | Editor churn |
| T3.2 | Md storage unification | Sonnet 4.6 (med) | M | Md robustness |
| T3.3 | Upstream PRs | Gemini 3.1 pro | S | Vendored-diff debt |

**Recommended execution order:** T0.1 → T0.2 → T1.1 (this alone may fully resolve bugs 2 & 3) → T0.3 → T1.4 → T2.1 → T2.3 → T2.4 → T1.5 → T1.2 → T1.3 → rest.
