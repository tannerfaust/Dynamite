# ADR-0006: App shell — one app, two environments per window
- Status: accepted
- Date: 2026-06-10
- Deciders: Max (owner); drafted by Claude (chief-architect pass)
- Resolves: PRD §9 open question 6; ARCHITECTURE.md key decision 6; formalizes PRD M0 (R0.1–R0.3)
- Depends on: [ADR-0001](ADR-0001-product-graph-data-model.md) (LinkIndex, node ids)

## Context

Dynamite has two top-level environments over one workspace: **Product Studio** (product ownership — Home, docs, tasks, projects, roadmap, canvases, Pulse, Ask the Product, ledgers; the default) and **Ground Control** (inherited CodeEdit layout for code review, source control, terminal, build/test state, and optional agent-extension supervision). PRD M0 requires a per-window switcher, per-project mode memory, two windows showing both environments of one workspace, and cross-deep-links in both directions. The switcher is environment-owned navigation plus ⌘1/⌘2 commands, not a toolbar segmented control. The architecture invariant: the product layer must run with no editor open and no repo connected, and both environments must see the same truth instantly — which is why this cannot be two apps.

Codebase facts that shape the design (see `notes/codeedit-internals.md` §3):

- `WorkspaceDocument` (NSDocument) creates one `CodeEditWindowController`; the controller sets `contentViewController = CodeEditSplitViewController` directly, and exposes `splitViewController` as a cast of `contentViewController` (`CodeEditWindowController.swift:35–52`).
- `CodeEditSplitViewController` is a rigid 3-pane `NSSplitViewController` (navigator / workspace / inspector) with hardcoded constraints — the internals doc explicitly warns against shoving new view modes inside it.
- Per-project UI state persists via `WorkspaceStateKey` + `workspace.addToWorkspaceState/getFromWorkspaceState`.
- **Keyboard conflict:** ⌘1–⌘9 are currently bound to navigator tab switching (`ViewCommands.NavigatorCommands`). The PRD's ⌘1/⌘2 environment shortcuts collide; this ADR must resolve it.

## Decision

One app, one process, one window class. Each window owns a **view-mode container** that swaps between two child view controllers over the same `WorkspaceDocument`.

### 1. Window integration: a mode container above the split view

New `Features/Shell` adds:

- `ViewMode` enum: `.studio | .groundControl`; new workspace state stores `studio` / `ground-control`, while old `cockpit` / `ide` values are accepted for migration.
- `ShellViewController` (NSViewController): the window's new `contentViewController`. It owns up to two children — the existing `CodeEditSplitViewController` (Ground Control) and an `NSHostingController<ProductStudioRootView>` (Product Studio) — and crossfades/swaps between them. No `NSSplitViewController` changes; the CodeEdit pane is mounted exactly as today, one level deeper.
- `CodeEditWindowController.splitViewController` becomes a lookup through `ShellViewController` (the only call-site-visible change; all existing toggles — navigator, inspector, utility area — keep working untouched).
- **Lazy children, retained once created.** Ground Control is built first for legacy CodeEdit integration; Product Studio is built on first switch/default open and then kept alive — switching back preserves editor tabs, scroll positions, canvas state. Product Studio never depends on editor UI being visible. (Follow-up, non-blocking: `WorkspaceDocument`'s eager `EditorManager`/LSP init should become lazy so a Studio-only window doesn't even build editor models — tracked as a perf task, not required for correctness.)
- **Per-window mode.** `viewMode` lives on `CodeEditWindowController` (`@Published`), not on the document — so two windows on the same workspace can show Product Studio and Ground Control simultaneously (R0.3). The toolbar reconfigures per mode for chrome only; it does not host the environment switch.

### 2. Where Product Studio and Ground Control mount

- `ProductStudioRootView` (SwiftUI, in `Features/Shell/ProductStudio`) is Product Studio's own top-level layout: a labeled sidebar plus content area, *not* the 3-pane split VC. Phase 1 surfaces: Home, Tasks, Projects, Roadmap, Docs, Product Map; later: Pulse, Ask, Ledgers.
- **Ground Control product toggles reuse existing extension points**, per the internals doc's advice: a `productContext` case on `InspectorTab` (current file's spec/decisions/assumptions + backlinks, queried from LinkIndex by path) and, later, an Ask-the-Product tab on `UtilityAreaTab`. No new product shell is embedded inside Ground Control.
- **Switcher placement:** Product Studio exposes Ground Control as a pinned sidebar destination. Ground Control exposes Product Studio as a pinned row above the navigator. ⌘1/⌘2 and View menu commands remain the global paths. A toolbar segmented toggle was rejected because it overloads global chrome and proved unreliable when toolbar rebuilding and mode switching raced.

### 3. Deep-link routing

A `Router` in `Features/Shell`, with a URL-style internal route format (also registrable as a macOS URL scheme later, so compiled context/briefing-pack citations can carry clickable `dynamite://` links — deferred, Phase 2):

```
dynamite://node/<node-id>                          → Product Studio: focus node
dynamite://surface/<studio|map|pulse|ask|...>      → Product Studio: open surface
dynamite://code?path=<repo-rel-path>&line=<n>&symbol=<name>
                                                   → Ground Control: open file; line optional; if path is stale,
                                                     resolve via LinkIndex anchor (ADR-0001 §2)
dynamite://context?path=<repo-rel-path>            → product context for a file (Studio node list,
                                                     or Ground Control inspector if already there)
dynamite://mode/<studio|ground-control>            → switch current window's mode
```

- Host = route type; everything else is path/query. Percent-encode paths. Routes are workspace-relative and resolve within the routing window's workspace (cross-workspace routing deferred).
- **Window targeting rule:** a route whose target mode differs from the current window's mode first looks for another window on the *same workspace* already in the target mode and routes there; otherwise it switches the current window. This makes the two-window setup (Product Studio left, Ground Control right) work naturally: clicking a citation in Studio jumps the Ground Control window to file/line instead of flipping your Studio away.
- The two PRD-mandated directions are then just routes: citation/node → `dynamite://code?...`; "show product context" on a file → `dynamite://context?path=...`.

### 4. State restoration (per project)

Extend `WorkspaceStateKey`:

| New key | Meaning |
|---|---|
| `viewMode` | last-used mode for this workspace — the default for new windows |
| `cockpitSelectedSurface` | last Product Studio surface (legacy key name retained) |
| `cockpitSelectedNode` | last focused Product Studio node id (legacy key name retained) |

- Written via the existing `addToWorkspaceState` path; absence of `viewMode` falls back to the rollout default (§Rollout). All current Ground Control keys (`openTabs`, collapse states, …) are untouched — CodeEdit restoration behavior is byte-for-byte today's.
- Per-window mode is runtime state; the *document* records only last-used mode as the restoration seed. Each mode restores its own internal state independently, so flipping modes never perturbs the other side's restoration.

### 5. One `CEWorkspace` session, one `LinkIndex`

- `WorkspaceDocument` gains **one** new property: `productSession: ProductSession` — a container owning the `LinkIndex` (GRDB pool per ADR-0001), the ProductGraph store, and the `Router`. One property, not five, to limit god-object growth (internals §2 pitfall).
- Both view controllers receive the same `WorkspaceDocument` and reach everything through it: Product Studio queries LinkIndex by node id; Ground Control's `productContext` inspector queries it by file path; deep links resolve through the same `Router`. There is no second index, no sync protocol, no message passing — "both see the same truth" is satisfied by construction because there is only one truth object per workspace.
- `ProductSession` initializes without a repo and without editor UI (architecture invariant); repo-dependent features inside it degrade per ADR-0001 (`no-repo` state).

### 6. Keyboard

⌘1 = Product Studio, ⌘2 = Ground Control. The environment switch gets prime keyboard real estate, while visible entry points live inside each environment's navigation. The colliding navigator tab shortcuts move from ⌘1–⌘9 to **⌃⌘1–⌃⌘9** (Ground Control only). This deliberately breaks Xcode muscle memory; acceptable because Ground Control is the secondary environment, and the remap ships in the same release as the switcher so the keys never mean two things at once.

## Alternatives considered

**Separate window stacks** (a Product Studio window class + a Ground Control window class, each workspace opening one or both). Doubles window-controller, toolbar, restoration, and menu-validation code; cross-deep-links degrade into window-finding heuristics; NSDocument's window-controller bookkeeping gets ambiguous about which window "is" the document; and the one-keystroke flip dies. The one thing it offers (both environments visible at once) the chosen design already does better via two windows with independent per-window modes.

**Separate processes** (Product Studio app + Ground Control helper, XPC between). Every link traversal and citation click becomes IPC; the LinkIndex either duplicates per process or becomes a server; crash isolation buys nothing (both halves are ours, same codebase); state restoration and "same truth instantly" become a distributed-systems problem.

**Web views for Product Studio surfaces.** Explicitly banned by PRD R1.2 ("No web views") and the native-speed principle in `CLAUDE.md`. Canvas surfaces (VPC/BMC/story maps) are exactly where web views feel worst on macOS (scrolling, drag, focus rings, accessibility). Native taste is part of the product layer.

## Rollout (migration-free)

Gated on a new `FeatureFlags.cockpitView` (the existing `FeatureFlags` type at `CodeEdit/FeatureFlags.swift`):

- **Phase A — flag off:** `Features/Shell` lands; `ShellViewController` wraps the split VC but builds *only* Ground Control; no switcher UI, no ⌘1/⌘2, no keybinding remap. Behavior is pixel-identical to CodeEdit. This de-risks the container refactor in isolation.
- **Phase B — flag on (current dev):** switcher + `ProductStudioRootView`; default mode **Product Studio**; ⌘1/⌘2 live; navigator tabs remapped to ⌃⌘1–9; Product Studio gets quiet toolbar chrome while Ground Control keeps CodeEdit chrome.
- **Phase C — permanent:** flag removed after Product Studio is hardened as the primary surface; saved per-project modes always win.

No data migration at any phase: the only persistence change is additive `WorkspaceStateKey` entries whose absence means "default".

## Consequences

**Easier:** Product Studio surfaces, Ground Control product toggles, and future surfaces (Pulse, Ask) all have designated mounting points; deep links are one parser + one router instead of scattered navigation calls; the two-window workflow falls out of per-window mode for free; the editor-less product layer is structurally enforced (Studio child never references editor UI).

**Harder / must maintain:** `ShellViewController` is a new indirection every window-content change goes through; the `splitViewController` computed-property change must be audited at all call sites; keeping both children alive raises per-window memory (acceptable — measured against `notes/perf-baseline.md`, and children are lazy until first use); the ⌃⌘1–9 remap needs documenting in keybindings help.

**Deferred:** registering `dynamite://` with macOS for external links; cross-workspace routing; lazy `EditorManager`/LSP init in `WorkspaceDocument`; Studio surfaces beyond Home/Docs/Tasks/Projects/Roadmap/Map.
