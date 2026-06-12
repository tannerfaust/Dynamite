---
id: adr-xxxxx
kind: adr
status: proposed
deciders: ["User Name"]
created: 2026-06-10
updated: 2026-06-10
v: 1
title: ADR Title
tags: []
links: []
---

# ADR Title

## Context
*What is the problem we are solving, and what constraints exist?*
<!-- Example:
Storing the local LinkIndex database in Git causes frequent merge conflicts on concurrent edits.
-->

## Decision
*What is the chosen approach, and why did we choose it?*
<!-- Example:
Use SQLite via GRDB at .dynamite/index.db, and ignore the entire directory in Git. The index is disposable.
-->

## Alternatives
*What other options did we consider, and why did we reject them?*
<!-- Example:
- Flat JSON cache: slow query/search performance at scale.
- Core Data: heavy setup overhead and difficult merge conflict resolutions.
-->

## Consequences
*What are the trade-offs, risks, or follow-up tasks of this decision?*
<!-- Example:
- Easy: SQLite handles backlinks and FTS5 instantly.
- Hard: Must handle index corruption by deleting and rebuilding it from files.
-->
