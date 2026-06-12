# ADR-0001: Product Graph data model
- Status: accepted
- Date: 2026-06-10
- Deciders: Max (owner); drafted by Claude (chief-architect pass)
- Resolves: PRD §9 open question 1; ARCHITECTURE.md key decision 1
- Appendix: [ADR-0001-schema.md](ADR-0001-schema.md) — full kind catalog + example files

## Context

The Product Graph (PRD M1) is typed product artifacts plus typed links between them and into code. PRD R1.1 enumerates the catalog (23 kinds — the "22" previously quoted in `CLAUDE.md` was a stale count; the catalog in the appendix is normative). Hard constraints, from PRD principles and the architecture invariant:

1. **Plain `.md` is always authoritative.** Everything Dynamite knows must be derivable from the files; zero lock-in (PRD principle 7).
2. **The index is always disposable.** Delete it, rebuild it, lose nothing.
3. **External edits never corrupt the graph.** A user (or an agent) editing these files in vim, Obsidian, or GitHub's web editor is a *normal* workflow, not an error path. Renames, moves, malformed YAML, partial edits — all must degrade gracefully, never destroy links (R1.3: broken links are surfaced, never dropped).
4. Links must survive file renames/moves (R1.3) and, for code targets, survive code refactors as well as possible.
5. Git-merge-friendly: two branches adding artifacts or links concurrently should merge without conflict in the common case.
6. The graph must work with **no repo connected** (R1.6) — code links degrade, doc links don't care.

## Decision

### 1. Front-matter schema

Every artifact is one `.md` file: YAML front-matter for **metadata only**, markdown body for **all content**.

**Shared core fields** (all 23 kinds):

```yaml
---
id: spec-9k3fa        # required, immutable — identity (see below)
kind: spec            # required, immutable — one of the 23 catalog slugs
status: active        # required — lifecycle (see vocabulary below)
created: 2026-06-10   # required — ISO date, set once
updated: 2026-06-10   # required — ISO date, advisory (see invalidation: never trusted for cache logic)
v: 1                  # required — schema version of this file format
title: …              # optional — defaults to first H1, else filename
tags: [a, b]          # optional — free-form
links: […]            # optional — typed edges, §2
code: […]             # optional — code targets, §2
---
```

**Identity = `id`, not path.** `id` is `<kind-prefix>-<5-char Crockford base32 random suffix>` (e.g. `asm-x7k4q`, `prd-2qj8x`). Generated from a CSPRNG at creation, collision-checked against the index, then immutable. This is the linchpin of constraints 3–5:

- Renaming or moving a file changes nothing — links reference `id`, the index re-binds id→path on the next scan.
- Random suffixes never collide across branches (unlike sequential numbering), so concurrent artifact creation merges cleanly.
- The kind prefix makes raw links self-describing: a human reading `to: asm-x7k4q` in another editor knows it points at an assumption.
- A node's `kind` never changes; "convert" = create new node + `supersedes` edge.

**Status vocabulary.** Shared baseline: `draft | active | superseded | archived`. Three kinds override with richer lifecycles (documented in the catalog): `assumption` (`untested | validating | validated | falsified`, per R4.1), `experiment` (`planned | running | concluded`), `adr` (`proposed | accepted | superseded`). The index stores status as an opaque string; views interpret per kind.

**Per-kind fields are minimal** — most kinds add zero or one field (full table in the appendix). Structured *content* never goes in front-matter: canvas kinds (VPC, BMC, Lean Canvas, Journey, Story Map, OST) store their content as **canonical H2 sections in the body** (e.g. `## Pains`, `## Gain Creators`), which the native canvas views parse and render. This keeps every artifact fully readable and editable as ordinary markdown in any tool; unknown headings are preserved untouched.

**Round-trip rule:** Dynamite's front-matter serializer preserves unknown fields verbatim and writes atomically (temp file + rename). Malformed YAML is *flagged in the UI, never auto-fixed* — the file is the user's.

### 2. Typed links

Edges live in the **source** file's front-matter, one YAML flow mapping per line:

```yaml
links:
  - { rel: validates, to: asm-x7k4q, label: "Indie founders pay for repo grounding" }
  - { rel: implements, to: prd-2qj8x, label: "PRD v3 §M5 R5.2" }
```

- One line per link → concurrent additions on different branches merge cleanly; one link per line diffs readably.
- `rel` ∈ `implements | validates | contradicts | supersedes | derived-from | relates-to`. The five typed edges are the PRD set; `relates-to` is the untyped escape hatch so users aren't forced to mistype a relationship just to record one.
- `label` is an optional human-readable hint (the target's title at link time) so the raw file is legible without resolving ids. It's display sugar — the index refreshes it; staleness is harmless.
- **Backlinks are computed, never written.** Inverses (`implemented-by`, `validated-by`, `superseded-by`, …) are index-derived views. Writing them into target files would double merge surface and write-amplify every link edit.
- A link whose `to:` id doesn't resolve stays in the file and appears in the UI as **broken** — surfaced, never dropped (R1.3).

**Code targets** get their own list (they are implicitly `implements`-flavored and need different resolution machinery):

```yaml
code:
  - { path: CodeEdit/Features/SourceControl/Diff/GitClient+Diff.swift, symbol: "parseDiff", anchor: 3f9c2a1d }
```

- `path` — repo-relative file path. A *hint*, not the identity.
- `symbol` — optional declaration name (function, type, …).
- `anchor` — first 8 hex chars of SHA-256 over the symbol's declaration line, whitespace-normalized. This is the durable identity: when `path` goes stale (file renamed/moved), the resolver searches the repo index for a declaration hashing to `anchor` and re-binds automatically. Resolution order: exact path+symbol → anchor scan → `broken` (surfaced).
- Line numbers are deliberately **not** stored — too volatile to survive any edit.
- Re-binding updates the **index** immediately (links keep working); the *file's* `path` hint is rewritten only on user action ("Repair links") or the next time the user saves that document in Dynamite — Dynamite never rewrites files behind the user's back.
- With no repo connected, code links resolve to `no-repo` state and render as inert chips. Nothing else degrades (R1.6).

### 3. Rebuildable local index

**Store: SQLite via GRDB** — already a dependency (used by `ExtensionDiscovery`, `EditorStateRestoration`), so zero new packages. Lives at `<workspace>/.dynamite/index.db` (WAL mode); Dynamite ensures `.dynamite/` is in `.gitignore`.

Why not a flat JSON cache: backlinks, kind/status filters, graph traversal, and instant search (R1.4 — FTS5 full-text) are queries; a flat cache makes each one a full scan + hand-rolled in-memory structures, and rewrites the world on every edit. SQLite gives incremental updates and indexed queries for free at any graph size.

**Schema (all derived, nothing authoritative):**

| Table | Contents |
|---|---|
| `nodes` | id, kind, status, title, path, mtime, size, content_sha, parse_state, created, updated, extra_json |
| `edges` | src_id, rel, dst_id, label, file_order, resolved (bool) |
| `code_links` | src_id, path_hint, symbol, anchor, resolved_path, resolve_state, file_order |
| `fts` | FTS5 over title + body + tags |
| `meta` | index_schema_version, app_version, built_at |

**Invalidation.** FSEvents on `product/` (reusing the existing `DirectoryEventStream` / `CEWorkspaceFileManager` machinery), debounced. Per-file freshness stamp = (size, mtime, content SHA-256); mismatch → reparse that file only. The front-matter `updated` field is **never** used for cache decisions — external editors don't maintain it.

**Rebuild-from-files guarantee.** Enforced by three rules:
1. *No authoritative data in the index, ever.* Any feature needing persistent state writes it to front-matter or body. Backlinks, resolved anchors, FTS — all derived. This is a code-review invariant for `Features/LinkIndex`.
2. *No migrations.* Index schema version bump (or `PRAGMA integrity_check` failure, or missing file) → delete and rebuild. Rebuild is offline, idempotent, and must complete from the `.md` files alone. Budget: ≤ 2 s for 1 000 nodes (tracked alongside `Dynamite Docs/notes/perf-baseline.md`).
3. *Index writes never touch `.md` files.* The indexer is read-only with respect to the graph.

**Malformed files.** A file whose YAML won't parse gets `parse_state = failed` and is surfaced in the UI. If the `id:` line is still recoverable by regex, the node is kept as an id-only tombstone so inbound links still resolve to *something* nameable; otherwise inbound edges show as broken. Last-known-good content is never silently substituted — stale ghosts are worse than visible gaps.

### 4. Folder layout

```
product/
  README.md        # generated once: explains layout + conventions for humans and agents
  discovery/       # problem, persona, vpc, bmc, lean-canvas, journey, story-map, ost, competitor, market-note
  planning/        # prd, spec, adr, roadmap-item, okr, experiment
  evidence/        # research-note, interview, feedback, insight, assumption
  gtm/             # gtm-brief, landing-page
  assets/          # optional: images, attachments
```

- **Four category folders, not 23 kind folders** (Finder-hostile) and not flat (unbrowsable at scale).
- Folders are **convention, not semantics**: `kind` comes from front-matter, identity from `id`. Move any file anywhere under `product/` — in Finder, in another editor, in a git rebase — and the graph is unaffected. This is constraint 3 made structural.
- Dynamite files new artifacts into the kind→category default; filenames are free-form kebab-case slugs (`indie-founder.md`); collisions are fine since identity is `id`.
- The product root defaults to `product/` and is configurable per workspace via `CEWorkspaceSettings` (`productRoot`) for repos with existing conventions (`docs/product/`, …).
- Standalone mode (no repo): the workspace root simply *is* the folder containing `product/`; nothing else changes.

## Alternatives considered

**Identity.** *Path-as-id* — breaks on rename; git rename detection is heuristic and external editors defeat it. *Sequential ids* (`PG-0042`) — collide across branches; the merge-friendliness constraint kills it. *Full UUIDs* — robust but illegible in front-matter and links; violates human-readability. *Chosen:* kind-prefix + short random suffix — readable, collision-safe, immutable.

**Link storage.** *Central `links.yaml`* — single contention point, merge hell, one corrupt file kills the whole graph. *Inline body wiki-links* (`[[asm-x7k4q]]`) — readable in place but mixes structure into prose, can't carry `rel` cleanly, and makes parsing every body edit load-bearing. Rejected as the primary representation; may later be accepted as *additional* sugar that compiles to `relates-to`. *Bidirectional links written to both files* — write amplification, double merge surface. *Chosen:* one-line flow mappings in the source file's front-matter; backlinks computed.

**Index.** *Flat JSON cache* — no queries, full rewrite per change, separate search structure needed; degrades with graph size. *In-memory only (rebuild each launch)* — launch cost grows with graph + repo size; violates the native-speed principle. *Core Data* — heavier, worse migration story than "delete and rebuild", and GRDB is already in the tree. *Chosen:* SQLite/GRDB, gitignored, disposable by construction.

**Folders.** *Per-kind (23 dirs)* — hostile to browsing, mostly near-empty. *Flat* — unbrowsable past ~50 files, and invites filename-as-metadata hacks. *Chosen:* per-category with folders-as-convention-only.

## Consequences

**Easier:** rename/move-safe links with no bookkeeping; conflict-free parallel work on the graph; instant search/filter/backlinks via SQL+FTS5; trivial corruption recovery (delete `.dynamite/`); agents and humans can create valid artifacts with nothing but a text editor and the README; the Context Compiler (M3) reads one well-defined model.

**Harder / must maintain:** an id↔path resolver pass on every scan; the anchor-rebinding machinery for code links (and its interaction with ADR-0002's repo index); the no-authoritative-data-in-index invariant needs code-review vigilance; YAML front-matter parsing must be robust against the wild (a fuzzed corpus belongs in `CodeEditTests`).

**Explicitly deferred:** body wiki-link sugar; multi-value link attributes (confidence, weight); cross-repo links; index schema for repo symbols (ADR-0002).
