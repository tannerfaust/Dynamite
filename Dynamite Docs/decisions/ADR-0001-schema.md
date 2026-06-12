# ADR-0001 Appendix — Product Graph schema

Normative catalog and reference files for [ADR-0001](ADR-0001-product-graph-data-model.md). When this appendix and prose elsewhere disagree, this appendix wins.

## Kind catalog (normative — 23 kinds)

Core fields (`id`, `kind`, `status`, `created`, `updated`, `v`, plus optional `title`, `tags`, `links`, `code`) apply to every kind and are not repeated below. *Body structure* notes which canonical H2 sections the native views parse; kinds marked "free" have no required body structure.

### Discovery & strategy → `product/discovery/`

| Kind slug | ID prefix | Per-kind front-matter | Body structure |
|---|---|---|---|
| `problem` | `prb` | — | free |
| `persona` | `per` | — | free (suggested: Goals / Frustrations / Context) |
| `vpc` | `vpc` | — | canvas: `Customer Jobs`, `Pains`, `Gains`, `Products & Services`, `Pain Relievers`, `Gain Creators` |
| `bmc` | `bmc` | — | canvas: the 9 BMC blocks as H2s |
| `lean-canvas` | `lean` | — | canvas: the 9 Lean Canvas blocks as H2s |
| `journey` | `jny` | — | canvas: one H2 per stage, in order |
| `story-map` | `smap` | — | canvas: H2 = activity, H3 = step, list items = stories |
| `ost` | `ost` | — | canvas: nested list (outcome → opportunity → solution → experiment) |
| `competitor` | `cmp` | `website` (url, optional) | free (suggested: Positioning / Strengths / Weaknesses) |
| `market-note` | `mkt` | — | free |

### Definition & planning → `product/planning/`

| Kind slug | ID prefix | Per-kind front-matter | Body structure |
|---|---|---|---|
| `prd` | `prd` | — | free (template ships with standard PRD sections) |
| `spec` | `spec` | — | free |
| `adr` | `adr` | `deciders` (list, optional) · status override: `proposed/accepted/superseded` | template: Context / Decision / Alternatives / Consequences |
| `roadmap-item` | `rmi` | `horizon`: `now/next/later` | free |
| `okr` | `okr` | `target` (string, optional) · `current` (string, optional) | free |
| `experiment` | `exp` | status override: `planned/running/concluded` | free (suggested: Hypothesis / Method / Result) |

### Evidence & learning → `product/evidence/`

| Kind slug | ID prefix | Per-kind front-matter | Body structure |
|---|---|---|---|
| `research-note` | `rsn` | `source` (url, optional) | free |
| `interview` | `int` | `subject` (string) · `date` (ISO date) | free (suggested: Context / Notes / Quotes) |
| `feedback` | `fbk` | `source` (string: channel) | free |
| `insight` | `ins` | `confidence`: `low/medium/high` | free |
| `assumption` | `asm` | `impact`: `low/medium/high` (optional) · status override: `untested/validating/validated/falsified` | free |

### Go-to-market → `product/gtm/`

| Kind slug | ID prefix | Per-kind front-matter | Body structure |
|---|---|---|---|
| `gtm-brief` | `gtm` | — | free |
| `landing-page` | `lpd` | `url` (optional) | free |

## Edge semantics

| `rel` | Reading (source → target) | Computed inverse |
|---|---|---|
| `implements` | source realizes target | implemented-by |
| `validates` | source (evidence) supports target | validated-by |
| `contradicts` | source (evidence) undermines target | contradicted-by |
| `supersedes` | source replaces target | superseded-by |
| `derived-from` | source was distilled out of target | source-of |
| `relates-to` | untyped association | relates-to |

---

## Example 1 — canvas kind: `product/discovery/vpc-indie-founder.md`

```markdown
---
id: vpc-h3m9w
kind: vpc
status: active
created: 2026-06-02
updated: 2026-06-10
v: 1
title: VPC — Indie founder shipping via agents
tags: [wedge, phase-1]
links:
  - { rel: derived-from, to: per-q2c8d, label: "Persona: indie product founder" }
  - { rel: derived-from, to: int-f7r2p, label: "Interview: Sam K., 2026-05-28" }
  - { rel: relates-to, to: asm-x7k4q, label: "Founders pay for repo grounding" }
---

# VPC — Indie founder shipping via agents

## Customer Jobs
- Decide what to build next with confidence
- Brief coding agents well enough that output lands close to intent
- Know what the product *actually* does after weeks of agent-driven changes

## Pains
- Product knowledge scattered across Notion, chats, and stale READMEs
- Hand-maintains AGENTS.md / CLAUDE.md; always out of date
- Can't verify agent claims without reading code

## Gains
- One place where strategy, evidence, and the repo agree
- Agent briefings generated from living docs, not memory
- Plain-language answers about own codebase, with citations

## Products & Services
- Product Studio (typed artifacts + links)
- Repo X-Ray / Ask the Product / Reality Diff
- Context Compiler + Briefing Packs

## Pain Relievers
- Graph compiles into agent context automatically — no hand-editing
- Reality Diff flags where docs and code diverge

## Gain Creators
- Every decision traceable to evidence
- Non-coder-readable map of the codebase
```

## Example 2 — doc kind: `product/planning/spec-markdown-diff.md`

```markdown
---
id: spec-9k3fa
kind: spec
status: active
created: 2026-06-09
updated: 2026-06-10
v: 1
title: Markdown diff rendering (doc review parity)
tags: [m5, diff]
links:
  - { rel: implements, to: prd-2qj8x, label: "PRD v3 — R5.2 doc review parity" }
  - { rel: derived-from, to: ins-w4n8t, label: "Insight: PRD reviews happen in git" }
code:
  - { path: CodeEdit/Features/SourceControl/Diff/GitClient+Diff.swift, symbol: "parseDiff", anchor: 3f9c2a1d }
  - { path: CodeEdit/Features/SourceControl/Diff/Views/MarkdownDiffView.swift, symbol: "MarkdownDiffView", anchor: a81d40c7 }
---

# Markdown diff rendering (doc review parity)

Diffing a 200-line PRD revision must be as readable as a code diff.

## Requirements
1. Word-level inline highlighting for prose (LCS over word tokens).
2. Inline and side-by-side display modes.
3. Front-matter hunks render as a key/value before/after table, not raw text.

## Acceptance
A PRD revision reviewed in the diff pane reads as prose with changed words
highlighted — no `+`/`-` archaeology required.
```

## Example 3 — evidence kind: `product/evidence/interview-sam-k.md`

```markdown
---
id: int-f7r2p
kind: interview
status: active
created: 2026-05-28
updated: 2026-06-01
v: 1
title: Interview — Sam K. (solo founder, agent-heavy workflow)
subject: Sam K.
date: 2026-05-28
tags: [discovery]
links:
  - { rel: validates, to: asm-x7k4q, label: "Founders pay for repo grounding" }
  - { rel: contradicts, to: asm-p9d3m, label: "Founders want agents managed in-app" }
---

# Interview — Sam K.

## Context
Solo founder, B2B SaaS, ~14 months in. Ships almost exclusively through
Claude Code; opens an editor "maybe twice a week".

## Notes
- Keeps PRDs in Notion; admits they drift from reality within weeks.
- Maintains CLAUDE.md by hand; calls it "a chore I do badly".
- Asked what the product does in an area he hadn't touched in months,
  he opened Cursor just to ask the agent — and didn't fully trust the answer.

## Quotes
> "I don't want something running my agents. I want to stop being
> the human clipboard between my docs and my agents."

> "If it could tell me what my own app does — with receipts — I'd pay today."
```
