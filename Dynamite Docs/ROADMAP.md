# Dynamite — Roadmap

Sequencing logic: **Phase 1 delivers a product platform people use day one (no repo needed). Phase 2 adds the differentiator nobody can follow (repo grounding + context engine). Phase 3 builds the trust/learning layer. Phase 4 monetizes teams.** The IDE is inherited — kept excellent, never expanded ahead of the product layer. Aligned with `PRD.md` v3 modules (M0–M6) and executed task-by-task via `DEVPLAN.md`.

Status legend: ☐ planned · ◐ in progress · ☑ done

---

## Phase 0 — Foundation *(inherited — keep excellent, keep out of the way)*
- ☑ Fast native editor, file tree, syntax, git, terminal (CodeEdit fork)
- ☐ Strip/park IDE surfaces that don't serve the product layer; performance baseline
- ☐ Doc review parity: `.md` diffs as polished as code diffs (M5/R5.2 — needed early, docs are our core data)

## Phase 1 — App shell + Product Studio (M0, M1) *(ship first — value with zero repo, zero code)*
- ☐ **Shell:** one app, two views — Cockpit (default) ↔ IDE, per-window switcher, cross-deep-links (ADR-0006)
- ☐ Typed documents, full catalog (22 kinds): discovery & strategy (Problem, Persona, VPC, BMC, Lean Canvas, Journey Map, Story Map, Opportunity Solution Tree, Competitor Card, Market Note) · definition & planning (PRD, Spec, ADR, Roadmap Item, OKR/Metric, Experiment) · evidence (Research Note, Interview, Feedback, Insight, Assumption) · GTM (Positioning Brief, Landing Page Draft)
- ☐ Native board/map views: VPC, BMC, Lean Canvas, Journey, Story Map, OST, Roadmap
- ☐ **AI Assist on every kind:** draft / refine / cross-check via thin `AIAssist` interface (ADR-0007) — Product Lab replacement complete
- ☐ Typed links + backlinks everywhere; links survive renames; broken links surfaced
- ☐ Product map (visual graph), search, quick-open across the graph
- ☐ Standalone mode guarantee: no editor pane, no repo required
- **Exit:** a founder runs a full discovery cycle here, AI-drafted and fully linked, and prefers it to Product Lab/ChatPRD/Notion.

## Phase 2 — Repo Awareness + Context Engine core (M2, M3) *(the bet)*
- ☐ Repo connect (read-only default; non-blocking indexing)
- ☐ **Repo X-Ray**: plain-language living map of what the code does, linked to graph nodes
- ☐ **Ask the Product**: grounded Q&A with citations
- ☐ Doc↔code links (spec ↔ files/symbols)
- ☐ **Context Compiler**: graph → canonical `AGENTS.md` + `CLAUDE.md` shim + per-folder context; compiler-owned vs user-owned regions; reviewable regen diffs
- ☐ **Context Lens**: preview what any agent will read
- ☐ **Briefing Packs**: one-click right-sized context packets for any external agent
- **Exit:** a non-coder answers product questions from the repo; an agent run from a plain terminal visibly improves on Dynamite-compiled context.

## Phase 3 — Truth & Learning (M4 + Drift)
- ☐ **Reality Diff** + **Drift Radar**: doc claims vs code behavior; stale context flagged, one-click recompile
- ☐ **Assumption Ledger** (hypothesis status + evidence links; falsification flags downstream specs)
- ☐ **Interview Mode** (conversation → linked insights, contradictions flagged)
- ☐ **Loop Ledger** (feedback → insight → decision → spec → shipped change, auto-traced)
- ☐ **Pulse** (daily cockpit: assumptions, drift, loop velocity, repo changes in product language)
- ☐ **Decision Replay** · ☐ **Stakeholder Digest**
- **Exit:** a product decision traces from customer quote to shipped code; the weekly update writes itself.

## Phase 4 — Team & scale (M6) *(monetization)*
- ☐ Shared product brain (synced graph/context) — paid tier
- ☐ Product-only seats (no code access needed)
- ☐ Audit trail (human + agent changes tied to specs/decisions)

## Continuous — IDE & extension surface (M5) *(bonus track, strictly behind the product layer)*
- ☐ Agent extension surface: optional Claude/Codex UI inside Dynamite (no orchestration features, ever)
- ☐ Editor maintenance: speed, stability, upstream CodeEdit merges

---

## Guardrails
- **No agent orchestration. Ever.** No nesting, panes, worktree fleets — Conductor/Intent's fight, not ours.
- Don't build our own agent/model. Don't go cross-platform before PMF.
- Don't replicate generic Notion/Linear/Productboard features — only what ties to the repo and agents.
- Repo answers always cite sources; never assert without one.
- A small task gets a small briefing — no ceremony.
- If a feature makes the app feel slow, redesign it.
