# ADR-0007: AIAssist interface — artifact-level AI calls

- Status: proposed
- Date: 2026-06-10
- Deciders: Max (CPO), Fable 5 (architect)
- Depends on: ADR-0001 (Product Graph data model — assumed: `.md` + front-matter nodes, typed links, LinkIndex query API). Revisit §ContextBundle if ADR-0001 diverges.

## Context

The product layer needs AI assistance everywhere (artifact Draft/Refine/Cross-check now; X-Ray summarization, interview extraction, Pulse narration later) — but Dynamite's hard invariant is **no agent runtime**: no sessions, no tool-use loops, no orchestration (CLAUDE.md, PRD §3 non-goals). We need one thin, model-agnostic seam so every feature calls AI the same way, costs stay visible, and the no-agent rule is enforced structurally rather than by discipline.

## Decision

Add `Features/AIAssist`, the **only** path to AI providers in the codebase. Single request → streamed response. Stateless by construction: the API takes a fully assembled context and returns text; there is no conversation object, no tool schema, no callback into the app.

### 1. Core API (conceptual)

```swift
protocol AIAssistService {
    func run(_ request: AssistRequest) -> AsyncThrowingStream<AssistEvent, Error>
    func estimate(_ request: AssistRequest) -> CostEstimate   // pre-flight, no network
}

struct AssistRequest {
    let operation: AssistOperation     // .draft, .refine, .crossCheck, .summarize, .extract, .narrate
    let prompt: String                 // user instruction (may be empty for .draft from template)
    let bundle: ContextBundle          // grounding (see §3)
    let budget: TokenBudget            // per-call caps (see §4)
}

enum AssistEvent { case delta(String), usage(TokenUsage), done(AssistResult) }

struct AssistResult {
    let text: String
    let groundingRefs: [NodeRef]       // which bundle items informed the output (for the sources UI)
    let discrepancies: [Discrepancy]?  // crossCheck only: claim, evidenceRef, kind(contradicts|unsupported|stale)
}
```

`AssistOperation` is a closed enum — adding a new AI behavior means adding a case + prompt template here, reviewed against the no-agent rule. Features never build raw provider calls.

### 2. Provider abstraction

`AIProvider` protocol with three implementations: Anthropic, OpenAI, Google. Chosen + configured in Settings (`Features/Settings`):

- **BYO API key** at v1 (stored in macOS Keychain, never on disk/in repo). Bundled/managed keys are a later commercial decision; the protocol doesn't care.
- Per-operation default model tiers: cheap tier for `.refine`/`.narrate`, capable tier for `.draft`/`.crossCheck`/`.extract`; user-overridable per provider.
- Streaming mandatory; one retry on transient failure; no background/queued calls — every call is user-initiated and visible.
- Offline / no-key state: AIAssist surfaces degrade to hidden or disabled-with-hint; nothing in the product layer hard-depends on AI (standalone invariant).

### 3. ContextBundle — grounding

Built by a `ContextBundleBuilder` that walks the LinkIndex from a focus node:

- **Contents:** the focus artifact (full text), linked nodes one hop out filtered by relevance to the operation (e.g. `.crossCheck` pulls only *evidence-kind* nodes via `validates`/`contradicts` edges; `.draft` pulls personas/problems/assumptions via any edge), each as `(NodeRef, kind, excerptOrFull)`.
- **Deterministic assembly order** (focus → edges by type → recency) so identical graphs produce identical prompts — testable, cacheable.
- **Size policy:** bundle trimmed to budget by dropping lowest-priority items whole (never mid-document truncation silently); the UI shows what was included/dropped. This is the same right-sizing philosophy as Briefing Packs (PRD R3.3); ContextBundle is its in-app sibling and they may share trimming code in Phase 2.
- Repo-derived context (X-Ray excerpts) joins the bundle in Phase 2 through the same item type — no API change.

### 4. Cost guardrails

- `TokenBudget` per call: hard input cap + output cap, defaults per operation (e.g. refine 4k/1k; draft 16k/4k; crossCheck 24k/2k), user-adjustable in Settings within sane bounds.
- **Pre-flight estimate** shown in the UI before send (tokens ≈ chars/4 per provider tab, priced from a bundled, updatable price table): "≈ $0.03". No call without a rendered estimate.
- Running per-project spend meter (local log of `TokenUsage` events) visible in Settings; soft monthly cap with warn-then-block.

### 5. The no-agent rule (enforced, not promised)

- AIAssist exposes **no** tool/function-call schema to providers, **no** multi-turn state, **no** filesystem or network capabilities to the model. One request, one response.
- Responses are **proposals**: rendered in review UI (draft preview, refine diff, discrepancy list); nothing writes into an artifact or the graph without explicit user acceptance (same rule as Interview Mode, T3.4).
- Lint/CI guard: provider SDK imports allowed only inside `Features/AIAssist` (SwiftLint custom rule), making bypass visible in review.

### 6. The three v1 operations (wired into the artifact editor)

- **Draft:** empty/partial artifact + template sections + bundle → full draft, sectioned per the kind's template; preview → accept/replace per section.
- **Refine:** selection + instruction → replacement shown as inline diff; accept/reject.
- **Cross-check:** artifact claims vs evidence-kind bundle items → `Discrepancy` list rendered with citation chips (click → source node); each row dismissible or convertible into a flagged link.
- All three display **grounding sources** (the `groundingRefs`) as chips under the result — "grounded or silent" applies in-app too: an output with an empty bundle is labeled *ungrounded* visually.

## Alternatives considered

- **Per-feature direct SDK calls** — fastest to start; rejected: cost/no-agent rules become unenforceable, N prompt styles, N billing surprises.
- **Embed an agent SDK (sessions + tools)** — more capable; rejected: violates the companion-not-cage invariant and PRD non-goals; capability creep is the main risk to position.
- **Local models only** — private and free; rejected for v1: quality insufficient for draft/cross-check on product artifacts; protocol leaves room for a local `AIProvider` later.
- **Route everything through the MCP extension surface (ADR-0005)** — rejected: extension is optional by definition; core product features can't depend on an optional component.

## Consequences

- Easier: consistent cost control and UX for every AI touchpoint; Phase 2/3 features (X-Ray, extraction, narration) reuse the seam by adding enum cases; provider swaps are config, not refactors; the no-agent invariant is testable.
- Harder: every new AI behavior must fit request/response (deliberate friction); we maintain a price table and three provider adapters; bundle relevance heuristics need tuning per operation.
- Must maintain: Keychain handling, the SwiftLint import rule, deterministic-bundle tests, per-operation prompt templates under `Features/AIAssist/Prompts/`.
