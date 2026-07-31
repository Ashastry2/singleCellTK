# Architecture Decision Records

This directory records the architecturally significant decisions governing singleCellTK —
decisions that constrain what future contributors may do.

Start with [ADR-0000](0000-record-architecture-decisions.md), which explains the format and
why these records exist.

## Index

| # | Title | Status | Governs |
|---|---|---|---|
| [0000](0000-record-architecture-decisions.md) | Record architecture decisions | Accepted | This process |
| [0001](0001-sce-in-sce-out-contract.md) | SingleCellExperiment in, SingleCellExperiment out | Accepted | The contract every analysis function follows |
| [0002](0002-function-naming-families.md) | Function naming families | Accepted | `run*`/`plot*`/`import*`/`get*` prefixes, argument names, `@family` tags |
| [0003](0003-result-storage-and-tagging.md) | Result storage and assay tagging | Accepted | Where results go; the closed assay-tag vocabulary |
| [0004](0004-documentation-architecture.md) | Documentation architecture | Accepted | Roxygen vs vignette vs article vs README |
| [0005](0005-dependency-policy.md) | Dependency policy | Accepted | `Imports` vs `Suggests`; the `requireNamespace()` gate |
| [0006](0006-testing-strategy.md) | Testing strategy | Accepted | What a new tool must test |

## Where each ADR is implemented

| ADR | Code that implements it |
|---|---|
| 0001 | `R/validityFunctions.R` (`.selectSCEMatrix`, `.manageCellVar`), `R/runSoupX.R` |
| 0002 | `NAMESPACE`, `_pkgdown.yml`, roxygen `@family` tags throughout `R/` |
| 0003 | `R/sctkTagging.R`, `metadata(inSCE)$sctk` |
| 0004 | `vignettes/`, `vignettes/articles/`, `_pkgdown.yml`, `README.md` |
| 0005 | `DESCRIPTION`, `requireNamespace()` gates in `R/` |
| 0006 | `tests/testthat/`, `data/` |

## Reading order for a new contributor

If you are adding a function to the toolkit, read **0001 → 0002 → 0003**, then follow
[`../adding-a-new-tool.md`](../adding-a-new-tool.md), which turns those three into a
step-by-step recipe. Read 0005 only if your tool needs a package that is not already a
dependency.

## Writing a new ADR

1. Copy the structure of any existing record: Status, Date, Context, Decision, Consequences.
2. Take the next unused number. Numbers are never reused.
3. Be honest in **Consequences** about what gets *harder*. An ADR that lists only benefits is
   not recording a decision, it is advertising one.
4. Add a row to the index above.

To change an accepted decision, do not edit it. Write a new ADR, and mark the old one
*Superseded by ADR-NNNN*. The record of what was believed, and when, is the point.

## Provenance

ADRs 0000-0006 were written in July 2026 as part of a documentation audit, and are largely a
**reading of existing conventions in the code** rather than a transcript of the original
authors' reasoning. Where an ADR proposes something new, or contradicts current practice, it
says so explicitly and names the deviations. Maintainers who know the original intent should
correct them — by supersession.

The evidence behind each record is in [`../../docs-audit/`](../../docs-audit/).
