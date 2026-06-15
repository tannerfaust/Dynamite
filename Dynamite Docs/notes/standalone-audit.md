# T1.10 — Standalone-mode audit (2026-06-10)

Audit of Phase-1 code against the architectural invariant (ARCHITECTURE.md):

> The product layer (`ProductGraph`, `RepoAwareness`, `ContextEngine`, `TruthLayer`) must run with
> **no editor pane open and no repo connected** (degrading gracefully). It depends on the
> workspace/document model, never on editor UI. No orchestration subsystem exists anywhere.

Scope traced: `Features/ProductGraph`, `Features/LinkIndex`, `Features/AIAssist`,
`Features/Shell` (Product Studio surfaces). Method: import graph + grep for editor/git/runtime
symbols (`EditorManager`, `CodeFileDocument`, `SourceControlManager`, `GitClient`,
`@EnvironmentObject`, `WorkspaceDocument`), then manual trace of each hit.

## Checklist

### Violations found — fixed in this change
- [x] **V1 (crash)** `ProductGraph/Map/Views/ProductMapView.swift:16` declared
  `@EnvironmentObject var workspace: WorkspaceDocument`, but the Studio hosting controller
  (`ShellViewController.buildStudioChildIfNeeded`) never injects it → fatal error on first
  node tap. **Fix:** removed the environment dependency; `Router` is now passed weakly through
  `MapSurface` → `ProductMapViewModel.openNode(id:)`. Map works with nil router (selection only).
- [x] **V2 (dead-end routes)** `Shell/Router.swift:131,136` wrote `cockpitSelectedNode` /
  `cockpitSelectedSurface` workspace state that **no view consumed** — Backlinks rows and map
  taps switched mode but never focused anything. **Fix:** Router now also posts
  `.cockpitFocusNode` / `.cockpitFocusSurface`; Product Studio selects the surface,
  `StudioViewModel` selects the artifact (with a pending-id retry if the store is still loading).
- [x] **V3 (silent degradation)** `ProductGraph/Views/StudioSurface.swift` never passed
  `linkIndexManager` into `StudioViewModel` (defaulted nil) → AIAssist `ContextBundleBuilder`
  always degraded to focus-artifact-only. **Fix:** wired through
  `ShellViewController` → `ProductStudioRootView`.
- [x] **V4 (watcher gap)** `LinkIndex/LinkIndexManager.swift:25-29` attached the `product/`
  `DirectoryEventStream` only if the folder existed at init. Fresh standalone workspace →
  first artifacts never indexed until relaunch. **Fix:** `ArtifactStore` posts
  `.productArtifactsDidChange` after create/save; `LinkIndexManager` attaches the watcher
  on first notification and rebuilds once. Subsequent changes flow through file events.
- [x] **V5 (perf)** `LinkIndex/Database/LinkIndexDatabase.swift:9-11` traced **every SQL
  statement** to stdout — `cachedKind(for:)` runs per file-tree cell, so navigator scrolling
  printed per-row. **Fix:** trace removed.

### Verified clean — no action
- [x] `ProductGraph` (Models, Services, Views, Board, Map): no `EditorManager`, no
  `CodeFileDocument`, no source-control/git symbols, no NSDocument coupling. `ArtifactStore`
  is pure FileManager on the workspace folder — works with no git repo.
- [x] `AIAssist`: imports are Foundation/SwiftUI/Combine/GRDB/Security only. "editor" hits are
  doc comments/prompt prose. `ContextBundleBuilder(linkIndex: nil, …)` degrades gracefully.
- [x] `LinkIndex`: depends on workspace URL + GRDB only; no repo or editor coupling.
- [x] Product Studio shell: Studio stores guard on `workspace?.fileURL`; with no
  workspace the Studio degrades gracefully. No orchestration subsystem anywhere.
- [x] `Router.openFile` (Shell:186) touches `editorManager` — **allowed**: Shell is the
  bridge layer routing *into* the IDE; product surfaces never call it directly.
- [x] ProductGraph → `Features/Editor/MarkdownEditor/MarkdownTextView` — **allowed by design**
  (T1.6: "reuse the existing editor component"). It is a self-contained `NSTextView` subclass;
  no editor *pane*, `EditorManager`, or open tab required. See task below for relocation.

### Index rebuild — lossless? Yes (verified by trace)
- [x] `WorkspaceDocument.swift:178-181` recreates `LinkIndexManager` and runs a **full
  `rebuildIndex()` on every workspace open** (delete-all + rescan `product/**/*.md`).
  Deleting `.dynamite/index.db` and relaunching therefore reproduces the graph exactly:
  every `nodes` column derives from front-matter or file attributes (mtime/size/sha), every
  `edges`/`code_links` row from parsed links. `.dynamite/index.db` is gitignored as designed.
- Caveat (a): files whose front-matter fails to parse get a **random UUID node id**
  (`LinkIndexManager.rebuildIndex`) — not stable across rebuilds. Recorded as
  `parseState: "failed"`, so no healthy data is affected. Filed as a task.
- Caveat (b): the `fts` virtual table is **never populated** (rebuild deletes from it, nothing
  inserts) — dead schema, no reader, no data loss. Filed as a task.

## Non-trivial follow-ups (filed as tasks)
1. **Incremental reindex** — `LinkIndexManager.handleEvents` does a full rebuild on any file
   event; ADR-0001 specifies per-file reparse on hash mismatch. Fine at ~100 artifacts, not at 5k.
2. **Populate or drop the FTS table** — needed before "Ask the Product"/graph text search.
3. **Deterministic ids for failed-parse nodes** — hash the workspace-relative path instead of
   `UUID()` so broken-file nodes (and edges pointing at them) are stable across rebuilds.
4. **Move `MarkdownEditor` out of `Features/Editor`** — to a feature-neutral folder so the
   compile-time layering (product layer must not depend on editor UI) is enforced by structure.
