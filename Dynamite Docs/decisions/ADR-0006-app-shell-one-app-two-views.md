# ADR-0006: App shell — one app, two views per window
- Status: accepted
- Date: 2026-06-10
- Deciders: Max (owner); drafted by Claude (chief-architect pass)
- Resolves: PRD §9 open question 6; ARCHITECTURE.md key decision 6; formalizes PRD M0 (R0.1–R0.3)
- Depends on: [ADR-0001](ADR-0001-product-graph-data-model.md) (LinkIndex, node ids)

## Context

Dynamite has two top-level surfaces over one workspace: the **Cockpit** (product ownership — Studio, canvases, Pulse, Ask the Product, ledgers; the default) and the **IDE** (inherited CodeEdit layout with product-context toggles). PRD M0 requires a per-window switcher (⌘1/⌘2), per-project mode memory, two windows showing both views of one workspace, and cross-deep-links in both directions. The architecture invariant: the product layer must run with no editor open and no repo connected, and both views must see the same truth instantly — which is why this cannot be two apps.

Codebase facts that shape the design (see `notes/codeedit-internals.md` §3):

- `WorkspaceDocument` (NSDocument) creates one `CodeEditWindowController`; the controller sets `contentViewController = CodeEditSplitViewController` directly, and exposes `splitViewController` as a cast of `contentViewController` (`CodeEditWindowController.swift:35–52`).
- `CodeEditSplitViewController` is a rigid 3-pane `NSSplitViewController` (navigator / workspace / inspector) with hardcoded constraints — the internals doc explicitly warns against shoving new view modes inside it.
- Per-project UI state persists via `WorkspaceStateKey` + `workspace.addToWorkspaceState/getFromWorkspaceState`.
- **Keyboard conflict:** ⌘1–⌘9 are currently bound to navigator tab switching (`ViewCommands.NavigatorCommands`). The PRD's ⌘1/⌘2 mode shortcuts collide; this ADR must resolve it.

## Decision

One app, one process, one window class. Each window owns a **view-mode container** that swaps between two child view controllers over the same `WorkspaceDocument`.

### 1. Window integration: a mode container above the split view

New `Features/Shell` adds:

- `ViewMode` enum: `.cockpit | .ide`.
- `ShellViewController` (NSViewController): the window's new `contentViewController`. It owns up to two children — the existing `CodeEditSplitViewController` (IDE) and an `NSHostingController<CockpitRootView>` (Cockpit) — and crossfades/swaps between them. No `NSSplitViewController` changes; the IDE pane is mounted exactly as today, one level deeper.
- `CodeEditWindowController.splitViewController` becomes a lookup through `ShellViewController` (the only call-site-visible change; all existing toggles — navigator, inspector, utility area — keep working untouched).
- **Lazy children, retained once created.** The mode the window opens in is built immediately; the other is built on first switch and then kept alive — switching back preserves editor tabs, scroll positions, canvas state. Cockpit-only sessions never pay for editor UI construction. (Follow-up, non-blocking: `WorkspaceDocument`'s eager `EditorManager`/LSP init should become lazy so a Cockpit-only window doesn't even build editor models — tracked as a Phase-C perf task, not required for correctness.)
- **Per-window mode.** `viewMode` lives on `CodeEditWindowController` (`@Published`), not on the document — so two windows on the same workspace can show Cockpit and IDE simultaneously (R0.3). The toolbar reconfigures per mode (Cockpit gets its own toolbar items; IDE keeps the current set).

### 2. Where Cockpit surfaces mount

- `CockpitRootView` (SwiftUI, in `Features/Shell`) is the Cockpit's own top-level layout: a sidebar of surfaces + content area, *not* the 3-pane split VC. Surfaces register through a `CockpitSurface` protocol (`id`, `title`, `systemImage`, `body`) — same registry pattern as `NavigatorTab`/`InspectorTab`/`UtilityAreaTab`, so adding Pulse or Ask the Product later is a registration, not a layout change. Phase 1 surfaces: Studio, Product Map; later: Pulse, Ask, Ledgers.
- **IDE-side product toggles reuse existing extension points**, per the internals doc's advice: a `productContext` case on `InspectorTab` (current file's spec/decisions/assumptions + backlinks, queried from LinkIndex by path) and, later, an Ask-the-Product tab on `UtilityAreaTab`. No new panel architecture in the IDE view.

### 3. Deep-link routing

A `Router` in `Features/Shell`, with a URL-style internal route format (also registrable as a macOS URL scheme later, so compiled context/briefing-pack citations can carry clickable `dynamite://` links — deferred, Phase 2):

```
dynamite://node/<node-id>                          → Cockpit: focus node (e.g. dynamite://node/spec-9k3fa)
dynamite://surface/<studio|map|pulse|ask|...>      → Cockpit: open surface
dynamite://code?path=<repo-rel-path>&line=<n>&symbol=<name>
                                                   → IDE: open file; line optional; if path is stale,
                                                     resolve via LinkIndex anchor (ADR-0001 §2)
dynamite://context?path=<repo-rel-path>            → product context for a file (Cockpit node list,
                                                     or IDE inspector if already in IDE view)
dynamite://mode/<cockpit|ide>                      → switch current window's mode
```

- Host = route type; everything else is path/query. Percent-encode paths. Routes are workspace-relative and resolve within the routing window's workspace (cross-workspace routing deferred).
- **Window targeting rule:** a route whose target mode differs from the current window's mode first looks for another window on the *same workspace* already in the target mode and routes there; otherwise it switches the current window. This makes the two-window setup (Cockpit left, IDE right) work naturally: clicking a citation in Cockpit jumps the IDE window to file/line instead of flipping your Cockpit away.
- The two PRD-mandated directions are then just routes: citation/node → `dynamite://code?...`; "show product context" on a file → `dynamite://context?path=...`.

### 4. State restoration (per project)

Extend `WorkspaceStateKey`:

| New key | Meaning |
|---|---|
| `viewMode` | last-used mode for this workspace — the default for new windows |
| `cockpitSelectedSurface` | last Cockpit surface |
| `cockpitSelectedNode` | last focused node id |

- Written via the existing `addToWorkspaceState` path; absence of `viewMode` falls back to the rollout default (§Rollout). All current IDE keys (`openTabs`, collapse states, …) are untouched — IDE restoration behavior is byte-for-byte today's.
- Per-window mode is runtime state; the *document* records only last-used mode as the restoration seed. Each mode restores its own internal state independently, so flipping modes never perturbs the other side's restoration.

### 5. One `CEWorkspace` session, one `LinkIndex`

- `WorkspaceDocument` gains **one** new property: `productSession: ProductSession` — a container owning the `LinkIndex` (GRDB pool per ADR-0001), the ProductGraph store, and the `Router`. One property, not five, to limit god-object growth (internals §2 pitfall).
- Both view controllers receive the same `WorkspaceDocument` and reach everything through it: Cockpit queries LinkIndex by node id; the IDE's `productContext` inspector queries it by file path; deep links resolve through the same `Router`. There is no second index, no sync protocol, no message passing — "both see the same truth" is satisfied by construction because there is only one truth object per workspace.
- `ProductSession` initializes without a repo and without editor UI (architecture invariant); repo-dependent features inside it degrade per ADR-0001 (`no-repo` state).

### 6. Keyboard

⌘1 = Cockpit, ⌘2 = IDE, exactly as the PRD specifies — the mode switch is the product's primary gesture (Cockpit-first positioning) and gets the prime real estate. The colliding navigator tab shortcuts move from ⌘1–⌘9 to **⌃⌘1–⌃⌘9** (IDE view only). This deliberately breaks Xcode muscle memory; acceptable because the IDE is the secondary surface, and the remap ships in the same release as the switcher so the keys never mean two things at once.

## Alternatives considered

**Separate window stacks** (a Cockpit window class + an IDE window class, each workspace opening one or both). Doubles window-controller, toolbar, restoration, and menu-validation code; cross-deep-links degrade into window-finding heuristics; NSDocument's window-controller bookkeeping gets ambiguous about which window "is" the document; and the one-keystroke flip — the core UX promise — dies. The one thing it offers (both views visible at once) the chosen design already does better via two windows with independent per-window modes.

**Separate processes** (Cockpit app + IDE helper, XPC between). Every link traversal and citation click becomes IPC; the LinkIndex either duplicates per process or becomes a server; crash isolation buys nothing (both halves are ours, same codebase); state restoration and "same truth instantly" become a distributed-systems problem. Rejected without much grief.

**Web views for Cockpit surfaces.** Explicitly banned by PRD R1.2 ("No web views") and the native-speed principle in `CLAUDE.md`. Canvas surfaces (VPC/BMC/story maps) are exactly where web views feel worst on macOS (scrolling, drag, focus rings, accessibility). The IDE-axis advantage is native taste; the product layer doesn't get to betray it.

## Rollout (migration-free)

Gated on a new `FeatureFlags.cockpitView` (the existing `FeatureFlags` type at `CodeEdit/FeatureFlags.swift`):

- **Phase A — flag off (default):** `Features/Shell` lands; `ShellViewController` wraps the split VC but builds *only* the IDE child; no switcher UI, no ⌘1/⌘2, no keybinding remap. Behavior is pixel-identical to today. This de-risks the container refactor in isolation.
- **Phase B — flag on (dev):** switcher + `CockpitRootView` shell with the Studio placeholder; default mode **IDE**; ⌘1/⌘2 live; navigator tabs remapped to ⌃⌘1–9.
- **Phase C — Cockpit M1 real:** default mode for workspaces with no saved `viewMode` flips to **Cockpit** (PRD R0.1); saved per-project modes always win. Flag removed.

No data migration at any phase: the only persistence change is additive `WorkspaceStateKey` entries whose absence means "default".

## Consequences

**Easier:** Cockpit surfaces, IDE product toggles, and future surfaces (Pulse, Ask) all have designated mounting points and a uniform registry pattern; deep links are one parser + one router instead of scattered navigation calls; the two-window workflow falls out of per-window mode for free; the editor-less product layer is structurally enforced (Cockpit child never references editor UI).

**Harder / must maintain:** `ShellViewController` is a new indirection every window-content change goes through; the `splitViewController` computed-property change must be audited at all call sites; keeping both children alive raises per-window memory (acceptable — measured against `notes/perf-baseline.md`, and children are lazy until first use); the ⌃⌘1–9 remap needs documenting in keybindings help.

**Deferred:** registering `dynamite://` with macOS for external links; cross-workspace routing; lazy `EditorManager`/LSP init in `WorkspaceDocument`; Cockpit surfaces beyond Studio/Map.
