# ADR-0006: Testing strategy

- **Status:** Accepted
- **Date:** 2026-07-31

## Context

The package has **24 testthat files against 251 exported functions**. The audit did not
measure line coverage — that requires `covr`, which requires a full installation — so the
ratio is the only number available, and it is indicative rather than precise.

Reading the existing tests shows an established and reasonable shape. `tests/testthat/test-qc.R`
is representative:

```r
library(singleCellTK)
context("Testing dimensionality reduction algorithms")
data(scExample, package = "singleCellTK")
sce <- subsetSCECols(sce, colData = "type != 'EmptyDroplet'")
```

Five fixture datasets ship in `data/`: `scExample` (the standard one — a small PBMC subset),
`mouseBrainSubsetSCE`, `sceBatches`, `MitoGenes`, `SEG`, `msigdb_table`. Tests load a fixture,
run a function, and assert on the class and structure of the result. Assertions are mostly
`expect_is()` on the return type.

Two gaps are visible:

1. **Almost no conditional skipping.** Across all 24 files there are 2 `skip_if_not()` calls
   and 2 bare `skip()` calls. Under ADR-0005, roughly 25 packages move to `Suggests` — and
   every test touching them will need `skip_if_not_installed()`, or the suite breaks for
   anyone without the optional package.
2. **Assertions are shallow.** `expect_is(p1, "ggplot")` confirms a plot object came back. It
   does not confirm the plot is correct. This matters concretely: the worst bug candidate found
   (`plotSCEHeatmap()` scaling per cell instead of per gene,
   `docs-audit/bug-candidates.md` §2) would pass every existing plotting test, because the
   returned object has exactly the right class. Likewise `getTopHVG()` returning a vector
   padded with `NA` would satisfy a length check.

There is a real constraint behind the shallowness: many of these functions wrap stochastic or
version-sensitive third-party methods, where asserting exact numerical output produces tests
that fail on an upstream patch release rather than on a real defect.

## Decision

**1. A new exported function ships with a test in the same PR.** No exceptions for "obvious"
functions — the audit found that documented examples for obvious functions are exactly where
errors hide (`R/miscFunctions.R:17` documents `summarizeSCE(sce, sample = NULL)` against a
formal that does not exist).

**2. Test file placement mirrors the source**, and follows the existing grouping: one file per
topic (`test-qc.R`, `test-clustering.R`), not one per function.

**3. Every test for a `run*` function asserts the ADR-0001 contract**, at minimum:

```r
test_that("runX writes its result into the SCE", {
    data(scExample, package = "singleCellTK")
    sce <- subsetSCECols(sce, colData = "type != 'EmptyDroplet'")
    out <- runX(sce, assayName = "xResult")

    expect_s4_class(out, "SingleCellExperiment")     # returns an SCE
    expect_true("xResult" %in% assayNames(out))      # named output present
    expect_equal(dim(out), dim(sce))                 # dimensions preserved
    expect_true("xResult" %in% expTaggedData(out, showTags = FALSE))  # tagged (ADR-0003)
})
```

Those four assertions are cheap, deterministic, and independent of the backend's numerical
behaviour. They catch the class of defect the current suite misses.

**4. Assert on structure and invariants, not exact numbers.** For stochastic methods, assert
what must be true regardless of the seed: output dimensions, absence of `NA` where none is
expected, value ranges, monotonicity. **Specifically assert absence of `NA`** in feature and
cell selections — that single assertion catches the `getTopHVG()` candidate.

**5. Optional dependencies are skipped, not assumed:**

```r
skip_if_not_installed("scMerge")
```

This is mandatory for every test touching a package that ADR-0005 moves to `Suggests`. Tests
requiring network access (`importExampleData()`, `enrichR`) use `skip_on_ci()` or
`skip_if_offline()`. Tests requiring Python use `skip_if_not(reticulate::py_available())`.

**6. Fixtures come from `data/`, never from the network.** `scExample` is the default.
`importExampleData()` needs `ExperimentHub` and network access and is unsuitable for tests or
for `@examples`, however convenient it is for a README.

**7. A confirmed bug gets a regression test that fails before the fix.** For the 35 candidates
in `docs-audit/bug-candidates.md`, the order is: write the failing test, confirm it fails *for
the stated reason*, then fix. Several candidates will turn out to be guarded by a caller the
static analysis did not trace — the test is what distinguishes those from real defects.

**8. Slow tests are skipped on CI, not deleted.** `skip_on_ci()` with a comment saying why.
A test that only ever runs locally is still worth more than no test.

## Consequences

**Easier:** The contract assertions turn ADR-0001 and ADR-0003 from prose into something
mechanically checked, so a violation is caught in CI rather than in review. The bug candidates
get a disciplined path from suspicion to fix. Moving dependencies to `Suggests` becomes safe,
because the suite degrades gracefully instead of collapsing.

**Harder:** Every PR adding a function now has an additional obligation, and contributors will
sometimes find writing the test harder than writing the function. Adding
`skip_if_not_installed()` across the suite means CI's green result no longer proves much on
its own — a run where half the suite skipped looks identical to one where it all passed, so at
least one CI job must install the full `Suggests` set to keep the gated paths honest.

**Neutral:** This ADR sets policy and does not set a coverage target. Choosing a number
without having measured coverage would be arbitrary. Measuring it with `covr`, and then
deciding, is queued in `docs-audit/next-pass.md`.

## References

- `tests/testthat/test-qc.R` — the existing fixture-and-assert pattern
- `data/` — the five bundled fixtures
- `docs-audit/bug-candidates.md` — the 35 candidates awaiting regression tests
- ADR-0001, ADR-0003 — the contracts these tests assert
- ADR-0005 — the dependency moves that make skipping mandatory
