# Dynamite — Concept Paper

**Status:** v3 · **Owner:** Max · **Last updated:** 2026-06-14

> **Doc map** (read in this order): `CONCEPT.md` — why Dynamite exists and what it is · `MARKET.md` — evidence & landscape · `PRD.md` — what we build · `ROADMAP.md` — in what order · `ARCHITECTURE.md` — how it maps to the codebase · `DEVPLAN.md` — how we build it, including which AI model gets which task.

---

## One line

Dynamite is the native macOS **Product Studio**: the place where a product builder runs discovery, strategy, planning, and customer development — grounded in the product's actual repo — and where that living product knowledge compiles into the context that external AI agents (Claude, Codex, Cursor) read. Agents work *beside* Dynamite, never inside a cage; Ground Control provides a fast, native code/agent-review environment when needed, but the product studio is the point.

## North star

A founder or product owner should be able to think, decide, plan, and learn about their product in one fast native app — and have every AI agent they use, anywhere, automatically understand the product because Dynamite keeps the context true.

## What Dynamite is — and pointedly is not

**Is:** a product platform (think Product Lab, but repo-aware and 10× deeper) + a context engine for agents + Ground Control as a useful native support environment.

**Is not:** an agent orchestrator. We do not nest, run, or manage coding agents, and we do not compete with Conductor or Intent. The industry may even be moving *away* from the IDE as the agent's home — fine by us; our center of gravity is the product layer, not the editor. At most, agents like Claude or Codex can appear inside Dynamite as **extensions** when that gives a nicer UI — optional, never required, never the product.

This cuts both ways and is the moat-defining choice: **every agent improvement helps us** (better agents make compiled context more valuable), and we never burn capacity racing orchestration features that Conductor gives away free.

## The thesis (evidence in MARKET.md)

1. **Agents now write most code** (~$15B/yr market; Lovable 0→$100M ARR in 8 months). The scarce skill moved to *product judgment*: knowing what to build, for whom, and whether it worked.
2. **Agent context became a standard but stayed hand-maintained.** AGENTS.md: Linux Foundation–stewarded, 30+ tools, 60k+ repos — all written by hand, all stale within a week. Stale context is the documented #1 cause of bad agent output.
3. **The fastest-growing builder is a product person.** Their planning tools (Notion, ChatPRD, Product Lab AI) can't see the code; the only way a PM can ask "where does pricing logic live?" today is to open Cursor or a terminal — engineer tools for a non-engineer job.

**The insight:** the artifacts a product owner already creates — value proposition, personas, PRDs, interview notes, decisions — are exactly the context agents need, and the repo is exactly the ground truth product tools lack. Connect the two and both sides get better: the product work gets grounded in reality, the agents get context that's always current. Nobody owns that connection. That's Dynamite.

## The concept: five layers

### 1. Product Studio — the core product (Phase 1)
A native, fast, opinionated workspace of **typed product artifacts**, stored as plain `.md` on disk (git-friendly, portable, zero lock-in) — the complete product-ownership catalog: discovery & strategy (Problem, Persona, VPC, BMC, Lean Canvas, Customer Journey Map, User Story Map, Opportunity Solution Tree, Competitor Card, Market Note), definition & planning (PRD, Spec, ADR, Roadmap Item, OKR/Metric, Experiment), evidence & learning (Research Note, Interview, Feedback, Insight, Assumption), and GTM (Positioning Brief, Landing Page Draft). Canvas/map kinds get native board views over the same `.md`. Every kind has **AI Assist** — draft from linked nodes, refine, cross-check against evidence (and against the repo once connected). Templates over blank canvas; typed links between everything (*implements, validates, contradicts, supersedes, derived-from*). This is the **Product Graph**.

Fully usable by someone who never opens an editor pane and never writes code. Day-one value with no repo at all — strictly a superset of Product Lab/ChatPRD — and it becomes far more powerful when pointed at a repo.

### 2. Repo Awareness — the differentiator no PM tool has (Phase 2)
Point Dynamite at a repo and the product layer becomes grounded in reality:

- **Repo X-Ray** — a plain-language, continuously updated map of what the product *actually does according to the code*: features, flows, modules, status. The PM's answer to "what is my product, really?" without reading Swift.
- **Ask the Product** — natural-language questions answered from graph + code, with citations: "Do we handle refunds?" "What happens after signup?" "Which features touch billing?"
- **Reality Diff** — what the docs/specs claim vs. what the code does, as a readable report. Drift made visible to non-coders.

### 3. Context Engine — the moat (Phase 2–3, the "later installation")
The Product Graph compiles into what agents actually read:

- **Context Compiler** — selected graph slices → canonical `AGENTS.md` + thin `CLAUDE.md` shim + per-folder context, recompiled on change; compiler-owned vs. user-owned regions so hand edits survive.
- **Context Lens** — preview *exactly* what any agent will see before it starts. Answers "why did the agent do that?" before it happens.
- **Briefing Packs** — one click turns a spec/task into a right-sized, self-contained context packet written into the repo (or copied), which the user hands to *any* agent, *anywhere* — Claude Code in a terminal, Codex in the cloud, Cursor. A bug fix gets a paragraph; a new module gets the full slice. Dynamite feeds agents; it doesn't drive them.

### 4. Truth & Learning layer — the trust builder (Phase 3)
- **Assumption Ledger** — every BMC/VPC hypothesis becomes a tracked assumption (untested / validating / validated / falsified) linked to evidence. Strategy stops being a poster.
- **Interview Mode** — paste or import a customer conversation → insights extracted, linked to assumptions and personas, contradictions flagged.
- **Loop Ledger** — the product's institutional memory: feedback → insight → decision → spec → shipped change, auto-traced and queryable.
- **Pulse** — the CEO's morning screen: assumption status, drift, open questions, loop velocity, what changed in the repo in product terms ("agents shipped the new onboarding flow yesterday").
- **Decision Replay** — pick any decision and replay its evidence chain: which interviews, which data, which alternatives. Onboarding a cofounder or investor becomes a 10-minute tour.
- **Stakeholder Digest** — investor/team updates auto-drafted from the Loop Ledger and Pulse.

### 5. Ground Control — the supporting operational environment
A fast native CodeEdit-powered environment for when you *want* to review or touch the code: doc and code diffs that are a pleasure to read, quick open, search, git, terminal, build/test state, and optional Claude/Codex extension surfaces for nicer supervision. It is deliberately separate from Product Studio so product work and code/agent review do not overload each other, and nothing in layers 1–4 depends on it being open.

**The shell — one app, two environments:** every window toggles between **Product Studio** (default: Home, docs, tasks, maps, Pulse, Ask the Product — with read-only code peeks, so non-coders never leave it) and **Ground Control** (classic CodeEdit layout plus product-context toggles in the inspector). Like VS Code activity-level separation, but product-first. One shared workspace and link index underneath; that's why it's one app, not two.

## A day in Dynamite

> Morning: Pulse shows an assumption at risk — three interviews this week contradict the "teams will self-serve" hypothesis. Open Decision Replay, see what the pricing decision rested on. Edit the PRD; the Context Compiler quietly updates `AGENTS.md`. Turn the revised spec into a Briefing Pack; hand it to Claude Code in a terminal (or tap the in-app extension). Afternoon: Reality Diff confirms the shipped change matches the spec; Loop Ledger records the loop; the Stakeholder Digest drafts itself for Friday.

Plan → ground in reality → brief any agent → verify → learn → plan. No retyping, no stale context, no lost "why."

## Lessons absorbed from SDD's first wave (Kiro / Spec Kit / Tessl field reviews)
1. *One heavyweight workflow for all sizes* → Briefing Packs right-size context per task; a bug fix never triggers PRD ceremony.
2. *Markdown review overload* → doc diffs as polished as code review; artifacts stay few and typed.
3. *False sense of control* → compiled, scoped, inspectable context (Context Lens) beats giant hand-written files.
4. *Unclear target user* → ours is explicit: product builders and product owners — people doing product-oriented work, not just development.

## Business model (sketch)
- **Free:** Ground Control + basic typed docs. The Product Studio door is open.
- **Pro (~$15–25/mo):** full Product Studio, Repo Awareness, Context Engine, Truth & Learning layer. Priced against ChatPRD ($10–25) and Product Lab — but defensible because none of them can read a repo.
- **Team (per-seat):** shared product brain, audit trail, digests. Switching cost compounds with every link in the graph.

## The moat, stated plainly
Every edge a user creates (spec↔code, feedback↔assumption, decision↔commit) makes their agents smarter and Dynamite harder to leave. Agent vendors won't build this (they sell the agent, not the product brain); PM tools can't (no repo access, web DNA); orchestrators chase a different buyer. Depth of graph per project is the metric that matters.

## Top risks
1. **Two mediocre halves** → the glue (graph + repo awareness + compiler) gets excellence first; both halves stay minimal until the glue sings.
2. **ChatPRD/Product Lab add repo reading via MCP** → our depth is native, linked, and drift-checked, not a fetch; speed matters — ship Repo X-Ray early.
3. **Agent-surface churn (MCP/standards)** → we write files and standards (AGENTS.md), not integrations; the file system is the most stable API in computing.
4. **macOS-only TAM** → accepted; the discerning-builder niche skews Mac; depth before breadth; revisit post-PMF.
