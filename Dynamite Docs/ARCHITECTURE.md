# Dynamite — Architecture

How the product layer maps onto the existing CodeEdit codebase. Design orientation, not a final spec; concrete decisions get ADRs (template below, store in `Dynamite Docs/decisions/`). Aligned with `PRD.md` v3.

## Base
- Swift, SwiftUI + AppKit, macOS only. Forked from CodeEdit.
- Feature-first organization under `CodeEdit/Features/` (app still uses the `CodeEdit` module name internally).
- MVVM-ish: SwiftUI views + observable view models, feature-scoped folders, SPM dependencies.

## Architectural invariant (from PRD G5/G6)
The product layer (`ProductGraph`, `RepoAwareness`, `ContextEngine`, `TruthLayer`) must run with **no editor pane open and no repo connected** (degrading gracefully). It depends on the workspace/document model, never on editor UI. No orchestration subsystem exists anywhere in the codebase.

## App shell — one app, two views (decided: `decisions/ADR-0006-app-shell-one-app-two-views.md`)
Not two subapps. **One app, one shared workspace, two top-level views per window:**

- **Cockpit view (default):** the product ownership surface — Studio, maps/canvases, Pulse, Ask the Product, ledgers. Contains lightweight **read-only code peeks** (citation popovers, X-Ray drill-downs) so a non-coder never needs the IDE view.
- **IDE view:** the classic CodeEdit layout, with **product toggles** — inspector panels showing the graph context of the current file (its spec, decisions, assumptions) and quick actions (open in Cockpit, add link).
- **Switcher:** per-window toggle (⌘1 Cockpit / ⌘2 IDE), mode remembered per project; two windows may show both views of the same workspace simultaneously. Think Cursor's Editor↔Agent switch, inverted: Cockpit is primary, IDE is the one toggle away.
- **Cross-deep-links:** any citation/node in Cockpit opens the IDE view at file/line; any file in IDE surfaces its product context. Both views sit on the same `CEWorkspace` session and `LinkIndex` — this is *why* it must be one app: two apps would sever the link graph and double maintenance.
- **Implementation:** new `Features/Shell` — view-mode state machine, switcher UI, routing/deep-links. Cockpit surfaces register as navigator/utility-style areas within the existing window controller architecture rather than a parallel window stack.

## Existing features we build on
| Capability | Existing folder | How we use it |
|---|---|---|
| Workspace/docs | `Features/CEWorkspace`, `Features/Documents` | Workspace state; extended to index the product-docs folder and host standalone (editor-less) sessions |
| Git | `Features/SourceControl` | Repo history for Loop Ledger; doc/code diff rendering (doc review parity) |
| Inspector | `Features/InspectorArea` | Backlinks panel: which spec/decision a file serves, and vice versa |
| Utility area | `Features/UtilityArea` | Host for Ask-the-Product, Drift/Reality reports |
| Feedback | `Features/Feedback` | Seed of Interview Mode / feedback capture |
| Settings | `Features/Settings`, `Features/CEWorkspaceSettings` | Compiler config, repo-connect config |
| Editor/terminal/LSP | `Features/Editor`, `Features/TerminalEmulator`, `Features/LSP` | The bonus IDE — maintained, not expanded |
| Extensions | `Features/Extensions` | Vehicle for the optional in-app agent UI (M5/R5.3) |

## New features to add (under `CodeEdit/Features/`)
- **`Features/ProductGraph`** — typed-doc model (all 23 kinds per PRD R1.1; catalog in `decisions/ADR-0001-schema.md`), templates, native board/canvas views (VPC/BMC/Lean/Journey/Story Map/OST/Roadmap) over `.md` + front-matter, typed links + backlinks, product map, graph search. The core product. (Phase 1) **Board views (T1.7):** `Board/` — `CanvasBodyParser` (H2/H3/list ↔ markdown), `ArtifactBoardView` dispatcher, per-kind grids/columns/tree; `RoadmapBoardView` aggregates `roadmap-item` by `horizon`; card-level typed links as indented `{ rel, to }` lines; Studio **Board/Source** toggle in `ArtifactEditorView`.
- **`Features/RepoAwareness`** — read-only repo indexing; Repo X-Ray model + views; Ask-the-Product (grounded Q&A with citations); doc↔code links. (Phase 2)
- **`Features/ContextEngine`** — Context Compiler (canonical `AGENTS.md` + `CLAUDE.md` shim + per-folder files; owned-regions merge), Context Lens preview, Briefing Pack generator, Drift Radar. Pure file output — no agent runtime. (Phase 2–3)
- **`Features/TruthLayer`** — Assumption Ledger, Interview Mode, Loop Ledger, Pulse dashboard, Decision Replay, Stakeholder Digest. (Phase 3)
- **`Features/LinkIndex`** — the shared doc↔doc↔code link index: human-readable links in front-matter, rebuildable local index for speed. The moat's plumbing; everything above sits on it. (Phase 1, grows in 2)
- **`Features/Shell`** — the one-app/two-views switcher, view-mode state, cross-deep-link routing (see App shell section). (Phase 1) **Implemented (T1.4):** `ShellViewController` (mode container), `ViewMode`, `DynamiteRoute`, `Router`, `CockpitSurface` + `CockpitSurfaceRegistry`, `CockpitRootView` (empty placeholder), `ViewModeSwitcherToolbarView`. Gated on `FeatureFlags.cockpitView` (Phase A default: off).
- **`Features/AIAssist`** — thin internal interface for artifact-level AI calls (draft/refine/cross-check, X-Ray summarization, insight extraction). Model-agnostic, BYO-key capable, no agent runtime. (Phase 1, grows in 2–3)

Explicitly **not** added: any `Features/Agents` / agent-orchestration module. All internal AI assistance (X-Ray analysis, insight extraction, artifact drafting) goes through `Features/AIAssist` — see ADR-0007.

## Key technical decisions to make (open — write ADRs)
1. **Link/metadata storage.** Front-matter links + `.gitignore`d rebuildable index DB. → **Decided:** `decisions/ADR-0001-product-graph-data-model.md` (SQLite/GRDB index, id-based links, `product/` category layout).
2. **Repo analysis engine.** Local static analysis (SwiftSyntax/tree-sitter) vs. agent-assisted indexing vs. hybrid; cost and privacy. → ADR-0002.
3. **Compiler merge semantics.** Compiler-owned vs. user-owned regions in AGENTS.md/CLAUDE.md; conflict rules. → ADR-0003.
4. **Drift/Reality-Diff signal.** Heuristics (links, timestamps) first; semantic agent check later with cost controls. → ADR-0004.
5. **Agent extension surface.** Thinnest viable in-app agent UI (MCP client vs. Agent SDK vs. plain CLI wrap). → ADR-0005.
6. **App shell.** Formalize the one-app/two-views decision above: window/view-mode architecture, deep-link routing, Cockpit surface registration. → **Decided:** `decisions/ADR-0006-app-shell-one-app-two-views.md` (`ShellViewController` mode container, `dynamite://` routes, `FeatureFlags.cockpitView` rollout).
7. **AI Assist backend.** How artifact-level AI assists (draft/refine/cross-check) call models: BYO API key vs. bundled; one thin internal `AIAssist` interface, no agent runtime. → ADR-0007.

## Principles for new code
- Product layer first: never let an editor dependency creep into `ProductGraph`/`ContextEngine`/`TruthLayer`.
- Keep core surfaces native and fast; no web views.
- Plain `.md` + front-matter on disk for all product artifacts; the index is always rebuildable from files.
- All repo-derived claims carry citations (file/symbol); no uncited assertions in X-Ray or Ask-the-Product.
- Match existing CodeEdit patterns before introducing new ones.

---

## ADR template
Copy into `Dynamite Docs/decisions/ADR-NNNN-title.md`:

```markdown
# ADR-NNNN: <title>
- Status: proposed | accepted | superseded
- Date: YYYY-MM-DD
- Deciders: <names>

## Context
What's the situation and the forces at play?

## Decision
What we chose.

## Alternatives considered
Option A — pros/cons. Option B — pros/cons.

## Consequences
What gets easier, what gets harder, what we now must maintain.
```
