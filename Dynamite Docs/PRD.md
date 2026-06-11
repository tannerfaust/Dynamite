# Dynamite — Product Requirements Document (PRD)

**Status:** Draft v3 · **Owner:** Max · **Last updated:** 2026-06-10
**Supersedes:** v2. Concept in `CONCEPT.md`; evidence in `MARKET.md`; sequencing in `ROADMAP.md`; codebase mapping in `ARCHITECTURE.md`; build plan in `DEVPLAN.md`.

---

## 1. Summary

Dynamite is a native macOS **product ownership cockpit**: a product platform (typed discovery/strategy/planning artifacts — the **Product Graph**) that is grounded in the product's actual repo (**Repo Awareness**) and compiles into the context files external AI agents read (**Context Engine**: `AGENTS.md` canonical + `CLAUDE.md` shim + briefing packs). Agents like Claude Code and Codex work *beside* Dynamite — in terminals, clouds, or optionally inside via an extension surface — never nested or orchestrated by it. A fast native IDE (CodeEdit fork) is included as a bonus capability, strategically demoted: nothing in the product layer depends on it.

v3 direction change: the product layer *is* Phase 1 (was the Review Cockpit); agent orchestration is out of scope permanently; Repo Awareness (X-Ray, Ask the Product, Reality Diff) added as the differentiator; IDE demoted to a supporting layer.

## 2. Problem

Product builders and product owners do product work — discovery, customer development, planning, deciding — in tools that cannot see the product's reality (Notion, ChatPRD, Product Lab), while the ground truth lives in a repo only engineer tools can read. Meanwhile their agents run on hand-written, perpetually stale context files. Result: product decisions ungrounded, agents under-briefed, the "why" lost. See `MARKET.md`.

## 3. Goals & non-goals

### Goals
- **G1 — Product Studio:** the best native workspace for typed product artifacts and the links between them; instant value with no repo and no code skills.
- **G2 — Repo Awareness:** let a non-coding product owner see, query, and verify what their product actually does, from the code, in plain language.
- **G3 — Context Engine:** compile the graph into `AGENTS.md`/`CLAUDE.md`/per-folder context and right-sized briefing packs; inspectable (Context Lens); drift-checked.
- **G4 — Truth & learning:** assumptions tracked against evidence; every loop (feedback → decision → spec → shipped change) traceable.
- **G5 — Agent-agnostic by construction:** all output is plain files in the repo; works identically with any agent, anywhere. Optional in-app agent UI only as an extension.
- **G6 — IDE as bonus:** fast, native, excellent, out of the way.

### Non-goals (permanent unless revisited post-PMF)
- Agent orchestration: no nesting, running, scheduling, or managing coding agents; no multi-agent panes; no worktree management. (Conductor/Intent's fight, not ours.)
- Our own coding model. Cross-platform. Real-time multiplayer. Generic Notion/Linear/Productboard parity. Mobile.

## 4. Target users

- **Primary — the product builder:** founder/indie who owns problem, customers, value prop, roadmap; ships via agents; may look at code occasionally, never lives in it.
- **Primary — the product owner / PM / CEO on a team:** runs product-oriented tasks (customer development, planning, verification) against a repo they don't personally edit. Today forced into Cursor/terminal just to ask their product questions.
- **Secondary:** small teams (2–8) sharing one product brain.
- **Not targeting yet:** enterprises, cross-platform shops.

## 5. Principles (tie-breakers)
1. The product layer is the product; everything else supports it.
2. Context is the moat — strengthen the graph↔repo↔context links above all.
3. Companion, not cage: never own the agent's runtime.
4. Native speed is non-negotiable.
5. Opinionated structure over blank canvas.
6. Right-size everything — a small task gets a small briefing; no ceremony.
7. Plain files, open standards, zero lock-in.

## 6. Requirements by module

### M0 — App shell: one app, two views *(Phase 1, with M1)*
- **R0.1 Cockpit view (default).** The product ownership surface: Studio, maps/canvases, Pulse, Ask the Product, ledgers. Includes read-only code peeks (citation popovers, X-Ray drill-down) so a non-coder never needs the IDE view.
- **R0.2 IDE view.** Classic CodeEdit layout with **product toggles**: inspector panels showing the current file's graph context (spec, decisions, assumptions) and quick actions (open in Cockpit, add link).
- **R0.3 Switcher.** Per-window toggle (⌘1/⌘2), mode remembered per project; two windows can show both views of one workspace. Cross-deep-links both ways (citation → file/line; file → product context).
- **Rationale:** not two subapps — one shared workspace and LinkIndex; two apps would sever the graph and double maintenance. See `ARCHITECTURE.md` (ADR-0006).
- **Acceptance:** a PO lives entirely in Cockpit view; an engineer lives in IDE view with product context one toggle away; both see the same truth.

### M1 — Product Studio *(Phase 1 — ship first)*
- **R1.1 Typed documents — the full product-ownership catalog** (each a templated kind, plain `.md` + front-matter on disk):
  - *Discovery & strategy:* Problem, Persona, Value Proposition Canvas, Business Model Canvas, Lean Canvas, Customer Journey Map, User Story Map, Opportunity Solution Tree, Competitor Card, Market Note.
  - *Definition & planning:* PRD, Spec, ADR, Roadmap Item, OKR/Metric, Experiment.
  - *Evidence & learning:* Research Note, Customer Interview, Feedback, Insight, Assumption.
  - *Go-to-market:* Positioning/GTM Brief, Landing Page Draft.
  - Coverage target: a Product Lab or ChatPRD user finds every artifact they had — plus links and repo grounding they didn't.
- **R1.2 Native map/canvas views.** Board- and map-style native views over the same `.md` for VPC, BMC, Lean Canvas, Journey Map, Story Map, Opportunity Solution Tree, Roadmap. No web views.
- **R1.3 Typed links.** First-class edges (*implements, validates, contradicts, supersedes, derived-from*) between any nodes; backlinks everywhere; links survive renames/moves; broken links surfaced, never dropped.
- **R1.4 Graph navigation.** Visual product map; filter by kind/status; instant search and quick-open across the graph.
- **R1.5 AI Assist on every kind.** Draft (generate from linked nodes + prompt), Refine, and Cross-check (against linked evidence; against the repo once M2 lands). Goes through the thin `AIAssist` interface (ADR-0007), BYO-key capable — assistance, not orchestration. This is what makes Dynamite AI-ready to replace Product Lab outright.
- **R1.6 Standalone by construction.** Everything in M1 works with no repo connected and no editor pane open.
- **Acceptance:** a founder completes a discovery cycle (persona → VPC → assumptions → PRD, AI-drafted, fully linked) faster and more pleasantly than in Product Lab/Notion.

### M2 — Repo Awareness *(Phase 2 — the differentiator)*
- **R2.1 Repo connect.** Point at a local clone (read-only by default). Indexing never blocks the UI.
- **R2.2 Repo X-Ray.** Plain-language, auto-refreshed map of what the code actually does: features, flows, modules, status — linked to graph nodes. Built for non-coders; engineers get drill-down to files/symbols.
- **R2.3 Ask the Product.** Natural-language Q&A grounded in graph + code, answers with citations (nodes, files, symbols).
- **R2.4 Reality Diff.** Readable report of doc claims vs. code behavior; per-spec status (matches / diverged / not implemented).
- **R2.5 Doc↔code links.** Specs link to implementing files/symbols; opening either side shows the other.
- **Acceptance:** a non-coding PO answers "do we support refunds, and where?" with citations, without opening an editor or terminal.

### M3 — Context Engine *(Phase 2–3)*
- **R3.1 Context Compiler.** Selected graph slices → canonical `AGENTS.md` + thin `CLAUDE.md` shim + per-folder context; recompile on change; compiler-owned vs. user-owned regions (hand edits survive); regeneration shown as a reviewable diff.
- **R3.2 Context Lens.** Preview exactly what an agent will read for a given folder/task before it runs.
- **R3.3 Briefing Packs.** One click: spec/task → right-sized, self-contained context packet (file in repo and/or clipboard) for any external agent. Every line traceable to its source node. Small task → small pack.
- **R3.4 Drift Radar.** Stale context vs. sources flagged with one-click recompile; spec drift feeds Reality Diff (R2.4).
- **Acceptance:** editing a PRD updates compiled context with zero hand-editing; Claude Code run from a plain terminal visibly benefits; Context Lens shows why.

### M4 — Truth & Learning *(Phase 3)*
- **R4.1 Assumption Ledger.** BMC/VPC hypotheses tracked (untested/validating/validated/falsified) with linked evidence; falsification flags downstream specs.
- **R4.2 Interview Mode.** Paste/import a customer conversation → insights extracted (agent-assisted), linked to personas/assumptions; contradictions flagged.
- **R4.3 Loop Ledger.** Auto-trace: feedback → insight → decision → spec → shipped change (via repo history).
- **R4.4 Pulse.** Daily cockpit screen: assumption status, drift, loop velocity, repo changes narrated in product language.
- **R4.5 Decision Replay.** Any decision replayable with its full evidence chain.
- **R4.6 Stakeholder Digest.** Investor/team update drafted from Pulse + Loop Ledger.
- **Acceptance:** a product decision traces from customer quote to shipped code; the weekly update writes itself.

### M5 — IDE & extension surface *(supporting layer, inherited)*
- **R5.1 Editor excellence, maintained not expanded:** fast editor, file tree, search, git, terminal (CodeEdit inheritance).
- **R5.2 Doc review parity.** Diffing a PRD/spec revision as polished as a code diff.
- **R5.3 Agent extension surface (optional).** Claude/Codex usable inside Dynamite via an extension for nicer UI (chat panel, inline results). Strictly optional; no orchestration features (no parallel sessions, worktrees, fleet management).
- **Acceptance:** the IDE never blocks or slows the product layer; a user who never opens it loses nothing from M1–M4.

### M6 — Team & scale *(Phase 4 — monetization)*
- **R6.1 Shared product brain** (synced graph/context) — paid wedge.
- **R6.2 Roles:** product-only seats are first-class (no code access needed).
- **R6.3 Audit trail:** human and agent changes tied to specs and decisions.

## 7. Success metrics
- **Activation:** new user creates ≥3 linked artifacts in week 1; (repo users) runs first Ask-the-Product query.
- **Core habit:** weekly Pulse opens; briefing packs generated per active user per week.
- **Moat:** linked edges per active project (target: median >25 by week 4); % projects with compiler-maintained context.
- **Grounding:** % specs with live code links; Reality Diff resolution time.
- **North star:** weekly closed loops (evidence → decision → spec → shipped change) per active user.

## 8. Risks & mitigations
- **Two mediocre halves** → graph + repo awareness + compiler get excellence first; IDE stays inherited.
- **ChatPRD/Product Lab add MCP repo-reading** → our grounding is native, linked, drift-checked — not a fetch; ship X-Ray early.
- **Repo analysis quality for non-coders** (X-Ray wrong = trust gone) → citations everywhere, confidence labels, never assert without a source.
- **Scope gravity toward orchestration** ("just add agent panes") → non-goal is written in stone above; extension surface is the release valve.
- **Solo/small-team capacity** → strict phasing (`ROADMAP.md`), AI-routed build plan (`DEVPLAN.md`).

## 9. Open questions
1. Link/metadata storage: front-matter + rebuildable local index. → **Decided:** `decisions/ADR-0001-product-graph-data-model.md`.
2. Repo analysis engine: local static analysis vs. agent-assisted indexing (cost/privacy trade-off). → ADR-0002.
3. Compiler merge semantics (compiler-owned vs. user-owned regions). → ADR-0003.
4. Drift/Reality-Diff signal: heuristics first, semantic agent check later — cost controls. → ADR-0004.
5. Extension surface tech: MCP client? Claude Agent SDK? Keep thinnest viable. → ADR-0005.
6. App shell view-mode architecture details. → **Decided:** `decisions/ADR-0006-app-shell-one-app-two-views.md`.
7. AI Assist backend: BYO key vs. bundled; cost controls. → ADR-0007.
8. Free/Pro boundary within the product layer.

## 10. References
`CONCEPT.md` · `MARKET.md` · `ROADMAP.md` · `ARCHITECTURE.md` · `DEVPLAN.md` · root `CLAUDE.md` (agent working instructions)
