# Dependency Inventory

**Method:** static. For every entry in `DESCRIPTION` `Depends`/`Imports`, count call sites
matching `pkg::` in `R/`, `importFrom()`/`import()` directives in `NAMESPACE`, and usage in
`inst/shiny/`, `inst/rmarkdown/`, `vignettes/`, and `tests/`. Nothing was installed or run.

**Status:** evidence only. **No `DESCRIPTION` change is made in this pass** — the policy for
making these moves is ADR-0006, and the moves themselves are queued in `next-pass.md`.

Reproduce with the script in the scratchpad (`depaudit.R`); the logic is 40 lines of
`read.dcf` + `grep` and is easy to re-run after any change.

## Headline numbers

| | Count |
| --- | --- |
| `Depends` (excluding R itself) | 4 |
| `Imports` | 84 |
| `Suggests` | 19 |
| **Total hard dependencies** | **88** |

88 hard dependencies is the core problem. Every one of them must install before a user can
call `library(singleCellTK)`, and the set spans Seurat, DESeq2, celda, SoupX, GSVA, zinbwave,
scMerge, batchelor, SingleR, and a Python bridge via reticulate. The install is the single
biggest barrier to adoption and to CI.

The distribution is extremely long-tailed. The top 20 packages account for the overwhelming
majority of call sites:

| Package | Field | `R/` call sites | Files |
| --- | --- | --- | --- |
| SummarizedExperiment | Depends | 249 | 41 |
| ggplot2 | Imports | 247 | 12 |
| S4Vectors | Imports | 179 | 43 |
| SingleCellExperiment | Depends | 133 | 39 |
| Seurat | Imports | 109 | 5 |
| stats | Imports | 95 | 18 |
| reticulate | Imports | 74 | 8 |
| methods | Imports | 52 | 12 |
| utils | Imports | 29 | 18 |
| rmarkdown | Imports | 26 | 1 |
| Matrix | Imports | 24 | 7 |
| GSEABase | Imports | 23 | 2 |
| zellkonverter | Imports | 22 | 3 |
| SoupX | Imports | 21 | 1 |
| data.table | Imports | 17 | 8 |
| withr | Imports | 17 | 10 |
| BiocParallel | Imports | 15 | 6 |
| dplyr | Imports | 14 | 5 |
| cowplot | Imports | 13 | 5 |
| grid | Imports | 12 | 3 |

Against that, **46 of the 88 have three or fewer call sites in `R/`**, and 27 have exactly
one. That tail is where the reduction opportunity lives.

---

## Finding 1 (High) — `.testFunctions()` is a dead stub that pins 4 packages

`R/miscFunctions.R:146-163` defines an unexported, uncalled function whose entire body is
wrapped in `if (interactive())`:

```r
#test shiny functions
.testFunctions <- function(){
  if (interactive()){
    res <- DT::datatable(matrix(1, 2))
    shinyjs::runExample("basic")
    shinyalert::runExample()
    p <- plotly::plot_ly(...)
    colourpicker::runExample()
    rt <- ape::rtree(10)
    gt <- ggtree::ggtree(rt)
    shinycssloaders::withSpinner(shiny::plotOutput("my_plot"))
    ...
    clarax <- cluster::clara(x, 2, samples = 50)
    circlize::colorRamp2(...)
  }
}
```

Nothing calls it. It computes results into local variables and discards them. Its evident
purpose is to suppress the `R CMD check` NOTE *"Namespaces in Imports field not imported
from"* by manufacturing a syntactic reference to each package.

This is worth calling out plainly: it is not a bug that produces wrong answers, but it
**defeats the exact check that would otherwise tell maintainers which dependencies are
unused**. It converts a useful signal into silence, and it is the reason the following four
packages remain in `Imports` despite having no functional role anywhere in the package:

| Package | Only `R/` site | Real use in `inst/shiny/`? |
| --- | --- | --- |
| `ape` | `.testFunctions` | No — `library(ape)` at `inst/shiny/ui.R:23`, but zero calls to `rtree`/`nj`/any `ape` function |
| `cluster` | `.testFunctions` | No — `library(cluster)` at `ui.R:21`, zero calls to `clara`/`pam`/`agnes`/`daisy` |
| `ggtree` | `.testFunctions` | No — `library(ggtree)` at `ui.R:22`, zero calls to `ggtree()` |
| `shinycssloaders` | `.testFunctions` | **Yes** — 4 real `withSpinner(` calls in `inst/shiny/` |

So `ape`, `cluster`, and `ggtree` appear to be **fully removable** — attached but never
called, in either the console API or the GUI. `shinycssloaders` is genuinely needed, but only
by the GUI (see Finding 2).

**Verification required before acting:** confirm no bare (unqualified) calls into these
packages exist in `inst/shiny/`. The greps above covered the obvious entry points
(`ggtree(`, `rtree(`, `nj(`, `clara(`, `pam(`, `agnes(`, `daisy(`) and found none, but
`library()`-attached packages can be called by any exported name, so a definitive answer
needs `R CMD check` or `codetools::checkUsagePackage()` with the package installed.

## Finding 2 (High) — GUI-only dependencies sit in `Imports`, inconsistently

The Shiny GUI under `inst/shiny/` (86 files) is an **optional** interface — the package is
fully usable from the console without ever calling `singleCellTK()`. Its dependencies are
currently split with no discernible rule:

**Already in `Suggests`** (correct): `shinythemes`, `shinyBS`, `shinyjqui`, `shinyWidgets`,
`shinyFiles`.

**In `Imports` despite being reached only from `inst/shiny/`:**

| Package | `R/` call sites | `inst/shiny/` call sites |
| --- | --- | --- |
| `shinyjs` | 1 (the dead stub) | 258 |
| `DT` | 1 (the dead stub) | 64 |
| `colourpicker` | 1 (the dead stub) | 14 |
| `shinyalert` | 1 (the dead stub) | 14 |
| `shinycssloaders` | 1 (the dead stub) | 4 |

Once the dead stub is removed, all five have **zero** references in `R/` and belong in
`Suggests` alongside the other five shiny packages, gated at the `singleCellTK()` entry point
with `requireNamespace()`. This alone removes five hard dependencies and makes the shiny
split internally consistent for the first time.

## Finding 3 (High) — `inst/shiny/ui.R` installs packages into the user's library

`inst/shiny/ui.R:1-9`:

```r
requiredPackages <- c("shinyjqui", "shinyWidgets", "shinythemes", "shinyFiles",
                      "shinyBS", "shinybusy", "tidyverse")
if(!all(requiredPackages %in% installed.packages())){
  missingPackages <- requiredPackages[which(requiredPackages %in% installed.packages() == FALSE)]
  install.packages(missingPackages)
}
```

Three problems, in descending order of seriousness:

1. **It writes to the user's library without consent.** Launching the GUI can silently
   install seven packages, including the whole of `tidyverse`. This violates CRAN/Bioconductor
   policy on non-interactive installation and would fail a Bioconductor review if it were in
   `R/` rather than hidden in `inst/`.
2. **`tidyverse` is not declared anywhere** — not in `Imports`, not in `Suggests`. It is
   attached at `ui.R:41` and pulled in by this installer. `tidyverse` is a meta-package; this
   is a very large undeclared dependency.
3. **`installed.packages()` is slow and deprecated for this purpose**; the idiomatic check is
   `requireNamespace(p, quietly = TRUE)`.

The correct shape is: declare these in `Suggests`, and on GUI launch check with
`requireNamespace()` and **stop with an informative message** telling the user what to
install, rather than installing it for them.

Also in this file: `library(base)` at `ui.R:31` (a no-op — `base` is always attached), and
the 30-line `library()` block generally, which attaches packages the app does not use.

## Finding 4 (Medium) — single-feature heavy dependencies

Each of these backs exactly one optional analysis method and has 1-3 call sites in a single
`R/` file. Every one is a candidate for `Suggests` + `requireNamespace()` gating inside the
one function that needs it. Several are large Bioconductor packages with their own deep
dependency trees.

| Package | `R/` sites | File | Feature it backs |
| --- | --- | --- | --- |
| `zinbwave` | 1 | `runDimReduce.R` | ZINB-WaVE dimensionality reduction |
| `scMerge` | 2 | `runBatchCorrection.R` | scMerge batch correction |
| `sva` | 2 | `runBatchCorrection.R` | ComBat/ComBat-seq batch correction |
| `batchelor` | 3 | `runBatchCorrection.R` | MNN / fastMNN batch correction |
| `SingleR` | 2 | `runSingleR.R` | cell type labeling |
| `GSVA` | 2 | `runGSVA.R` | pathway scoring |
| `VAM` | 2 | `runVAM.R` | pathway scoring |
| `msigdbr` | 2 | `importGeneSets.R` | MSigDB gene set import |
| `enrichR` | 3 | `enrichRSCE.R` | enrichment (also needs network access) |
| `scds` | 3 | `scds_doubletdetection.R` | cxds/bcds/hybrid doublet detection |
| `scDblFinder` | 1 | doublet detection | doublet detection |
| `DropletUtils` | 2 | `dropletUtils_*.R` | emptyDrops / barcodeRanks |
| `TENxPBMCData` | 1 | `importExampleData.R` | example dataset only |
| `ExperimentHub` | 1 | `importExampleData.R` | example dataset only |
| `AnnotationHub` | 1 | `importExampleData.R` | example dataset only |
| `ensembldb` | 1 | `importExampleData.R` | example dataset only |
| `tximport` | 1 | `importAlevin.R` | Alevin import |
| `multtest` | 1 | `miscFunctions.R` | multiple testing |
| `metap` | 1 | — | meta-analysis p-values |
| `ROCR` | 2 | — | ROC curves |
| `Rtsne` | 1 | `runTSNE.R` | t-SNE (one of several backends) |
| `fields` | 2 | — | — |
| `KernSmooth` | 1 | `doubletFinder_doubletDetection.R` | — |
| `zellkonverter` | 22 | 3 files | AnnData interop — genuinely used, listed for contrast |

The `importExampleData.R` cluster is notable: **four hub/annotation packages
(`TENxPBMCData`, `ExperimentHub`, `AnnotationHub`, `ensembldb`) are hard dependencies purely
to provide example datasets.** Example data is the textbook case for `Suggests`.

`Rtsne` deserves separate attention: `runTSNE()` offers multiple backends, so no single
backend should be mandatory.

## Finding 5 (Medium) — declared but never referenced by name

Three entries have zero `pkg::` call sites in `R/` and are reached only through a
`NAMESPACE` directive:

| Package | How it is reached |
| --- | --- |
| `magrittr` | `importFrom(magrittr, ...)` — the `%>%` pipe. Removable: R >= 4.1 has native `\|>`, and `DESCRIPTION` already requires R >= 4.0 (bump to 4.1 costs nothing given Bioconductor 3.20 requires R >= 4.4). |
| `GSVAdata` | `NAMESPACE` import; data package for GSVA examples — belongs in `Suggests`. |
| `eds` | `NAMESPACE` import; a transitive helper for `tximport`/Alevin — should follow `tximport`. |

## Finding 6 (Low) — `Depends` is wider than it needs to be

`Depends: R (>= 4.0), SummarizedExperiment, SingleCellExperiment, DelayedArray, Biobase`

`Depends` attaches packages to the user's search path, which is justified for
`SummarizedExperiment` and `SingleCellExperiment` (249 and 133 call sites; users manipulate
SCE objects directly, so having the accessors available is genuinely convenient and is
Bioconductor-idiomatic).

`DelayedArray` and `Biobase` are a different case — they should be checked for whether users
need them attached or whether `Imports` suffices. Moving them would shrink the search path
and reduce masking conflicts without changing what installs.

Separately, `R (>= 4.0)` is stale: singleCellTK 2.18.0 targets Bioconductor 3.20, which
requires **R >= 4.4**. The declared floor is three years behind what the package actually
needs, which means the version constraint provides no real protection.

---

## Estimated reduction

Purely from the findings above, with no functionality lost:

| Move | Packages | Count |
| --- | --- | --- |
| Remove outright (unused) | `ape`, `cluster`, `ggtree` | 3 |
| Remove (language feature) | `magrittr` | 1 |
| `Imports` → `Suggests`, GUI-gated | `shinyjs`, `DT`, `colourpicker`, `shinyalert`, `shinycssloaders` | 5 |
| `Imports` → `Suggests`, example-data-gated | `TENxPBMCData`, `ExperimentHub`, `AnnotationHub`, `ensembldb`, `GSVAdata` | 5 |
| `Imports` → `Suggests`, feature-gated | `zinbwave`, `scMerge`, `sva`, `batchelor`, `SingleR`, `GSVA`, `VAM`, `msigdbr`, `enrichR`, `Rtsne`, `multtest`, `metap`, `ROCR`, `tximport`, `eds` | 15 |

**88 → roughly 60 hard dependencies**, a ~32% reduction, with the feature-gated tier being
the one that needs the most care (each gated function needs a clear error message and its
tests need `skip_if_not_installed()`).

## Caveats

- All counts are `grep`-based on `pkg::` qualification. A package called via `importFrom` and
  then used bare in `R/` would be undercounted. Cross-checking against `NAMESPACE` directives
  (the `NAMESPACE` column in the source data) partially covers this, but the definitive
  answer needs `R CMD check` with the package installed.
- Removing `.testFunctions()` will surface the *"Namespaces in Imports field not imported
  from"* NOTE for every package this audit lists. That NOTE is the point — it is the
  authoritative version of this document and should be allowed to speak.
- None of these moves should be made without the gating pattern in place first, or users
  will get raw `there is no package called 'x'` errors instead of actionable messages.
