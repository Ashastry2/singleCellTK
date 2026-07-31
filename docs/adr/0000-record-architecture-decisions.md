# ADR-0000: Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-07-31

## Context

singleCellTK is a large, long-lived package: 87 files in `R/`, 251 exported functions, 88
hard dependencies, two user interfaces (console and Shiny), and contributions from many
authors over many years.

An audit of the package (`docs-audit/`) found that it has **strong conventions that are
nowhere written down**. Every `run*` function takes and returns a `SingleCellExperiment`.
Every user-supplied `colData` variable goes through `.manageCellVar()`. Every assay-producing
function tags its output via `expSetDataTag()`. Every `seed` argument routes through
`withr::with_seed()`. 82% of exported functions follow a prefix naming convention.

None of that is documented. It exists only as a pattern a contributor might infer by reading
enough source. The consequences are visible in the audit: helper functions built precisely to
validate user input are used inconsistently (`.selectSCEMatrix()` in 18 places but not in
`plotDimRed()`, which then produces "invalid subscript" errors); the tag vocabulary has
drifted (`"raw"`, `"normalized"`, `"scaled"`, `"batchCorrected"`, but also `"counts"` and
`"decontXcounts"`, which are assay names, not types); and dependencies accumulate with no
recorded rationale for why each one is mandatory.

The cost of an undocumented convention is not that it gets broken loudly — it is that it gets
broken quietly, by someone who had no way to know it existed.

## Decision

We will record architecturally significant decisions as **Architecture Decision Records**, in
`docs/adr/`, in the format described by Michael Nygard.

A decision is architecturally significant if it constrains what future contributors may do:
the shape of a public function contract, where results are stored, what may be added to
`DESCRIPTION`, how documentation is organized. Ordinary implementation choices are not ADRs.

**Format.** Each ADR is a file named `NNNN-kebab-case-title.md` with:

- **Status** — Proposed, Accepted, Deprecated, or Superseded by ADR-NNNN
- **Date**
- **Context** — the forces at play, stated factually, including evidence from the code
- **Decision** — what we will do, in the active voice ("we will…")
- **Consequences** — what becomes easier *and* what becomes harder, honestly

**Numbering.** Sequential, never reused. `0000` is this record.

**Immutability.** An accepted ADR is not edited to reflect a change of mind. It is marked
*Superseded by ADR-NNNN* and a new one is written. The record of what we believed, and when,
is the point.

**A note on these first ADRs.** ADRs 0002-0005 largely **document conventions that already
exist in the code** rather than introducing new ones. This is deliberate. Writing down an
existing convention converts tribal knowledge into something a newcomer — or an AI agent —
can follow, and gives future contributors a place to argue with it. Where an ADR proposes
something genuinely new, or contradicts current practice, it says so explicitly.

## Consequences

**Easier:** A contributor adding a function has a written contract to conform to rather than
a codebase to reverse-engineer. Disagreements about conventions get a specific document to
argue against. AI agents working in this repository can be pointed at `docs/adr/` and
`AGENTS.md` instead of inferring conventions from a sample of files — which is how conventions
get silently broken at scale.

**Harder:** Every architecturally significant change now carries a documentation obligation.
ADRs go stale if the code moves and nobody supersedes them — a stale ADR that contradicts the
code is worse than no ADR, because it is trusted. Mitigation: `CONTRIBUTING.md` requires that
a PR changing a documented convention either conform to the ADR or supersede it, and the ADR
index links each record to the code that implements it.

**Neutral:** The first eight ADRs are being written after the fact, by an agent auditing the
package rather than by the authors who made the decisions. They are therefore a *reading* of
the code's intent, not a transcript of the original reasoning. Where the reading is uncertain,
the ADR says so. Maintainers should feel free to correct them — that is what supersession is
for.

## References

- Michael Nygard, ["Documenting Architecture Decisions"](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions.html) (2011)
- `docs-audit/` — the audit that motivated these records
