# Proposal: Add `swift-markdown` as Dynamite's Markdown Structure Layer

- Status: proposed
- Date: 2026-06-14
- Related product areas: ProductGraph, ContextEngine, LinkIndex, RepoAwareness, TruthLayer
- Proposed dependency: <https://github.com/swiftlang/swift-markdown>
- License: Apache-2.0

## Summary

Dynamite already has a native Markdown editing surface through `nodes-app/swift-markdown-engine`. That gives users a good place to write Markdown.

`swift-markdown` would solve a different problem: it lets Dynamite understand Markdown as structured data.

The simplest distinction is:

- `swift-markdown-engine`: the user-facing editor.
- `swift-markdown`: the internal parser and document model.

In product terms, `swift-markdown-engine` helps humans write artifacts. `swift-markdown` helps Dynamite read, validate, transform, link, compile, and compare those artifacts.

## Why This Matters

Dynamite's core data format is plain Markdown on disk. PRDs, specs, ADRs, interviews, assumptions, roadmap items, context files, and agent briefing packs all live as `.md`.

If Dynamite treats those files as plain strings, features become fragile:

- finding sections depends on text search
- inserting generated content risks putting it in the wrong place
- checking required sections becomes inconsistent
- links and citations are hard to extract reliably
- context files are easy to overwrite incorrectly
- Reality Diff and Drift Radar cannot reason about document structure

`swift-markdown` gives Dynamite a structured representation of each document:

```text
Document
  Heading level 1: "PRD"
  Heading level 2: "Problem"
  Paragraph
  Heading level 2: "Requirements"
  Unordered list
    List item
    List item
  Heading level 2: "Risks"
  Task list
```

Once Dynamite has that structure, Markdown becomes an application data source instead of only a text file.

## Where Dynamite Would Use It

### 1. ProductGraph

ProductGraph owns typed artifacts such as PRDs, specs, ADRs, interviews, feedback, assumptions, insights, personas, and roadmap items.

`swift-markdown` would be used when loading or saving artifact Markdown.

Concrete uses:

- detect the artifact title from the first H1
- extract H2/H3 sections into typed fields
- validate required sections for each artifact kind
- extract task lists from roadmap items or specs
- detect empty or placeholder sections
- preserve unknown user-written sections instead of overwriting them
- convert Markdown sections into board/canvas state

Example:

```md
# Checkout PRD

## Problem
Users abandon checkout when shipping cost appears late.

## Acceptance Criteria
- [ ] Shipping cost is visible before payment
- [ ] Returning users see saved address options

## Risks
- Tax calculation varies by region
```

With `swift-markdown`, ProductGraph can ask:

- What is the artifact title?
- Does this PRD have a `Problem` section?
- What checklist items are under `Acceptance Criteria`?
- Which risks should become linked assumptions?

Without it, Dynamite has to guess by scanning raw text.

### 2. ContextEngine

ContextEngine compiles the Product Graph into files external agents can read:

- `AGENTS.md`
- `CLAUDE.md`
- per-folder context files
- briefing packs
- Context Lens previews

This is one of the strongest reasons to add `swift-markdown`.

Concrete uses:

- parse source artifacts before compiling context
- extract only the sections relevant to a task
- merge compiler-owned sections without destroying user-owned writing
- regenerate `AGENTS.md` in a stable, reviewable way
- validate generated Markdown before writing it to disk
- preserve headings, lists, links, and code blocks correctly

Example flow:

```text
PRD.md + ADR.md + assumptions + repo citations
        |
        v
swift-markdown parses documents into structure
        |
        v
ContextEngine selects relevant sections
        |
        v
ContextEngine writes AGENTS.md / briefing pack
```

This matters because context generation should be deterministic and reviewable. It should not be a pile of string concatenation.

### 3. LinkIndex

LinkIndex is the shared plumbing for doc-to-doc and doc-to-code links.

`swift-markdown` would help rebuild the index from Markdown files.

Concrete uses:

- extract Markdown links like `[Spec](../specs/foo.md)`
- extract wiki-style links if Dynamite supports them in artifact text
- extract repo citations like `CodeEdit/Features/ProductGraph/...`
- map headings to stable anchors
- detect broken links
- build backlinks
- update links after rename or move

Example:

```md
This requirement is implemented in
[`CheckoutViewModel.swift`](../CodeEdit/Features/Checkout/CheckoutViewModel.swift).

See also [[Assumption: Shipping price sensitivity]].
```

LinkIndex can parse this and create edges:

```text
PRD -> source file
PRD -> assumption
source file -> PRD backlink
assumption -> PRD backlink
```

### 4. Artifact Board Views

Architecture already mentions board views such as VPC, BMC, Lean Canvas, Journey Map, Story Map, OST, and Roadmap.

Those views need a reliable way to map Markdown sections to visual cells/cards.

Concrete uses:

- parse H2/H3 sections into board columns
- parse bullet lists into cards
- round-trip board edits back into Markdown
- keep the Source view and Board view synchronized
- avoid losing user notes that do not belong to a known board cell

Example:

```md
## Now
- Improve context compiler
- Add product graph backlinks

## Next
- Repo X-Ray
- Ask the Product

## Later
- Stakeholder Digest
```

RoadmapBoardView could parse this into columns without custom string splitting.

### 5. AIAssist

AIAssist drafts and refines artifact content, but Dynamite should still be in control of the document structure.

`swift-markdown` would sit between AI output and files on disk.

Concrete uses:

- validate that AI returned Markdown with the expected sections
- insert AI-generated content into the right section
- reject or repair malformed output before saving
- compare old and new document structure before applying changes
- support "rewrite only the Risks section" without touching the rest

Example:

```text
User asks: "Improve the risks section."

Dynamite:
1. parses the document
2. extracts only ## Risks
3. sends that section to AIAssist
4. parses the returned Markdown
5. replaces only ## Risks
6. leaves the rest of the PRD untouched
```

### 6. RepoAwareness

RepoAwareness connects product claims to code citations.

`swift-markdown` would help read product docs and find claims, links, and citation blocks that refer to the repository.

Concrete uses:

- extract all code citations from PRDs/specs/ADRs
- identify sections that make repo-derived claims
- attach repo references to the right product artifact section
- support Ask the Product answers with citations back into source docs

Example:

```md
## Current Behavior
The editor stores undo state per document instance.

Citation: `CodeEdit/Features/ProductGraph/...`
```

RepoAwareness can associate the claim with that section, not merely with the whole file.

### 7. TruthLayer

TruthLayer includes Assumption Ledger, Reality Diff, Drift Radar, Decision Replay, and Stakeholder Digest.

These features need to compare what documents say against what the repo and product graph show.

Concrete uses:

- find stale sections in specs and PRDs
- detect claims without citations
- detect assumptions mentioned in specs but missing from the ledger
- summarize changes by document section
- produce stakeholder updates from structured sections

Example:

```text
Reality Diff:
- PRD says "export supports PDF"
- repo index finds no export path or PDF dependency
- section is flagged as ungrounded
```

`swift-markdown` helps Reality Diff know exactly where the claim lives in the document.

## Proposed Architecture

Add a small internal wrapper instead of spreading direct `swift-markdown` calls everywhere.

Suggested folder:

```text
CodeEdit/Features/ProductGraph/Markdown/
```

Possible types:

```text
MarkdownDocumentParser
MarkdownSection
MarkdownSectionExtractor
MarkdownChecklistExtractor
MarkdownLinkExtractor
MarkdownDocumentRewriter
ArtifactMarkdownValidator
```

The wrapper should expose Dynamite concepts, not library concepts.

For example, callers should ask:

```swift
let sections = parser.sections(in: markdownText)
let links = parser.links(in: markdownText)
let result = validator.validatePRD(markdownText)
```

Callers should not need to know the full `swift-markdown` AST unless they are working inside the Markdown infrastructure.

## Relationship To `swift-markdown-engine`

These two dependencies should not compete.

The editor remains responsible for user interaction:

```text
User types in Product Studio
        |
        v
swift-markdown-engine displays and edits Markdown
        |
        v
Markdown text changes on disk or in memory
        |
        v
swift-markdown parses the text for ProductGraph, LinkIndex, ContextEngine
```

The editor should not become responsible for ProductGraph semantics. Likewise, the parser should not be responsible for editing UI.

## First Implementation Slice

Start small. Do not add every possible Markdown workflow at once.

Recommended first slice:

1. Add `swift-markdown` as an SPM dependency.
2. Create a `MarkdownDocumentParser` wrapper.
3. Implement heading/section extraction.
4. Implement Markdown link extraction.
5. Add tests with representative Dynamite artifact files.
6. Use it in one feature first: ProductGraph artifact validation or ContextEngine compilation.

Good first feature:

```text
Validate a PRD artifact has required sections:
- Problem
- Users
- Requirements
- Acceptance Criteria
- Risks
```

That gives an immediate product benefit without touching the editor.

## Risks

- `swift-markdown` does not replace a full editor. This is fine because Dynamite already has one.
- Custom syntaxes such as wiki links may need a small supplemental parser if they are not standard Markdown nodes.
- Rewriting Markdown while preserving the user's exact formatting can be hard. Start with read/extract/validate before doing aggressive rewrites.
- The dependency is Apache-2.0, so notices and license obligations must be preserved.

## Recommendation

Add `swift-markdown`, but use it narrowly at first.

The best initial use is not rendering and not editing. The best initial use is making ProductGraph and ContextEngine treat `.md` files as structured product data.

That is directly aligned with Dynamite's moat: the graph, repo, and generated agent context all become more reliable when Markdown is parsed structurally instead of handled as plain text.
