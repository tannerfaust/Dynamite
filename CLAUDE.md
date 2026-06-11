# CLAUDE.md — Dynamite

> Context for AI agents (Claude, Codex, Cursor) working in this repo. Read this first. Keep it current — it is the single source of truth for how to work here. If you change architecture, product scope, or conventions, update this file in the same change.

## What Dynamite is
Dynamite is a native macOS **product ownership cockpit** built on a fork of [CodeEdit](https://github.com/CodeEditApp/CodeEdit) (Swift / SwiftUI / AppKit): a product platform where product builders and product owners run discovery, strategy, planning, and customer development — grounded in the product's actual repo — and where that living knowledge compiles into the context external AI agents read.

**Positioning in one line:** Dynamite works *beside* agents (Claude, Codex, Cursor), never nests or orchestrates them. It is NOT an agent orchestrator and does not compete with Conductor/Intent. The IDE inside is a fast native bonus, not the product; agents may optionally appear in-app via an extension surface only.

**The wedge (do not lose sight of this):** the **Product Graph** — 23 typed artifact kinds (catalog: `Dynamite Docs/decisions/ADR-0001-schema.md`) across discovery/strategy (personas, VPC, BMC, Lean Canvas, journeys, story maps, opportunity solution trees, competitor cards), planning (PRDs/specs/ADRs/OKRs/experiments), evidence (interviews/feedback/insights/assumptions), and GTM, each with AI Assist — made **repo-aware** (Repo X-Ray, Ask the Product, Reality Diff: a non-coder can see and query what the code actually does) and compiled into agent instruction files (canonical `AGENTS.md` + `CLAUDE.md` shim + per-folder context + Briefing Packs). That graph↔repo↔context link system is the moat. The product layer must work standalone — no editor pane, even no repo.

**App shell:** one app, two views per window — **Cockpit view** (default; the product surface) ↔ **IDE view** (classic editor with product-context toggles), shared workspace and link index, cross-deep-links. See `Dynamite Docs/ARCHITECTURE.md` (ADR-0006).

Key instruments: Repo X-Ray, Ask the Product, Reality Diff, Context Compiler, Context Lens, Briefing Packs, Drift Radar, Assumption Ledger, Interview Mode, Loop Ledger, Pulse, Decision Replay, Stakeholder Digest.

Product docs live in `Dynamite Docs/` (read in this order): `CONCEPT.md` (why & what, incl. vision), `MARKET.md` (evidence & landscape), `PRD.md` (v3 — requirements), `ROADMAP.md` (sequencing), `ARCHITECTURE.md` (codebase mapping), `DEVPLAN.md` (build plan + which AI model gets which task).

## What we are NOT building
- **Agent orchestration of any kind** — no nesting, running, or managing coding agents; no multi-agent panes or worktree fleets. We feed agents context via files; they run wherever the user likes.
- Our own coding model/agent.
- A cross-platform Electron/web app. Native macOS speed and taste is the only IDE-axis advantage — protect it.
- A full Notion/Linear/Productboard clone. Build only the planning surface that ties to code and agents.
- "AI everywhere." Differentiation is structured context discipline, not another chat box.

## Tech stack & environment
- **Language:** Swift, SwiftUI + AppKit, macOS only.
- **Build:** Xcode. Primary project: `Dynamite.xcodeproj` (forked from `CodeEdit.xcodeproj`). Dependencies via Swift Package Manager (`.SourcePackages`).
- **Lint:** SwiftLint (`.swiftlint.yml`) — run/respect it; do not introduce new lint violations.
- **Tests:** `CodeEditTests` (unit), `CodeEditUITests` (UI). Test plan: `CodeEditTestPlan.xctestplan`.
- **Min target / signing:** see `Configs/`.

## Codebase map (where things live)
Source root: `CodeEdit/` (the app still uses the CodeEdit module name internally). Feature-first organization under `CodeEdit/Features/`:

| Area | Folder | Notes |
|---|---|---|
| Text editing | `Features/Editor` | Core editor surface |
| Language servers | `Features/LSP` | LSP client integration |
| Git & code review | `Features/SourceControl` | Diffs, review — **foundation for the agent change-review cockpit** |
| Task running | `Features/Tasks` | **Hook point for agent task execution** |
| Terminal | `Features/TerminalEmulator` | Where agent CLIs (Codex/Claude Code) can run |
| File tree / nav | `Features/NavigatorArea` | |
| Inspectors | `Features/InspectorArea` | |
| Utility panels | `Features/UtilityArea` | Bottom panel host |
| Settings | `Features/Settings`, `Features/CEWorkspaceSettings` | App + per-workspace settings |
| Feedback | `Features/Feedback` | **Hook point for customer-dev / feedback module** |
| Extensions | `Features/Extensions` | Extension system |
| Commands / keybindings | `Features/Commands`, `Features/Keybindings` | |
| Quick open | `Features/OpenQuickly` | |
| Search | `Features/Search` | |
| Workspace model | `Features/CEWorkspace`, `Features/Documents` | Document & workspace state |

New product-layer features (`ProductGraph`, `RepoAwareness`, `ContextEngine`, `TruthLayer`, `LinkIndex`, `Shell`) are added as new folders under `CodeEdit/Features/` following the same MVVM + SwiftUI conventions.

**`Features/Shell` (T1.4 — implemented):** `ShellViewController` is the window's `contentViewController` and wraps `CodeEditSplitViewController` (IDE) + `CockpitRootView` (Cockpit). All mode switches go through `ShellViewController.setViewMode(_:animated:)`. `Router` (on `WorkspaceDocument.router`) parses/generates `dynamite://` URLs and dispatches cross-deep-links. Phase A (`FeatureFlags.cockpitView = false`): IDE only, pixel-identical. Phase B (`cockpitView = true`): ⌘1/⌘2 live, navigator tabs remapped to ⌃⌘1–⌘9. **Invariant:** the product layer never depends on the editor being open or a repo being connected; no orchestration subsystem exists anywhere. See `Dynamite Docs/ARCHITECTURE.md`.

## Conventions
- Follow the existing CodeEdit patterns: SwiftUI views + view models, feature-scoped folders, dependency injection via environment/observable objects already used in the codebase. Match surrounding style before inventing new patterns.
- Keep new UI native and fast. No web views for core surfaces. Performance and responsiveness are product values, not afterthoughts.
- Markdown is a first-class data type in Dynamite (specs, PRDs, docs). Prefer plain `.md` on disk so docs stay portable and git-friendly.
- Small, reviewable changes. One concern per change. Update tests and docs in the same change.

## How to work in this repo (for agents)
1. Read this file + the relevant doc in `Dynamite Docs/` before non-trivial work.
2. Locate the feature folder; read neighboring files to match patterns.
3. Make the change; keep it scoped; respect SwiftLint.
4. Add/adjust tests in `CodeEditTests` / `CodeEditUITests`.
5. If you touched product scope, architecture, or conventions, update this file and the relevant doc in `Dynamite Docs/`.
6. Build must pass and lint must be clean before you consider the task done.

## Product principles (use these to break ties)
1. **The product layer is the product.** The IDE and everything else supports it.
2. **Companion, not cage.** Never own the agent's runtime; feed it via files.
3. **Context is the moat.** Anything that strengthens the graph↔repo↔context links wins.
4. **Native speed is non-negotiable.** If a feature makes the app feel slow, redesign it.
5. **Opinionated structure over blank canvas.** Typed docs (PRD/Spec/ADR/Interview/Persona/VPC/BMC/Journey…), not freeform.
6. **Grounded or silent.** Repo-derived claims always carry citations.
7. **Right-size everything.** A small task gets a small briefing; no ceremony.
