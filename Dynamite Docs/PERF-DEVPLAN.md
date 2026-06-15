# Performance Audit & Development Plan — IDE Side

> Updated: 2026-06-13 (branch `IDE-optimisation`). Supersedes the 2026-06-11 plan, which was never executed; this revision re-audits the codebase, records what has now been **fixed directly on this branch**, and re-scopes the remaining work. Scope: IDE-side performance, reliability, and structural code health. Cockpit/product layer out of scope. Each task in Part 3 is **one prompt for one AI model**; GPT 5.5 (any thinking effort) is now a first-class choice alongside Composer, Sonnet, Gemini (Antigravity), Opus, and Fable.

---

## Part 1 — Landed on `IDE-optimisation` (2026-06-13)

The following structural fixes are implemented, build clean, lint clean, `CEWorkspaceFileManagerUnitTests` green, app launch verified via `./script/build_and_run.sh --verify`. Do **not** re-do these; review them.

| # | Fix | Files | What changed |
|---|-----|-------|--------------|
| L1 | **Async file open** | `CEWorkspaceFile.swift`, `Editor.swift` | `loadCodeFileAsync()`: disk read + decode on a background queue, document registration back on main, in-flight task guard against double-opens. `Editor.openFile` now never blocks the main thread; the existing `LoadingFileView` + `fileDocumentPublisher` path shows progress. |
| L2 | **Async state restoration** | `EditorLayout+StateRestoration.swift` | Restored tabs no longer each do a synchronous read on the main thread during workspace launch — previously launch blocked on reading *every* previously-open file. |
| L3 | **FSEvents pipeline off main** | `CEWorkspaceFileManager+DirectoryEvents.swift` | Event parsing on the FSEvents thread; affected parent dirs **deduplicated per batch** (was: one full rebuild per event, even for the same dir); directory listing (disk IO) on a serial background queue; only the cheap in-memory reconcile + one `notifyObservers` per batch on main. |
| L4 | **O(n²) → O(n) child diff** | same file | `reconcileChildren(of:withDirectoryContents:)` extracted from `rebuildFiles`, set-based lookups instead of `Array.contains` in loops. `rebuildFiles` keeps its signature for the FileManagement callers. |
| L5 | **Git status debounce + serialize + scoped sweep** | `SourceControlManager.swift`, `+GitClient.swift`, `+DirectoryEvents.swift` | FS-event refreshes go through `scheduleStatusRefresh()`: 500 ms trailing-edge debounce, never-concurrent serializer with a single pending re-run (final state always matches `git status`). `refreshStatusInFileManager` no longer sweeps **all** of `flattenedFileItems` — a `filesWithGitStatus` index tracks exactly which files have a badge — and only files whose status **actually changed** are sent to observers (was: every changed file, every refresh). |
| L6 | **Batched navigator reloads** | `ProjectNavigatorOutlineView.swift` | One `beginUpdates()/endUpdates()` pass; reload only **topmost** updated ancestors (subtree reloads cover descendants); skip rows not visible (collapsed folders read live model state on expand). Was: one `reloadItem(_, reloadChildren: true)` per item — thousands per git refresh in a big repo. |
| L7 | **Markdown keystroke mirror is incremental** | `MarkdownPreviewView.swift` | `handleEdit` was copying the **entire document string** out of the text view, comparing O(n), and replacing the whole doc storage per keystroke. Now mirrors only the edited range (NSTextStorage edited-range semantics), with an O(1) length check + full-resync fallback if the mirrors ever diverge. |
| L8 | **Dead code removed (~1,060 lines)** | `RenderedMarkdownView/Parser/Models.swift` + its test | Entire alternate markdown rendering stack was compiled but referenced by nothing. Also: unused duplicate `TreeSitterClient` `@State` in `CodeFileView` (was allocated on every struct init), and the `.onHover` `NSCursor.push/pop` hack in `EditorAreaFileView` (text view manages its own cursor rects; the hack desynced the cursor stack and applied I-beam over images/PDFs). |

### Re-audit notes (what the 2026-06-11 plan got stale on)

- The markdown editor was partially rewritten since the old plan: `MarkdownTextView` now **already** does incremental paragraph restyling with paired glyph+layout invalidation (full-document restyle only when a fence marker is edited). Old tasks T1.2/T1.3 are **done/obsolete**; the hardcoded-600pt dead zone is fixed by a clip-view frame observer.
- All editor-package patch checkouts (repo `.SourcePackages`, `.derivedData`, global DerivedData) verified patched on 2026-06-13. The patch system itself remains the structural liability → V1.
- Old T1.6 (init hygiene/cursor) landed above (L8). Old T2.1–T2.4 landed (L3–L6). Old T1.4 landed (L1/L2).

---

## Part 2 — Remaining audit findings (current, 2026-06-13)

### F1. Patch-on-checkout is still the root structural risk *(unchanged, highest priority)*
Editor correctness/perf fixes (ghost-text `ViewReuseQueue` fix, typesetter forward-progress hang fix, FastID, 100 KB sync-parse threshold, minimap height guard) live as patches applied to SPM checkouts. Any Xcode package re-resolve silently reverts them in the build — this has *already happened three times* (see `patches/README.md`). The apply script is not wired into any build phase. → **V1 (vendor the packages)**.

### F2. Tab switch rebuilds the whole editor *(the biggest remaining UX cost)*
Switching tabs swaps SwiftUI identity of `EditorAreaFileView` → tears down and rebuilds `CodeFileView` → new `TextViewController`, full text layout, full Tree-sitter re-parse. `CodeFileView.body` is also `.id(ObjectIdentifier(codeFile))`-keyed. Async open (L1) removed the disk stall but the rebuild stall remains on every switch back to an open tab. → **V3 (editor view caching)**.

### F3. "Slightly bigger file = janky animations" — remaining causes
With L1–L8 landed, the remaining suspects for the user-visible complaint, in likely order:
1. **Tree-sitter sync threshold semantics**: only `setUp` (full parse) needs the low 100 KB sync threshold; incremental edits and visible-range queries are cheap and currently share the same gate — files just over 100 KB get the async flash, files just under get sync cost on open. Split thresholds inside the (to-be-vendored) package. → **V4**.
2. **Wrap-on live resize re-typeset**: every resize frame re-typesets all visible lines when Wrap Lines is on (the `frozenWrapWidth` optimization was correctly reverted for correctness — do **not** reintroduce it that way). FastID reduced per-line cost; an Instruments pass must say whether this is still a hang source. → **V6**.
3. **`CodeFileView` observes ~20 `@AppSettings` keys** — any settings write re-evaluates every open editor body. → **V5**.

### F4. New findings from this audit (not in the old plan)
- **`flattenedFileItems`/`childrenMap` leak**: when a folder is deleted, only its *direct* children are pruned; descendants of deleted subfolders stay in both maps forever (stale objects, growing memory, and they used to be swept by the old git-status loop). → **V7**.
- **Navigator filter cache staleness**: with an active navigator filter, `filteredContentChildren` caches filtered children and FS changes don't invalidate entries for collapsed dirs (pre-existing; reloads never reached collapsed rows anyway). Minor. → folded into **V7**.
- **`MarkdownPreviewView.updateNSView`** still does an O(n) string compare against the text view per SwiftUI update (rare updates, but O(n) on a 2 MB doc). A document version counter removes it. → **V8**.
- **Markdown full-document restyle on fence edits**: typing inside/around ``` fences restyles the whole doc; a cached fence-state line index would bound it. Only matters for very large `.md`. → **V8**.

---

## Part 3 — Delegation plan

One task = one prompt = one model. Every task ends with: build passes (`xcodebuild build -project Dynamite.xcodeproj -scheme Dynamite`), SwiftLint clean on touched files, no new violations, and for behavior changes a test or a written manual-verification note. Always validate the running app with `./script/build_and_run.sh --verify` (never Finder//Applications copies).

**Model economy:** mechanical/scripted edits → Composer / Gemini flash / GPT 5.5 Low. Focused single-subsystem work → Sonnet 4.6 / GPT 5.5 Medium–High (GPT 5.5 High is a strong default for package-internal TextKit/typesetter work and for test authoring). Cross-cutting AppKit/SwiftUI lifecycle architecture → Fable 5 / Opus 4.8 / GPT 5.5 xHigh. Long-context analysis & report writing → Gemini 3.1 pro.

### Dependency order

```
V1 → V2 (tests live in the vendored package) → V4 (threshold change is package-internal)
V0 (signposts) before V6 (Instruments pass) — V6 also wants V3 landed
V3 independent of V1 (app-side only) — highest risk, schedule early
V5, V7, V8 independent
V9 (upstreaming) after V2
```

### V0 — Performance signposts + big-repo stress fixture
**Model:** GPT 5.5 (Medium) · **Size:** S

> Add lightweight performance instrumentation to the Dynamite macOS app (CodeEdit fork). (1) Create `CodeEdit/Utils/PerfSignposts.swift`: a thin `OSSignposter` wrapper (subsystem `app.dynamite.perf`) with static categories `fileOpen`, `tabSwitch`, `fsEvents`, `gitStatus`, `outlineReload`, `markdownStyle`. (2) Add interval signposts at: `CEWorkspaceFile.loadCodeFileAsync()` (annotate byte size), `Editor.openFile`, `CEWorkspaceFileManager.fileSystemEventReceived` (annotate event count and per-stage: parse / IO / reconcile), `SourceControlManager.refreshAllChangedFiles()`, the batched reload block in `ProjectNavigatorOutlineView.fileManagerUpdated` (annotate item count and reloaded-row count), `MarkdownTextView.applyIncrementalStyling` (annotate restyled range length vs document length). (3) Add `scripts/make-stress-fixture.sh` generating a throwaway repo: 10,000 files across 800 dirs, a git history with ~500 modified files, and a 2 MB markdown file. (4) No behavior changes. Acceptance: build + lint clean; `xcrun xctrace record --template 'Time Profiler' ...` shows the signposts; usage notes in `Dynamite Docs/reports/V0-instrumentation.md`.

### V1 — Vendor CodeEditTextView & CodeEditSourceEditor as local packages
**Model:** Sonnet 4.6 (medium) or GPT 5.5 (High) · **Size:** M · **The top structural-durability task.**

> In the Dynamite repo, convert two remote SPM dependencies into vendored local packages so our editor patches can never again be silently reverted by a package re-resolve (this has happened three times; see `patches/README.md`). (1) Verify patches are applied (`./scripts/apply-editor-perf-patch.sh` reports "already patched" everywhere), then copy `.SourcePackages/checkouts/CodeEditTextView` (0.12.1 + `codeedittextview-resize-perf.patch`) and `.SourcePackages/checkouts/CodeEditSourceEditor` (0.15.1 + both sourceeditor patches) into `LocalPackages/CodeEditTextView` and `LocalPackages/CodeEditSourceEditor`. Strip `.git`; add `VENDORED.md` to each (upstream version, commit, applied patches). (2) In `Dynamite.xcodeproj` replace the remote references with local package references; point CodeEditSourceEditor's `Package.swift` dependency on CodeEditTextView at the relative local path. Other deps stay remote. (3) Build clean from a wiped DerivedData; verify the compiled sources contain the marker comment "Always remove a retired view" (`ViewReuseQueue.swift`) and `maxSyncContentLength: Int = 100_000` (`TreeSitterClient.swift`). (4) Update `patches/README.md` (patches now baked into `LocalPackages/`; script retired for these two packages) and add one line to `CLAUDE.md`'s tech-stack section. Acceptance: clean build with no compiled checkout of these two packages; lint clean.

### V2 — Regression tests for the ghost-text / dead-right-edge / typesetter-hang fixes
**Model:** GPT 5.5 (High) or Opus 4.8 · **Depends:** V1 · **Size:** M

> In the vendored `LocalPackages/CodeEditTextView` inside the Dynamite repo: our patches fix three upstream bugs — (a) retired line-fragment views resurfacing as ghost text on wrapped lines + blocking right-edge clicks (`ViewReuseQueue.enqueueView` now removes views from superview; `LineFragmentView` is layer-backed), (b) infinite typesetter loop when width ≤ 0 (`clusterBreakEnsuringProgress` + pop-guard), (c) minimap `updateContentViewHeight` zero-height guard. Write package unit tests proving each: after `enqueueView` the view has no superview; during a simulated re-wrap no two visible fragment views overlap and fragment ranges are disjoint; `Typesetter.layoutTextUntilLineBreak` terminates with maxWidth 0, 0.1, and 1.0 on multi-line content; minimap height constraint becomes non-zero once content lays out. Then audit the re-wrap path (`TextLayoutManager.layoutLines`, fragment positioning, `ViewReuseQueue` callers, `LineFragmentView.hitTest`) for any remaining way a stale fragment stays visible or hit-testable, and confirm the text view width tracks the clip view under wrapping (no dead strip). Fix only what you find, smallest diffs, comment why. Findings → `Dynamite Docs/reports/V2-ghost-audit.md`.

### V3 — Cache editor views across tab switches
**Model:** Fable 5 (high) or GPT 5.5 (xHigh) · **Size:** L · **Highest-risk task; keep the diff reviewable.**

> Dynamite macOS app (Swift/SwiftUI/AppKit, CodeEdit fork): switching editor tabs swaps the SwiftUI identity of `EditorAreaFileView(editorInstance:codeFile:)` (and `CodeFileView.body` is keyed `.id(ObjectIdentifier(codeFile))`), so the whole `CodeFileView` → CodeEditSourceEditor `TextViewController` stack is rebuilt — full re-layout and full Tree-sitter re-parse per switch. Implement per-split editor view caching so switching back to an open tab reuses the live AppKit view: (1) a cache keyed by tab on the `Editor` (or new `EditorViewCache`), LRU cap ~10 per split, eviction tears down coordinators/highlight providers; (2) restructure `EditorAreaView`/`EditorAreaFileView` so the hosting view's identity is stable per split and the hosted editor view swaps; move per-tab state that must survive (`TreeSitterClient` in `CodeFileView`) into the cached object; (3) closing a tab releases its cached view and document (existing `Editor.closeTab` semantics — note it nils `file.fileDocument`); settings/theme changes must still propagate to cached non-frontmost editors; (4) file opening is now async (`CEWorkspaceFile.loadCodeFileAsync`) — the cache must tolerate `fileDocument == nil` → loading view → document arrival. Stay inside `Features/Editor`; no orchestration; product layer untouched. Acceptance: switching between two open large files < 50 ms (V0 `tabSwitch` signpost), no re-parse on switch, memory bounded with 30 tabs, `CodeEditTests`/`CodeEditUITests` pass, build + lint clean. Propose the design in a doc comment atop the cache type.

### V4 — Split tree-sitter sync thresholds (package-internal)
**Model:** Sonnet 4.6 (medium) · **Depends:** V1 · **Size:** S

> In vendored `LocalPackages/CodeEditSourceEditor`, `TreeSitterClient` gates *all* operations (initial `setUp` full parse, incremental edits, visible-range queries) behind one `maxSyncContentLength` (our patch lowered it 1 MB → 100 KB to stop main-thread stalls opening medium files; cost: brief unhighlighted flash on files > 100 KB). Only `setUp` is O(document); edits are incremental and queries are ≤ 4096 chars. Introduce separate constants: keep 100 KB (or lower) for `setUp`; restore ~1 MB for edits/queries so medium files keep synchronous (flash-free) highlighting while typing. Audit each call site of the constant to classify it. Update `LocalPackages/CodeEditSourceEditor/VENDORED.md`. Acceptance: opening a 150 KB file does not stall the main thread (V0 signposts); typing in it highlights without flashing; package tests pass; build + lint clean.

### V5 — Consolidate CodeFileView's ~20 @AppSettings observers
**Model:** GPT 5.5 (Medium) · **Size:** S

> In `CodeEdit/Features/Editor/Views/CodeFileView.swift` (Dynamite repo), ~20 individual `@AppSettings(\.textEditing.*)` / `@AppSettings(\.theme.*)` wrappers each subscribe per open editor; any settings write re-evaluates every editor body. Inspect the `AppSettings` wrapper (`Features/Settings`), then introduce one observed model exposing the needed sub-structs as `@Published` with `removeDuplicates()`, and refactor `CodeFileView` to consume it so its `SourceEditorConfiguration` rebuilds only when an actual input changed. Behavior identical: every editor setting still live-updates all open editors. Verify with `Self._printChanges()` during dev (remove before commit) that an unrelated settings write (e.g. terminal font) causes zero `CodeFileView` re-evaluations. Keep the diff to `CodeFileView` + the new model. Build + lint clean.

### V6 — Instruments verification pass (report only)
**Model:** Gemini 3.1 pro · **Depends:** V0, ideally after V3 · **Size:** S

> Profile the Dynamite macOS app using the V0 stress fixture and `app.dynamite.perf` signposts. Record Time Profiler + Hangs for: 10 s window live-resize with a wrapped 500 KB file open (Wrap Lines ON — check `TextLayoutManager.layoutLines` re-typeset cost; the old `frozenWrapWidth` freeze was reverted for correctness, do not recommend reintroducing it as-was), sidebar expand/collapse storms, a 1,000-file touch-storm while idle (verify the new off-main FSEvents pipeline holds: main-thread time per batch should be < 10 ms), git refresh with 500 changed files (verify ≤ ~10 `git status` spawns per 5 s storm and that only changed rows reload), opening 500 KB / 5 MB files (verify loading view appears < 16 ms), tab switching among 10 tabs. For every main-thread hang > 100 ms, attribute the heaviest stack to a file in `CodeEdit/Features/...` and suggest a fix + model per this plan's economy rules. Output: `Dynamite Docs/reports/V6-instruments-findings.md`. No code changes.

### V7 — Fix the file-index leak on folder deletion (+ filter cache invalidation)
**Model:** Sonnet 4.6 (medium) · **Size:** S

> In the Dynamite repo, `CEWorkspaceFileManager` (`Features/CEWorkspace/Models/`): when a directory is deleted, `reconcileChildren(of:withDirectoryContents:)` (also reachable via `rebuildFiles`) removes only the directory's *direct* child entries from `flattenedFileItems`/`childrenMap`; descendants of deleted subfolders are never pruned — stale `CEWorkspaceFile` objects and map entries accumulate for the lifetime of the workspace. Fix: when removing a child whose `childrenMap` entry exists (it was an indexed directory), recursively remove its entire indexed subtree from both maps. Add a unit test in `CodeEditTests/Utils/CEWorkspaceFileManager/` (create nested dirs, index them via `childrenOfFile`, delete the root of the subtree on disk, trigger a rebuild, assert the maps contain no descendant keys). Bonus, same change: `ProjectNavigatorViewController.filteredContentChildren` caches filtered children while a navigator filter is active and is not invalidated by FS changes — invalidate affected entries in `fileManagerUpdated` (controller already clears it wholesale in `handleFilterChange`; per-item removal is enough). Build + lint clean.

### V8 — Markdown editor: version-counter sync + fence-state cache
**Model:** GPT 5.5 (High) · **Size:** M

> In Dynamite's live markdown editor (`CodeEdit/Features/Editor/MarkdownEditor/`, TextKit 1): (1) `MarkdownPreviewView.updateNSView` detects external document changes with a full `documentText != textView.string` compare — O(n) per SwiftUI update on large docs. Replace with a version counter: bump on every mirrored edit (`Coordinator.handleEdit`) and on `replaceContents`, and have external-change detection subscribe to the document's content-change signal (`CodeFileDocument` posts via `contentCoordinator.textUpdatePublisher`; the markdown view's own mirror writes must be excluded via the existing `isSyncing` flag) instead of comparing strings. (2) `MarkdownTextView.didChangeText` falls back to *full-document* restyling whenever the edited paragraph contains a fence marker (``` or ~~~). Maintain a line-index → in-fence cache so a fence edit restyles only from the edited fence to the next fence boundary (or EOF), recomputed lazily. (3) Undo in markdown mode uses the NSTextView's own stack, separate from the raw editor's registered undo manager — document this divergence in a header comment and file it as a known issue; do not attempt to unify in this task. Acceptance: typing near fences in a 2 MB md file restyles ≪ document length (V0 `markdownStyle` signpost); external changes (git checkout while preview open) still propagate; toggling preview preserves content; build + lint clean.

### V9 — Upstream the package fixes
**Model:** Gemini 3.1 pro · **Depends:** V2 · **Size:** S · **Deliverable: PR branches + writeups, no Dynamite code.**

> Prepare upstream contributions from Dynamite's vendored editor packages. Sources: `patches/README.md` (root-cause analyses), `patches/*.patch`, V2's regression tests. Three self-contained series against `CodeEditApp/CodeEditTextView` 0.12.1 and `CodeEditApp/CodeEditSourceEditor`: (1) ViewReuseQueue retired-view removal + layer-backed `LineFragmentView` + V2 tests (ghost text on wrapped lines, unclickable right edge — reproduces on pristine upstream, macOS 26); (2) typesetter forward-progress fix (zero-width infinite loop / launch hang); (3) minimap `updateContentViewHeight` zero-height guard. Exclude Dynamite-specific choices (FastID, threshold values, capture-name aliases) — list as optional follow-ups. Each PR: symptom, root cause, fix, repro, tests. Output `Dynamite Docs/reports/V9-upstream-prs/`. Merged upstream = permanently smaller vendored diff.

---

## Part 4 — Summary

| ID | Task | Model (effort) | Size | Why |
|----|------|----------------|------|-----|
| V0 | Signposts + stress fixture | GPT 5.5 (Med) | S | Measurement before claims |
| V1 | Vendor editor packages | Sonnet 4.6 / GPT 5.5 (High) | M | Kill the recurring patch-revert failure mode |
| V2 | Package regression tests + audit | GPT 5.5 (High) / Opus 4.8 | M | Lock in ghost/hang fixes |
| V3 | Editor view caching | Fable 5 / GPT 5.5 (xHigh) | L | Biggest remaining UX stall |
| V4 | Split tree-sitter thresholds | Sonnet 4.6 (med) | S | Flash-free medium files, no stalls |
| V5 | @AppSettings consolidation | GPT 5.5 (Med) | S | Stop cross-editor invalidation |
| V6 | Instruments pass | Gemini 3.1 pro | S | Verify L1–L8 + find what's left |
| V7 | File-index leak fix | Sonnet 4.6 (med) | S | Memory + staleness in long sessions |
| V8 | Markdown version counter + fence cache | GPT 5.5 (High) | M | Big-md robustness |
| V9 | Upstream PRs | Gemini 3.1 pro | S | Shrink vendored diff |

**Recommended order:** V1 → V0 → V3 (start early, it's the long pole) → V2 → V4 → V5 → V7 → V8 → V6 → V9.
