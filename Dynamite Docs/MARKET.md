# Dynamite — Market & Competitive Analysis

**Status:** v2 · **Owner:** Max · **Last updated:** 2026-06-10
**Feeds:** `CONCEPT.md`, `PRD.md`. Sources at the bottom; refresh quarterly — this space moves fast.

---

## 1. Market signals

- Global spend on AI coding tools: **~$15B/yr**. Lovable: $100M ARR in 8 months; Replit: $10M→$100M in 9 months. The growth segment is *product builders*, not traditional engineers.
- **AGENTS.md** is now a cross-vendor standard (Linux Foundation–stewarded, 30+ tools, 60k+ repos). Claude Code still reads `CLAUDE.md`, so the converged pattern is canonical `AGENTS.md` + thin `CLAUDE.md` shim. All of it is hand-maintained; the **stale-context problem is named and documented** — and unsolved.
- AI PM tooling validated willingness to pay: **ChatPRD 100k+ PMs at $10–25/mo**; Product Lab AI sells discovery artifacts (VPC, personas, journeys) at $5–89/mo.
- The telling signal: **PM guides in 2026 teach product managers to open Claude Code or Cursor just to understand their own product** ("ask 'where does pricing logic live?'"). The demand for repo-aware product work exists; the only supply is engineer tools.
- Spec-driven development went mainstream (GitHub Spec Kit 90k+ stars; Kiro, Tessl) — proving "docs drive agents" — but stayed dev-centric and task-scoped.

**Read:** demand is proven for product artifacts (ChatPRD), for repo understanding (PMs in Cursor), and for context files (AGENTS.md). Nobody sells all three as one product. That seat is empty.

## 2. Landscape

### A. AI product-management platforms — our primary competitive axis
| Tool | What it is | Strengths | The gap Dynamite exploits |
|---|---|---|---|
| **ChatPRD** | AI copilot for PMs: PRDs, stories, GTM briefs; 100k+ users | Market leader; even publishes "PRDs for AI codegen" guides — they see the convergence but stop at the doc | Output lands in a void: no repo grounding, no agent feed, no drift detection. A generator, not a system of record |
| **Product Lab AI** | Discovery copilot: VPC, personas, journey maps | Validates demand for typed discovery artifacts — our Phase-1 catalog | Artifacts are exports connected to nothing; shallow; web-based |
| **Productboard / Aha! AI** | Incumbent PM suites + AI | Enterprise distribution | Heavy, web, roadmap-centric; can't see code; agents are an afterthought |
| **Notion (+ MCP)** | Planning mindshare; agents can *read* it via MCP | Ubiquity | Reading a wiki ≠ typed, linked, drift-checked, compiled context; no repo grounding |

**Verdict:** this is the fight we pick, and we bring a weapon none of them has: the repo. "Product Lab, but it knows your actual product" is the positioning in one phrase.

### B. Spec-driven dev tools — philosophy validators, different buyer
Kiro (AWS), GitHub Spec Kit, Tessl, OpenSpec proved that structured docs make agents better — and field reviews (Thoughtworks/Fowler) documented their failure modes: one heavyweight workflow for all sizes, markdown review fatigue, agents ignoring verbose specs, unclear target user. They serve developers doing tasks; we serve product owners running a product. We inherit their lesson, not their market.

### C. Agent orchestrators — adjacent, complementary, explicitly not our fight
Conductor (free, native macOS), Intent ($20–200/mo), Nimbalyst run and manage coding agents. **Dynamite does not orchestrate agents and will not compete here.** These tools are downstream consumers of what we produce: a Conductor or Claude Code session works better when the repo carries Dynamite-compiled context. If anything, healthy orchestrators grow our value. The only overlap to monitor: Intent's "Context Engine" reads codebases for *task* context — if Intent ever climbs from tasks to product knowledge, it enters our space. Watch, don't chase.

### D. The giants — rails, not rivals
- **Anthropic / OpenAI / Google** ship the agents and the standards (MCP, AGENTS.md). We write to their standards; every agent improvement raises the value of compiled context. Watch for first-party "project memory" creeping up the stack.
- **Cursor / Copilot:** engineer IDEs. Their possible drift *away* from the IDE form factor toward cloud agents only strengthens the case for a product-layer home that isn't an IDE.

## 3. Positioning map

```
                 owns PRODUCT knowledge
                          ▲
        ChatPRD ·         │        ★ DYNAMITE
        Product Lab AI ·  │       (product platform,
        Productboard ·    │        repo-grounded,
        Notion ·          │        feeds any agent)
 ─────────────────────────┼────────────────────────────▶
  blind to the repo       │        grounded in the repo
                          │   · Kiro, Spec Kit, Tessl (task specs)
                          │   · Cursor, Claude Code (engineer tools)
                          │   · Conductor, Intent (run agents — adjacent)
                 owns CODE/agent surface
```

Top-right is empty: product knowledge, grounded in the repo, feeding any agent. PM tools climb from the left (no repo DNA); dev tools climb from the bottom (no product DNA, wrong buyer). We start in the quadrant.

## 4. Implications for Dynamite

1. **Compete with PM platforms, not orchestrators.** Feature-for-feature parity target is ChatPRD + Product Lab; the differentiator is repo grounding (X-Ray, Ask the Product, Reality Diff).
2. **Be agent-agnostic by design.** Output = files in the repo (`AGENTS.md`, briefing packs). Works with every agent, present and future; zero integration treadmill.
3. **Day-one value without a repo** (or the user's involvement in code at all) — match Product Lab's instant gratification, then reveal depth when a repo is connected.
4. **Adopt standards, never invent them:** AGENTS.md canonical + CLAUDE.md shim, MCP where useful.
5. **Fix SDD's UX failures** for our audience: right-sized briefing packs, doc review as pleasant as code review.
6. **Price the platform, not the editor.** Free IDE + basic docs; Pro = the product layer (ChatPRD/Product Lab price band, far more defensible).
7. **Speed on Repo X-Ray** — it's the feature PM tools can't follow quickly and the proof of the whole thesis.

## 5. Sources

- [ChatPRD](https://www.chatprd.ai/) · [ChatPRD — PRDs for AI codegen](https://www.chatprd.ai/learn/prd-for-ai-codegen) · [Product Lab AI](https://product-lab.ai/)
- [Claude Code for Product Managers (Builder.io)](https://www.builder.io/blog/claude-code-for-product-managers) · [How PMs use Claude Code](https://www.prodmgmt.world/blog/how-to-use-claude-code) · [AI tools for PMs working with coding agents](https://nimbalyst.com/blog/best-ai-tools-for-product-managers/)
- [Thoughtworks/Fowler — Understanding Spec-Driven Development](https://martinfowler.com/articles/exploring-gen-ai/sdd-3-tools.html) · [GitHub Spec Kit](https://github.com/github/spec-kit) · [InfoWorld — SDD tools](https://www.infoworld.com/article/4171332/four-cutting-edge-tools-for-spec-driven-development.html)
- [bestagent.dev — CLAUDE.md vs AGENTS.md 2026](https://bestagent.dev/claude-md-vs-agents-md-2026/) · [Atlan — AGENTS.md guide](https://atlan.com/know/how-to-write-agents-md/)
- Adjacent (monitor only): [Conductor](https://www.conductor.build/) · [Intent vs Conductor](https://www.augmentcode.com/tools/intent-vs-conductor-macos-agent-orchestrators)
- Market figures: [the-ai-corner — AI coding tools guide](https://www.the-ai-corner.com/p/ai-coding-tools-complete-guide-2026) · [justinmckelvey — best AI coding agents 2026](https://justinmckelvey.com/blog/best-ai-coding-agents-2026)
