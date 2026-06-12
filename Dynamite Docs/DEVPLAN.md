# Dynamite — Development Plan (prompt-driven, AI-orchestrated)

**Status:** v2 · **Owner:** Max · **Last updated:** 2026-06-10
Every task below is an **explicit prompt** plus a one-line statement of **which model to give it to**. Run them in order within a phase; respect "After:" dependencies. Requirements: `PRD.md` · order: `ROADMAP.md` · structure: `ARCHITECTURE.md`.

---

## How to use this file

1. Copy the task's prompt into the stated model/tool. Append the **Standard Footer** (below) to every implementation prompt.
2. **Escalation rule:** if the assigned model fails a task twice, stop. Re-run on Fable 5 with the failure transcript attached.
3. **Cross-check rule:** tasks marked ⚠ write into user repos or define the moat — their output must be reviewed by the named *second* model before merge.
4. Design tasks produce short specs/ADRs into `Dynamite Docs/decisions/` or `Dynamite Docs/notes/`; implementation tasks then reference them. Design once expensive, implement cheap.

**Model roster:** Fable 5 & Opus 4.8 ($$$$ — design, audits, hardest problems) · Gemini 3.1 Pro ($$$ — long-context comprehension & review) · Sonnet 4.8 ($$ — implementation workhorse, in Claude Code) · Composer 2.5 ($$ — live UI iteration, in Cursor) · Gemini 3.5 Flash High ($ — bulk drafting) · Auto in Cursor ($ — chores).

**Standard Footer (append to every implementation prompt):**
> Before coding, read `CLAUDE.md` and the relevant sections of `Dynamite Docs/ARCHITECTURE.md` and `Dynamite Docs/PRD.md`. Match existing CodeEdit patterns (SwiftUI + observable view models, feature-scoped folders). Definition of done: builds clean in Xcode, SwiftLint zero new violations, unit tests added in `CodeEditTests` (UI tests in `CodeEditUITests` where UI is involved), no editor-UI dependency leaks into product-layer features, no orchestration code anywhere, and the relevant doc in `Dynamite Docs/` updated in the same change. Keep the change scoped to this task only.

---

## Phase 0 — Foundation hygiene

### T0.1 — Comprehension pass over inherited CodeEdit internals
**Give to: Gemini 3.1 Pro** (long context)
> Read the Dynamite repo (a CodeEdit fork) end to end, focusing on `CodeEdit/Features/CEWorkspace`, `Features/Documents`, `Features/SourceControl`, `Features/InspectorArea`, `Features/UtilityArea`, `Features/Settings`, `Features/Extensions`, and the window/controller architecture that hosts them. Produce `Dynamite Docs/notes/codeedit-internals.md` (≤300 lines): for each subsystem — its responsibilities, key types, state flow, extension points, and pitfalls. End with a section "What to reuse vs. avoid for: (a) a standalone product-doc workspace, (b) a second top-level view mode per window, (c) a backlinks inspector panel." Cite file paths for every claim.

### T0.2 — CI gates
**Give to: Auto in Cursor**
> Add a GitHub Actions workflow that on every PR: builds `Dynamite.xcodeproj` (macOS), runs SwiftLint with `--strict` on changed files, and runs `CodeEditTests` via the `CodeEditTestPlan.xctestplan`. Fail the PR on any error. Cache SPM dependencies. Don't change any lint rules.

### T0.3 — Performance baseline & IDE surface audit
**Give to: Sonnet 4.8** (in Claude Code) · After: T0.1
> Using `Dynamite Docs/notes/codeedit-internals.md`, produce and implement a small plan that (1) records a performance baseline (cold launch, workspace open, file open, search) as a markdown table in `Dynamite Docs/notes/perf-baseline.md` with the measurement method, and (2) identifies IDE menu items/panels irrelevant to Dynamite's direction (see CLAUDE.md) and hides them behind a single `FeatureFlags` type rather than deleting. Do not remove functionality; park it.

### T0.4 — Doc review parity (.md diffs)
**Give to: Sonnet 4.8**; UI polish afterwards by **Composer 2.5** · After: T0.1
> Implement polished Markdown diff rendering in the existing SourceControl diff surface: word-level inline highlighting for prose, side-by-side and inline modes, and front-matter changes rendered as a readable key/value table instead of raw text. Reuse the existing diff infrastructure in `Features/SourceControl`; add `MarkdownDiff` rendering components beside it. Acceptance: diffing a 200-line PRD revision is as readable as a code diff.

---

## Phase 1 — App shell + Product Studio

### T1.1 — ADR-0001: Product Graph data model ⚠
**Give to: Fable 5** · Cross-check: **Opus 4.8** (fresh session, ask it to attack the design)
> Act as chief architect of Dynamite (read `CLAUDE.md`, `Dynamite Docs/PRD.md` §M1, `ARCHITECTURE.md`). Write ADR-0001 deciding the Product Graph data model: (1) front-matter schema for all 22 artifact kinds (shared core fields: id, kind, status, created, updated; per-kind fields kept minimal); (2) the typed-link representation in front-matter (human-readable, git-merge-friendly) for edges implements/validates/contradicts/supersedes/derived-from, including links to code targets (file path + optional symbol + content-hash anchor for rename survival); (3) the rebuildable local index (store choice: SQLite vs flat cache; invalidation; rebuild-from-files guarantee); (4) folder layout under the project's `product/` directory. Constraints: plain `.md` always authoritative; index always disposable; a user editing files in any other editor must never corrupt the graph. Deliver: the ADR + a `schema.md` appendix with one complete example file per category (canvas kind, doc kind, evidence kind).

### T1.2 — ADR-0006: App shell — one app, two views
**Give to: Fable 5** · After: T0.1
> Read `Dynamite Docs/ARCHITECTURE.md` §"App shell" and `notes/codeedit-internals.md`. Write ADR-0006 formalizing the one-app/two-views architecture: how a per-window view mode (Cockpit ↔ IDE, ⌘1/⌘2) integrates with the existing CodeEdit window controller; where Cockpit surfaces mount; the deep-link routing scheme (node → file/line, file → node context) including a URL-style internal route format; state restoration per project; and how both views share one `CEWorkspace` session and `LinkIndex`. Decide explicitly against: separate window stacks, separate processes, web views. Include a migration-free rollout plan (IDE view = current behavior, Cockpit added).

### T1.3 — LinkIndex implementation ⚠
**Give to: Sonnet 4.8** · Cross-check: **Gemini 3.1 Pro** reviews the diff · After: T1.1
> Implement `Features/LinkIndex` exactly per ADR-0001: parse front-matter links from all `.md` under the product folder, maintain the rebuildable index, expose query API (outgoing/incoming edges by node, by kind, by link type), watch the filesystem for changes, survive file renames via the content-hash anchors, and surface broken links as a published diagnostics collection (never auto-delete). Include a `rebuildIndex()` that reconstructs everything from files alone, and property tests proving: rebuild idempotence, rename survival, and broken-link detection.

### T1.4 — Shell: view switcher + routing
**Give to: Sonnet 4.8**; visual polish by **Composer 2.5** · After: T1.2
> Implement `Features/Shell` per ADR-0006: per-window Cockpit/IDE mode with ⌘1/⌘2 switcher and toolbar control, mode persistence per project, the internal route format, and cross-deep-link handling (route from a graph node citation to IDE view at file/line; from a file to its product context). Cockpit view starts as an empty registered surface container that Studio features will fill (T1.6+). IDE view must remain pixel-identical to current behavior.

### T1.5 — Artifact templates (22 kinds)
**Give to: Gemini 3.5 Flash High**; Max reviews for taste · After: T1.1
> Using the ADR-0001 schema, draft the 22 template `.md` files for Dynamite's artifact kinds: Problem, Persona, Value Proposition Canvas, Business Model Canvas, Lean Canvas, Customer Journey Map, User Story Map, Opportunity Solution Tree, Competitor Card, Market Note, PRD, Spec, ADR, Roadmap Item, OKR/Metric, Experiment, Research Note, Customer Interview, Feedback, Insight, Assumption, Positioning/GTM Brief, Landing Page Draft. Each: correct front-matter, section headings with one-line italic guidance per section, and a tiny filled example in a comment. Tone: opinionated, terse, jargon-free. Canvas kinds must structure their blocks as front-matter-addressable sections so native board views can bind to them.

### T1.6 — Typed-doc editor + template flow
**Give to: Sonnet 4.8** · After: T1.3, T1.5
> Implement the core of `Features/ProductGraph`: "New artifact" flow (kind picker → templated `.md` created in the right folder), a fast native Markdown editing surface for artifact docs (reuse the existing editor component), front-matter rendered as a friendly header form (status, kind, dates, links) instead of raw YAML, and kind/status badges in the file tree and quick-open. Editing must work in Cockpit view without any IDE panes.

### T1.7 — Native board/canvas views
**Give to: Composer 2.5** (iterate live); data binding reviewed by **Sonnet 4.8** · After: T1.6
> Build native SwiftUI board views over the artifact `.md` files for: Value Proposition Canvas, Business Model Canvas, Lean Canvas (block grids); Customer Journey Map and User Story Map (column/lane boards); Opportunity Solution Tree (tree layout); Roadmap (Now/Next/Later columns). Each view binds two-way to the front-matter-addressable sections defined by the templates (T1.5) — editing a card edits the `.md`. Native only, no web views; drag to reorder; every card can hold typed links rendered as chips. Target feel: as fast as Things, as clear as a printed canvas.

### T1.8 — Backlinks panel + product map + graph search
**Give to: Sonnet 4.8**; map layout polish by **Composer 2.5** · After: T1.3
> Implement (1) a Backlinks inspector panel (`Features/InspectorArea`) showing incoming/outgoing typed links for the focused artifact or file with one-click navigation; (2) the Product Map: a zoomable native graph view of nodes colored by kind, filterable by kind/status/link-type, with the same deep-link routing as the Shell; (3) graph-aware search and quick-open (kind: and status: filters). Keep 60fps on a 500-node graph — virtualize if needed.

### T1.9 — ADR-0007 + AIAssist interface ⚠
**Give to: Fable 5** (ADR) then **Sonnet 4.8** (implementation) · Cross-check: **Gemini 3.1 Pro** · After: T1.1
> First, write ADR-0007: the thin `Features/AIAssist` interface for artifact-level AI calls — provider abstraction (Anthropic/OpenAI/Google, BYO API key in Settings, streaming), a `ContextBundle` type that gathers an artifact + its linked nodes for grounding, cost guardrails (per-call token caps, user-visible spend estimate), and an explicit rule that AIAssist performs single request/response assistance only — no sessions, no tool-use loops, no agent runtime. Then implement it with three operations wired into the artifact editor UI: **Draft** (generate content for an empty artifact from prompt + linked nodes), **Refine** (improve selection per instruction), **Cross-check** (compare claims against linked evidence nodes; output a discrepancy list). Show grounding sources in the result UI.

### T1.10 — Standalone-mode audit
**Give to: Fable 5** (audit); mechanical fixes by **Auto in Cursor** · After: T1.6–T1.9
> Audit Phase-1 code against the architectural invariant in `ARCHITECTURE.md`: the product layer must function with no editor pane and no repo. Trace imports and runtime dependencies of `ProductGraph`, `LinkIndex`, `AIAssist`, `Shell`-Cockpit surfaces; list every violation with file/line and a minimal fix. Also verify: deleting the index and relaunching rebuilds the graph losslessly. Output a checklist; apply the trivial fixes yourself, file the non-trivial ones as tasks.

### T1.11 — Phase 1 test sweep
**Give to: Sonnet 4.8**; scaffolds by **Gemini 3.5 Flash High**
> Bring Phase-1 features to solid coverage: unit tests for LinkIndex queries and rebuild, template parsing of all 22 kinds, front-matter round-tripping (board edit → md → board), route parsing; UI tests for new-artifact flow, view switcher, backlinks navigation. Use the test scaffolds provided; make them meaningful, not theatrical.

---

## Phase 2 — Repo Awareness + Context Engine

### T2.1 — ADR-0002: repo analysis engine ⚠
**Give to: Fable 5**; evidence gathered first by **Gemini 3.1 Pro** ·
> (Gemini, first:) Survey approaches for letting a macOS app understand a codebase well enough to explain it to non-programmers: SwiftSyntax/tree-sitter static indexing, LSP-derived symbols, agent-assisted summarization (cost/privacy/latency), and hybrids; summarize trade-offs in `notes/repo-analysis-options.md` with citations. (Fable 5, then:) Write ADR-0002 choosing Dynamite's engine. Constraints: read-only by default, never blocks UI, works offline for the structural layer, AI summarization layered on top through AIAssist with caching, every produced claim must carry a file/symbol citation, and language support starts with Swift + TS/JS + Python. Define the index schema and refresh strategy.

### T2.2 — Repo connect + structural indexer
**Give to: Sonnet 4.8** · After: T2.1
> Implement `Features/RepoAwareness` foundation per ADR-0002: connect a local clone (read-only), background structural indexing (modules, files, symbols, dependencies, entry points), incremental refresh on git HEAD change, progress UI that never blocks. Expose a query API consumed by X-Ray, Ask the Product, and doc↔code linking. Include the citation type (file, symbol, line range, commit) used everywhere downstream.

### T2.3 — Doc↔code links
**Give to: Sonnet 4.8** · After: T2.2, T1.3
> Extend LinkIndex and the linking UI so specs/PRDs link to code targets (files/symbols) using ADR-0001 anchors: link picker with repo search, backlinks both directions (file's inspector shows its specs; spec shows implementing code with live valid/moved/missing status), and bulk re-anchoring when the indexer detects renames. Acceptance: PRD R2.5.

### T2.4 — X-Ray summarization design
**Give to: Opus 4.8** (prompt/pipeline design); then **Sonnet 4.8** implements · After: T2.2
> Design the Repo X-Ray summarization pipeline: how structural index data + AIAssist calls produce a plain-language, citation-backed map of what the product does — feature/flow detection heuristics, per-module summaries written for a non-programmer (8th-grade reading level, no jargon), confidence labels (derived-from-code vs inferred), caching and incremental re-summarization on change, and token budgets per repo size. Deliver `notes/xray-pipeline.md` with the exact prompt templates. (Then Sonnet: implement the pipeline and the X-Ray browsing UI in Cockpit view — feature list → flows → modules → drill to cited code peek — per that note.)

### T2.5 — Ask the Product ⚠
**Give to: Sonnet 4.8**; retrieval design by **Fable 5**; answer-quality review by **Opus 4.8** · After: T2.2, T2.4
> (Fable 5, first:) design the grounded-QA retrieval: how a natural-language question selects graph nodes + index entries + X-Ray summaries as context, and the answer contract — every sentence cited or labeled as uncertain, "I don't know" preferred over guessing; write `notes/ask-the-product.md`. (Sonnet:) implement the Ask the Product panel in Cockpit view per that note: question box, streaming answer with citation chips (click → code peek or node), history per project. Hard rule from CLAUDE.md: grounded or silent.

### T2.6 — ADR-0003 + Context Compiler ⚠⚠
**Give to: Fable 5** (ADR) then **Sonnet 4.8** (implementation) · Cross-check: **Gemini 3.1 Pro** line-by-line on the merge engine ·
> (Fable 5:) Write ADR-0003: compiled-context file management — canonical `AGENTS.md` + thin `CLAUDE.md` shim (`@AGENTS.md` import), per-folder context files; compiler-owned regions delimited by explicit markers vs user-owned regions that always survive; deterministic generation (same graph → byte-identical output); conflict and corruption recovery; what graph slices compile by default per PRD R3.1. (Sonnet:) Implement `Features/ContextEngine` compiler per the ADR: inclusion config UI, recompile-on-change with debounce, regeneration shown as a reviewable diff before write (auto-mode opt-in). This code writes into users' repos — maximum care; property tests: idempotence, user-region survival under any compiler change, no write outside declared targets.

### T2.7 — Context Lens
**Give to: Sonnet 4.8**; UI by **Composer 2.5** · After: T2.6
> Implement Context Lens: for a chosen scope (repo root, folder, or a specific task/spec), render exactly what an agent reading the compiled files would see — assembled, in order, with each block traceable to its source node (hover → highlight source). Include a staleness indicator per block and a "recompile" affordance. This is a read-only viewer over ContextEngine output; no new compilation logic.

### T2.8 — Briefing Packs
**Give to: Sonnet 4.8** · After: T2.6
> Implement Briefing Packs: from any Spec/Roadmap Item/Task-like artifact, generate a right-sized, self-contained context packet — the artifact, its relevant linked nodes, pertinent X-Ray excerpts, and repo conventions — sized by a small heuristic (bug-fix → ≤1 page; feature → spec slice; new module → full slice) defined in the implementation note. Output: a file under `product/briefings/` and/or clipboard. Every line traceable to a source node. Add "Generate Briefing Pack" to artifact context menus and the Cockpit toolbar.

### T2.9 — Phase 2 test sweep + compiler fuzzing
**Give to: Sonnet 4.8** · After: T2.6–T2.8
> Tests: indexer incremental correctness; doc↔code anchor survival across renames/moves; compiler fuzz tests (random user edits inside and outside owned regions across 1,000 generated cases — user content must never be lost); Ask-the-Product citation integrity (no uncited assertive sentence passes); Briefing Pack size heuristics.

---

## Phase 3 — Truth & Learning

### T3.1 — ADR-0004: drift & reality signals
**Give to: Fable 5**
> Write ADR-0004: how Dynamite computes (1) stale compiled context (cheap: source-node timestamps vs compile time), (2) spec↔code drift (tiers: link-anchor invalidation → structural diff of linked symbols → opt-in AI semantic comparison with per-run cost cap), (3) assumption↔evidence contradiction (graph rule on contradicts edges + AI cross-check). Define signal confidence levels, where each surfaces (file tree, backlinks, Pulse), and the cost-control budget.

### T3.2 — Drift Radar + Reality Diff
**Give to: Sonnet 4.8**; report UX by **Composer 2.5** · After: T3.1
> Implement per ADR-0004 in `Features/TruthLayer`: Drift Radar badges and the one-click recompile for stale context; Reality Diff — a readable per-spec report (matches / diverged / not implemented, with citations and a plain-language explanation of each divergence) accessible from the spec, the file, and Pulse.

### T3.3 — Assumption Ledger
**Give to: Sonnet 4.8** · After: T1.7
> Implement the Assumption Ledger view: all Assumption nodes with status (untested/validating/validated/falsified), linked evidence counts, and origin canvas block (VPC/BMC/Lean). Status changes require an evidence link or an explicit override note. Falsifying an assumption flags downstream linked specs/PRDs (uses contradicts/derived-from edges). Board and table layouts.

### T3.4 — Interview Mode
**Give to: Sonnet 4.8**; extraction prompts designed by **Opus 4.8** · After: T1.9
> (Opus: design the extraction prompt set — from a pasted/imported conversation transcript: candidate Insights with verbatim quotes, links proposed to existing Personas/Assumptions, contradiction flags, never-invent rule; deliver as `notes/interview-extraction.md`.) (Sonnet: implement Interview Mode per the note: paste/import transcript into a Customer Interview artifact → AIAssist extraction → user reviews each proposed Insight/link as accept/edit/reject cards → accepted items become real nodes with links.) Nothing enters the graph without explicit user acceptance.

### T3.5 — Loop Ledger
**Give to: Sonnet 4.8** · After: T2.3
> Implement the Loop Ledger: automatic trace records connecting evidence → insight → decision/spec → code change (via doc↔code links + repo history) → shipped (commit/tag). Store as append-only `.md` records under `product/loops/`; render as a searchable timeline; each loop openable to its full chain. Expose a read-only query API (used by Pulse, Digest, Decision Replay).

### T3.6 — Pulse
**Give to: Composer 2.5** (dashboard UI) + **Sonnet 4.8** (data feeds); repo-change narration prompts by **Opus 4.8** · After: T3.2, T3.3, T3.5
> Build Pulse, the Cockpit's default morning screen: assumption status summary, drift/reality flags, loop velocity, open questions, and "what changed in the repo, in product language" (AIAssist narration of recent commits grouped by feature, cited). Every tile deep-links to its feature. Loads instantly from cached data; refresh is background.

### T3.7 — Decision Replay + Stakeholder Digest
**Give to: Sonnet 4.8**; digest templates by **Gemini 3.5 Flash High** · After: T3.5
> Implement (1) Decision Replay: select any ADR/decision-bearing node → chronological replay of its evidence chain (interviews, insights, assumptions, alternatives, outcome) as a navigable story view; (2) Stakeholder Digest: AIAssist-drafted weekly/monthly update from Pulse + Loop Ledger using the provided templates (investor / team / customer variants), always opened as an editable draft artifact, never auto-sent.

### T3.8 — Phase 3 test sweep
**Give to: Sonnet 4.8**
> Tests: drift-signal tiers fire correctly on synthetic repos; assumption status rules (no status change without evidence/override); interview extraction acceptance flow (nothing enters graph unaccepted); loop record integrity; Pulse tile data correctness against fixtures.

---

## Continuous track

### TC.1 — ADR-0005: agent extension surface
**Give to: Fable 5**
> Write ADR-0005: the thinnest viable way to optionally use Claude/Codex *inside* Dynamite (chat panel, inline results) via `Features/Extensions` — evaluate MCP client vs Claude Agent SDK vs CLI wrap. Hard constraints from CLAUDE.md: no orchestration (no sessions management beyond one visible conversation, no worktrees, no parallel agents); the extension may read Briefing Packs and compiled context; uninstallable without trace.

### TC.2 — Extension implementation
**Give to: Sonnet 4.8** · After: TC.1, T2.8
> Implement the agent extension per ADR-0005 with a polished native chat surface that can attach a Briefing Pack or Context Lens scope as the conversation's grounding. Nothing else.

### TC.3 — Upstream CodeEdit merges (recurring)
**Give to: Gemini 3.1 Pro** (summarize upstream diff, flag conflicts with our invariants) → **Sonnet 4.8** (perform merge)
> (Gemini:) Read the upstream CodeEdit changes since our last merge point; produce a summary listing: safe-to-take, conflicts-with-our-shell/product-layer, and skip. (Sonnet:) execute the merge accordingly.

### TC.4 — Docs & changelog upkeep (recurring)
**Give to: Gemini 3.5 Flash High / Auto in Cursor**
> After each merged feature: update CHANGELOG.md, refresh affected sections of `Dynamite Docs/`, and keep root `CLAUDE.md` truthful per its own rule. Commit messages: conventional, one concern each.

### TC.5 — Monthly market refresh (recurring)
**Give to: Gemini 3.1 Pro**
> Re-verify `Dynamite Docs/MARKET.md`: pricing/feature changes at ChatPRD, Product Lab, Productboard; any PM tool gaining repo access; AGENTS.md standard changes; new entrants in the product-platform-meets-repo space. Output a dated delta section; flag anything that threatens the positioning map.

### TC.6 — Weekly architecture hour (recurring)
**Give to: Fable 5**
> Review this week's merged diffs against the invariants in `ARCHITECTURE.md` and `CLAUDE.md`: product layer independent of editor UI; no orchestration code; grounded-or-silent citations; plain-md authority; native-speed regressions (check perf baseline). Output: violations with file/line and proposed fixes, or a clean bill.

---

## Milestone acceptance (run after each phase)
- **Phase 1:** a founder completes persona → VPC → assumptions → PRD fully linked and AI-drafted, in Cockpit view only, with no repo connected. Faster and nicer than Product Lab/ChatPRD.
- **Phase 2:** a non-coder answers "do we support refunds, and where?" with citations; a Claude Code session run from a plain terminal visibly improves with Dynamite-compiled context; Context Lens explains why.
- **Phase 3:** a decision traces from customer quote to shipped commit; the weekly digest drafts itself; drift never silently accumulates.
