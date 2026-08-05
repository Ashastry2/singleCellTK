# Handoff — Steps 6–8: The Runtime Pass

**Status:** complete
**Date:** 2026-08-01
**Next step:** see "What comes next" below

---

## The premise of this pass was partly wrong

`next-pass.md` opened by saying the runtime work was blocked on installing 88 Bioconductor
dependencies, "the better part of an hour". **They were already installed** — all 88 hard
dependencies and all 19 `Suggests`, plus `devtools` and `pkgdown`.

Worse, the Step 4 conclusion that *"`man/` cannot be regenerated"* was **wrong**. It was not a
missing-dependency problem at all. I had tested with
`roxygen2::roxygenise(load_code = "source")`, which evaluates the package in a bare
environment where `setClassUnion()` in `R/sctkTagging.R` fails for want of its S4
dependencies. The default loader (`pkgload`) works fine. `devtools::document()` succeeded
immediately.

The lesson worth keeping: the failure was in **how I invoked the tool**, not in the
environment. A diagnostic that blames the environment deserves one more attempt with the
defaults before it becomes a documented blocker.

---

## Step 6 — Runtime established

| Fact | Value |
|---|---|
| R | 4.4.1 |
| BiocManager | 3.19 (package targets 3.20/3.21 — see below) |
| Hard dependencies installed | **88 / 88** |
| `Suggests` installed | **19 / 19** |
| Pandoc | **not available** — blocks pkgdown HTML rendering |

### Test baseline: 6 pre-existing errors

Recorded *before* any change in this pass, so later runs can be compared honestly:

| # | Test | Cause |
|---|---|---|
| 1 | `test-import.R:120` importGeneSetFromMSigDB | `msigdbr` renamed its arguments (`collection`/`subcollection`) |
| 2 | `test-misc.R:43` runVAM | same `msigdbr` drift |
| 3 | `test-misc.R:58` runGSVA | same `msigdbr` drift |
| 4 | `test-pathway.R:29` VAM | `S7::prop(x, "meta")` subscript out of bounds — GSVA version drift |
| 5 | `test-pathway.R:39` GSVA | same |
| 6 | `test-seuratFunctions.R:91` Seurat workflow | `Seurat` + `S7` incompatibility in `Ops` dispatch |

**All six are environment drift, not defects in this codebase.** The installed Bioconductor is
3.19 while the package targets 3.20/3.21, and `msigdbr`, `GSVA`, and `Seurat` have all moved
their APIs. None relates to any change made in this work. Anyone reading a red test run should
start here.

---

## Step 7 — `man/` regenerated, pkgdown verified

`devtools::document()` ran clean.

| Check | Result |
|---|---|
| `NAMESPACE` changed | **No** — exactly as Step 4 predicted. Nothing exported or unexported. |
| `man/*.Rd` changed | 218 files, **11,198 insertions, 0 deletions** |
| `.Rd` files with `Other <family> functions:` cross-links | **197** |
| `checkRd()` issues before | **73** |
| `checkRd()` issues after | **73** — identical, so regeneration introduced none |
| Documented topics covered by `_pkgdown.yml` | **237 / 237** |

### A mistake I made in Step 4, caught here

Regenerating `man/` revealed that I had introduced **three duplicate `@return` tags** in
`R/importGeneSets.R`. Those three functions already documented their return values; my
Step 4 checker missed them because line 509 of that file is a plain `#` comment sitting inside
a roxygen block, which broke the checker's contiguity walk backwards from the function
definition.

Removed. Each of the three now renders exactly one `\value{}` block. This is the second
measurement error from the static pass to surface (after the `@return` and "flat index" claims
corrected in Step 4) and it has the same shape: **a text-level heuristic that looked
authoritative and was not.**

### pkgdown findings

`pkgdown::check_pkgdown()` refused to run because **`_pkgdown.yml` had no `url` field** — a
genuine defect that also breaks cross-package link resolution. Added, along with matching
`URL:` in `DESCRIPTION`.

⚠️ **The URL is a guess.** It points at `https://ashastry2.github.io/singleCellTK`, the default
GitHub Pages location for this fork. Upstream's site is `camplab.net/sctk`, which is wrong for
a standalone fork. **Change it if this fork publishes elsewhere.**

**Pandoc is not installed**, so a full `pkgdown::build_site()` could not run. Installing pandoc
modifies the system and was left for the user to decide. The two claims that mattered were
verified without it:

- **All 207 article image references resolve** — a filesystem check, no pkgdown needed.
- **All 237 documented topics are covered by the reference index** — verified by matching
  `_pkgdown.yml` entries against `.Rd` topic *aliases*, which is what pkgdown actually
  resolves against. This is a stronger check than Step 4's, which compared export names.

---

## Step 8 — Bug candidates: 2 confirmed and fixed, 1 dismissed

Each was reproduced against a loaded package before being touched, per
[ADR-0006](../../docs/adr/0006-testing-strategy.md).

### 1. `getTopHVG()` padded its result with `NA` — CONFIRMED, FIXED

Reproduction: store a feature subset, then call with the default `hvgNumber`.

```
stored subset size: 97
getTopHVG() returned length: 2000     <- 1903 of them NA
```

`hvgNumber` was clamped to the number of available features only on the
`useFeatureSubset = NULL` branch. On the default branch it kept its default of 2000, so
`topGenes[1:hvgNumber]` padded the result. The `!is.na()` filter on the preceding line shows
the author expected no `NA`s by that point.

Fixed with `seq_len(min(hvgNumber, length(topGenes)))`. Verified across four cases: the
97-feature subset now returns 97 with no `NA`s; explicit truncation still truncates;
`hvgNumber = 0` returns 0 elements (it returned 2, because `1:0` is `c(1, 0)`); and the
non-subset path is unchanged.

**Impact:** this feeds feature selection for every downstream dimensionality reduction, so the
`NA`s propagated.

### 2. `plotSCEHeatmap()` scaled the wrong margin — CONFIRMED, FIXED

Reproduction: extract `@matrix` from the returned heatmap.

```
columns (cells) z-scored: TRUE
rows    (genes) z-scored: FALSE     <- doc says "on each row"
'min-max' output identical to raw data: TRUE
```

Two defects. `base::scale()` standardizes columns and `.minmax()` used `MARGIN = 2`, so with
the **default** `scale = TRUE` every heatmap was z-scored per cell rather than per gene. And
the documented `"min-max"` spelling never matched the code's `"min_max"` test, so that option
silently did nothing.

Fixed: transpose around `base::scale()`, `MARGIN = 1` for min-max, accept both spellings, and
return 0 rather than `NaN` for a zero-variance feature.

⚠️ **This changes the appearance of nearly every heatmap the function produces.** Flagged
prominently in `NEWS.md`. The previous behaviour did not error — it drew a convincing wrong
picture, which is why it survived.

Checked and cleared: the heatmap matrix carries no dimnames, but the untouched `scale = FALSE`
path behaves identically, so that is pre-existing and not a regression.

### 3. `summarizeSCE()` example — DISMISSED, false positive

`summarizeSCE(mouseBrainSubsetSCE, sample = NULL)` **runs correctly**. R's partial argument
matching resolves `sample` to `sampleVariableName` unambiguously, since no other formal shares
that prefix. The example was never broken and `R CMD check` would not have flagged it.

Tidied to use the full argument name — relying on partial matching is fragile — but recorded
as a dismissal, not a fix.

### Regression tests

Added to `tests/testthat/test-featureSelection.R` and `tests/testthat/test-plotting.R`, each
asserting the specific failure mode with a comment explaining what went wrong. Both files pass
with **0 failures**.

---

## Honest scorecard for the static audit

**2 of 3 confirmed.** The candidates judged most likely to be real were, roughly, two-thirds
real. Extrapolating, perhaps a third of the remaining 32 will not survive contact with a
runtime. That is a reasonable yield for static analysis and a poor basis for bulk-applying
fixes.

Across this whole effort the static pass produced four measurement errors — the `@return`
count (24 vs 3), the "flat reference index" claim, the duplicate `@return` insertions, and the
"`man/` cannot be regenerated" conclusion. Every one had the same character: a heuristic over
text, stated with more confidence than it had earned. The findings were directionally right
often enough to be worth having; the specific numbers needed checking.

---

## What comes next

**Highest value first:**

1. **Resolve the Bioconductor version mismatch.** Installed 3.19 vs targeted 3.20/3.21 causes
   all 6 baseline test errors. Until that is fixed, `R CMD check` cannot give a clean signal
   and no other test work is trustworthy.
2. **Install pandoc, run `pkgdown::build_site()`.** The last unverified Step 4 claim.
3. **Work through the remaining 32 bug candidates**, in `bug-candidates.md` severity order,
   each with a reproduction first. Expect a meaningful dismissal rate.
4. **Measure coverage** with `covr::package_coverage()` — still never measured, so
   [ADR-0006](../../docs/adr/0006-testing-strategy.md) deliberately sets no target.
5. **Dependency reduction** per [ADR-0005](../../docs/adr/0005-dependency-policy.md), starting
   by deleting `.testFunctions()` and reading the `R CMD check` NOTE it currently suppresses.
   Untouched in this pass.
6. **The deferred documentation** — `@examples` for the 49 exports lacking them, the README
   quick-start (now unblocked, since the `getTopHVG()` bug it depended on is fixed), and
   rewriting the stub vignette.

**Still not done, deliberately:** no dependency was moved, `.testFunctions()` still exists, no
article was consolidated, and `R CMD check` was never run end to end — it needs the
Bioconductor version fixed first to mean anything.
