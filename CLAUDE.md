# CLAUDE.md — Dynamite

> Context for AI agents (Claude, Codex, Cursor) working in this repo. Read this first. Keep it current — it is the single source of truth for how to work here. If you change architecture, product scope, or conventions, update this file in the same change.

## What Dynamite is  
Dynamite is a native macOS **Product Studio** built on a fork of [CodeEdit](https://github.com/CodeEditApp/CodeEdit) (Swift / SwiftUI / AppKit): a product platform where product builders and product owners run discovery, strategy, planning, and customer development — grounded in the product's actual repo — and where that living knowledge compiles into the context external AI agents read.

**Positioning in one line:** Dynamite works *beside* agents (Claude, Codex, Cursor), never nests or orchestrates them. It is NOT an agent orchestrator and does not compete with Conductor/Intent. Ground Control is a fast native support environment, not the product; agents may optionally appear in-app via an extension surface only.

**The wedge (do not lose sight of this):** the **Product Graph** — 23 typed artifact kinds (catalog: `Dynamite Docs/decisions/ADR-0001-schema.md`) across discovery/strategy (personas, VPC, BMC, Lean Canvas, journeys, story maps, opportunity solution trees, competitor cards), planning (PRDs/specs/ADRs/OKRs/experiments), evidence (interviews/feedback/insights/assumptions), and GTM, each with AI Assist — made **repo-aware** (Repo X-Ray, Ask the Product, Reality Diff: a non-coder can see and query what the code actually does) and compiled into agent instruction files (canonical `AGENTS.md` + `CLAUDE.md` shim + per-folder context + Briefing Packs). That graph↔repo↔context link system is the moat. The product layer must work standalone — no editor pane, even no repo.

**App environments:** one app, one shared workspace, two separate top-level environments per window — **Product Studio** (default; product work, graph, docs, tasks, map, planning) ↔ **Ground Control** (CodeEdit-powered code review, source control, terminal, and optional agent-extension supervision). They should feel like distinct workspaces, not one overloaded shell; the bridge is the shared Product Graph, LinkIndex, repo citations, and context files. See `Dynamite Docs/ARCHITECTURE.md` (ADR-0006).

Key instruments: Repo X-Ray, Ask the Product, Reality Diff, Context Compiler, Context Lens, Briefing Packs, Drift Radar, Assumption Ledger, Interview Mode, Loop Ledger, Pulse, Decision Replay, Stakeholder Digest.

Product docs live in `Dynamite Docs/` (read in this order): `CONCEPT.md` (why & what, incl. vision), `MARKET.md` (evidence & landscape), `PRD.md` (v3 — requirements), `ROADMAP.md` (sequencing), `ARCHITECTURE.md` (codebase mapping), `DEVPLAN.md` (build plan + which AI model gets which task).

## What we are NOT building
- **Agent orchestration of any kind** — no nesting, running, or managing coding agents; no multi-agent panes or worktree fleets. We feed agents context via files; they run wherever the user likes.
- Our own coding model/agent.
- A cross-platform Electron/web app. Native macOS speed and taste is the advantage — protect it.
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
| Git & code review | `Features/SourceControl` | Diffs, review — **foundation for Ground Control change review** |
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

**`Features/Shell` (T1.4 — implemented):** `ShellViewController` is the window's `contentViewController` and wraps `CodeEditSplitViewController` (Ground Control) + `ProductStudioRootView` (Product Studio). All environment switches go through `ShellViewController.setViewMode(_:animated:)`. `Router` (on `WorkspaceDocument.router`) parses/generates `dynamite://` URLs and dispatches cross-deep-links. With `FeatureFlags.cockpitView = true`, Product Studio is the default, ⌘1 opens Product Studio, ⌘2 opens Ground Control, and navigator tabs are remapped to ⌃⌘1–⌘9. The visible switch lives in each environment's own navigation: Ground Control is pinned in the Product Studio sidebar, and Product Studio is pinned above the Ground Control navigator. Do not put a segmented environment toggle in the toolbar. **Invariant:** the product layer never depends on the editor being open or a repo being connected; no orchestration subsystem exists anywhere. See `Dynamite Docs/ARCHITECTURE.md`.

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

### Mandatory app build/run discipline
This repo can easily produce multiple apps with the same visible name. To avoid agents testing different binaries:

- Always build and launch branch work with `./script/build_and_run.sh --logs` or `./script/build_and_run.sh --verify`.
- Do not validate branch behavior with an Xcode/global DerivedData product or a stale copied app. The canonical branch app is `./.derivedData/Build/Products/Debug/Dynamite.app`, built from `./.SourcePackages`.
- `./script/build_and_run.sh` owns the local launch registration: after a successful build it archives stale `Dynamite.app` bundles from `/Applications`, `~/Applications`, and global Xcode DerivedData, then recreates `/Applications/Dynamite.app` as a symlink to the canonical branch app. Finder/Applications can be used as a convenience only after this script has run.
- After launching, verify the running command points at `/Users/mediaalamedia/dynamite/.derivedData/Build/Products/Debug/Dynamite.app/Contents/MacOS/Dynamite`. The build script now does this verification automatically.
- If editor behavior depends on patched Swift package checkouts, run `./scripts/apply-editor-perf-patch.sh` before building. Do not leave a direct checkout edit without updating the matching `patches/*.patch` file and the patch verifier.
- Before investigating UI bugs, stop existing `Dynamite` processes and relaunch with the script above so stale app copies cannot mask or reintroduce fixes.

## Product principles (use these to break ties)
1. **Product Studio is the product.** Ground Control and everything else supports it.
2. **Companion, not cage.** Never own the agent's runtime; feed it via files.
3. **Context is the moat.** Anything that strengthens the graph↔repo↔context links wins.
4. **Native speed is non-negotiable.** If a feature makes the app feel slow, redesign it.
5. **Opinionated structure over blank canvas.** Typed docs (PRD/Spec/ADR/Interview/Persona/VPC/BMC/Journey…), not freeform.
6. **Grounded or silent.** Repo-derived claims always carry citations.
7. **Right-size everything.** A small task gets a small briefing; no ceremony.
