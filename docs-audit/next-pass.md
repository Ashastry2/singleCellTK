# Next Pass — Work Requiring a Runtime

Everything here was deliberately **not** done in the July 2026 static pass, because doing it
responsibly requires the package installed and its 88 dependencies resolved. Each item names
what must be true before it can be attempted, and roughly what it costs.

**Prerequisite for almost all of this:**

```r
BiocManager::install(version = "3.20")
devtools::install_deps(dependencies = TRUE)   # slow — the better part of an hour
devtools::load_all()
```

---

## P0 — Do this first, before anything else

### 1. Regenerate `man/`

**The roxygen sources changed in Step 4 but `man/*.Rd` did not.** 221 `@family` tags and 3
`@return` entries are in `R/` and are **not** reflected in the rendered help pages, because
roxygen must evaluate the package code to run and the dependency tree was unavailable.

```r
devtools::document()
git diff --stat man/ NAMESPACE
```

Expect changes to ~221 `.Rd` files (new `\seealso{Other run functions: ...}` blocks) and
**no change to `NAMESPACE`** — nothing was exported or unexported. If `NAMESPACE` changes,
stop and investigate.

Until this runs, the package's documentation is internally inconsistent. It is the single
highest-priority item in this document.

### 2. Confirm the pkgdown site builds

```r
pkgdown::build_site()
```

Two Step 4 changes want verification: all 207 article images should now resolve, and all 251
exports should be covered by a reference section. A clean build with no "topic not indexed"
warnings and no missing-image warnings confirms both.

---

## P1 — Bug candidates

35 candidates are catalogued in [`bug-candidates.md`](bug-candidates.md), **all unverified**.
The discipline for each, per [ADR-0006](../docs/adr/0006-testing-strategy.md):

1. Write a test asserting the documented failure scenario.
2. Confirm it fails **for the stated reason**. Several will turn out to be guarded by a caller
   the static analysis did not trace — that is a successful outcome, not a wasted test.
3. Fix, keeping the test as a regression guard.

**Start with these three.** The first two produce silently wrong scientific output — the worst
failure mode an analysis package has — and the third fails `R CMD check` today:

| Priority | Candidate | Why first |
|---|---|---|
| 1 | `R/getTopHVG.R:103` — `topGenes[1:hvgNumber]` pads with `NA` on the default path | Feature selection feeds every downstream step; `NA`s propagate silently |
| 2 | `R/plotSCEHeatmap.R:218,273` — scales per cell while documenting per row, and `scale = TRUE` is the default | Does not error; draws a plausible but wrong picture |
| 3 | `R/miscFunctions.R:17` — `@examples` calls `summarizeSCE(sce, sample = NULL)` against a formal named `sampleVariableName` | A documented example that cannot run; `R CMD check` catches it |

Then the remaining High-severity entries, then Medium. The Low tier is mostly robustness and
can wait.

**Estimated effort:** the three above, perhaps a day including tests. All 35, considerably more
— and some will be dismissed on contact.

## P1 — Test coverage

24 test files against 251 exports. **Coverage was never measured** — that needs `covr`, which
needs the install. Measure before setting any target:

```r
covr::package_coverage()
```

Then, per [ADR-0006](../docs/adr/0006-testing-strategy.md):

- Add the four contract assertions to existing `run*` tests. Mechanical, high value: it turns
  ADR-0001 and ADR-0003 from prose into something CI enforces.
- Add `expect_false(any(is.na(...)))` to feature-selection and subsetting tests. This single
  assertion catches the `getTopHVG()` candidate.
- Thin areas with no dedicated test file: the `import*` family (20 exports), `export*`,
  `report*` (16 exports), and `reticulate_setup.R`.

## P2 — Dependency reduction

Policy is set in [ADR-0005](../docs/adr/0005-dependency-policy.md); the evidence is in
[`dependencies.md`](dependencies.md). **88 → roughly 60.** Order matters:

**Step 1 — delete `.testFunctions()`** (`R/miscFunctions.R:146`). It must go first, because
the `R CMD check` NOTE it suppresses is the authoritative version of the dependency audit — it
knows about bare, unqualified uses that `grep` cannot see. Deleting it will surface a NOTE
naming every unused dependency. **That NOTE is the tool.** Do not re-suppress it.

**Step 2 — act on what the NOTE says**, in increasing order of risk:

| Tier | Packages | Risk |
|---|---|---|
| Remove — unused | `ape`, `cluster`, `ggtree` | Low, but confirm no bare calls in `inst/shiny/` via `codetools::checkUsagePackage()` |
| Remove — native feature | `magrittr` (`%>%` → `\|>`) | Low; requires bumping the declared R floor, which is stale anyway |
| → `Suggests`, GUI-gated | `shinyjs`, `DT`, `colourpicker`, `shinyalert`, `shinycssloaders` | Low — gate once at `singleCellTK()` |
| → `Suggests`, example-data-gated | `TENxPBMCData`, `ExperimentHub`, `AnnotationHub`, `ensembldb`, `GSVAdata` | Low |
| → `Suggests`, feature-gated | `zinbwave`, `scMerge`, `sva`, `batchelor`, `SingleR`, `GSVA`, `VAM`, `msigdbr`, `enrichR`, `Rtsne`, `multtest`, `metap`, `ROCR`, `tximport`, `eds` | **Medium** — 15 separate gates, each needing an error message and `skip_if_not_installed()` in its tests |

**Step 3 — fix `inst/shiny/ui.R:1-9`**, which calls `install.packages()` at launch. Replace
with `requireNamespace()` checks that stop with a message. Declare `tidyverse` or, better,
replace it with the specific packages actually used.

**Step 4 — correct `DESCRIPTION`:** `R (>= 4.0)` → `R (>= 4.4)` to match Bioconductor 3.20.
Also evaluate whether `DelayedArray` and `Biobase` need to be in `Depends` rather than
`Imports`.

**Do not begin any of this without a working `devtools::check()` baseline** — the whole point
is that `R CMD check` is the oracle.

## P2 — Documentation completion

| Item | Blocked on |
|---|---|
| `@examples` for the 49 exports lacking them | Runtime, to verify each example runs against the `scExample` fixture. The 13 `report*` ones legitimately need `\dontrun{}`. |
| README quick-start | Runtime. The draft is in [`readme-and-install.md`](readme-and-install.md) §3 with every symbol checked against `NAMESPACE`, but `setTopHVG`'s formals were never read and it exercises the `getTopHVG()` bug candidate — resolve that first. |
| Rewrite `vignettes/singleCellTK.Rmd` | Runtime. Currently a 102-line stub; [ADR-0004](../docs/adr/0004-documentation-architecture.md) requires it to carry a runnable end-to-end workflow. Must use bundled `scExample`, not `importExampleData()`. |
| QC article consolidation | Runtime. Taxonomy decided in [`articles.md`](articles.md) §4: merge `ui_qc` into `01`, retitle the `cnsl_*` pair as references, move `02_a_la_carte` out of the QC group. |
| Un-`eval=FALSE` the celda and scanpy workflows | Runtime + a Python environment. 11 of 11 chunks in `celda_curated_workflow.Rmd` are unevaluated, so its code has never been validated. |
| `@param` prose quality review | Manual, 251 functions. Completeness is confirmed; usefulness is not. |
| Re-verify `camplab.net` | A network you trust. Every such URL failed from the audit machine, but TLS *stalled* rather than refusing, so this may be a sandbox artifact. `sctk.bu.edu` resolves and may be the intended replacement. |

## P3 — Housekeeping

- **Delete `.travis.yml`.** GitHub Actions is the live CI; the Travis config is dead weight
  that implies otherwise.
- **Resolve the duplicated images.** Step 4 copied 44 MB of screenshots into
  `vignettes/articles/`, and the same files remain tracked under `docs/`. That is deliberate —
  `vignettes/articles/` is the correct home for *sources* — but it doubles the repository
  size. The clean end state is: sources in `vignettes/`, and `docs/` untracked and regenerated
  by CI. Untracking `docs/` is a large, disruptive commit and deserves its own decision.
- **`scaterCPM` / `scaterPCA` / `scaterlogNormCounts`** violate ADR-0002 (named for the
  backend, not the action; and the third breaks camelCase). Renaming is a breaking change
  needing a deprecation cycle.
- **The assay-tag vocabulary drift** — `"counts"` ×3 and `"decontXcounts"` ×1 are assay
  *names* used as type tags ([ADR-0003](../docs/adr/0003-result-storage-and-tagging.md)).
  Fixing them changes GUI dropdown grouping, so it needs the GUI running to verify.
- **`runGSVA()` appends duplicates** to `metadata$pathwayAnalysisResultNames` on every re-run
  (`R/runGSVA.R:50-56`).
- **Add a `.github/ISSUE_TEMPLATE` and PR template.** Neither exists.

---

## Suggested order

1. **P0** — regenerate `man/`, confirm the pkgdown build. Nothing else is trustworthy until
   the documentation is internally consistent.
2. **Establish a `devtools::check()` baseline** and record it. Every later step is measured
   against it.
3. **The three P1 bugs**, each with a regression test.
4. **Contract assertions** across existing `run*` tests, plus a coverage measurement.
5. **Dependency reduction**, beginning with deleting `.testFunctions()` and reading the NOTE.
6. **Documentation completion**, starting with the vignette — it is the only shipped
   documentation and it is currently empty.

## A note on the static-pass findings

Everything in `docs-audit/` was produced without running the package. That was the right
constraint for a first pass — it is fast, and it cannot break anything — but it has a specific
failure mode worth remembering: **it over-reports.**

Two claims in these documents were already corrected during Step 4, both cases of a
measurement being too literal. The `@return` gap was reported as 24 and turned out to be 3,
because the check counted tags per roxygen block and ignored `@rdname` inheritance. The
pkgdown reference index was described as "a flat alphabetical list" when it has had 21 topical
sections all along.

Treat the 35 bug candidates with the same suspicion. They are leads, not defects.
