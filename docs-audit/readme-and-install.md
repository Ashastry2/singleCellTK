# README and Installation Audit

**Method:** static reading of `README.md`, `vignettes/articles/installation.Rmd`, and
`DESCRIPTION`, cross-referenced against `R/reticulate_setup.R` and `NAMESPACE`. All URLs were
probed with `curl -I -L`. Nothing was installed or executed.

---

## 1. Installation accuracy

**Correct today:**

- `README.md:33-40` — the `BiocManager::install("singleCellTK")` snippet is in the current,
  correct form.
- `installation.Rmd:8,10` — states R >= 4.0, matching `DESCRIPTION:32`. ✅
- `installation.Rmd:104,106,121,123` — `sctkPythonInstallConda()`,
  `sctkPythonInstallVirtualEnv()`, `selectSCTKConda()`, `selectSCTKVirtualEnvironment()` are
  all correctly named and all present in `NAMESPACE`. ✅

**Stale — the sharpest finding in this file:**

> `installation.Rmd:140` — *"If the version number is not 3.6 or higher, you must upgrade
> Bioconductor"*, repeated at `:146`.

Bioconductor 3.6 was released in **October 2017**. singleCellTK 2.18.0 corresponds to
Bioconductor 3.21/3.22. This threshold is roughly eight years out of date, which makes the
check worse than useless: it tells a user with a hopelessly old Bioconductor that they are
fine. Should read 3.20 or higher.

Related, from `docs-audit/dependencies.md`: `DESCRIPTION` declares `R (>= 4.0)` while
Bioconductor 3.20 requires **R >= 4.4**. The declared floor is three years behind what the
package actually needs. `installation.Rmd` faithfully mirrors the wrong number.

## 2. Python / reticulate path — a concrete drift

The documented pip line at `installation.Rmd:20`:

```
scipy numpy astroid six scrublet scanpy bbknn scanorama louvain leidenalg
```

What `R/reticulate_setup.R:61-62` actually installs:

```r
packages    = c("scipy", "numpy", "astroid", "six")
pipPackages = c("scrublet", "scanpy", "louvain", "leidenalg", "bbknn",
                "scanorama", "anndata")
```

**`anndata` is missing from the documented line**, and it is not optional — it is imported
unconditionally at `R/reticulate_setup.R:27`:

```r
ad <<- reticulate::import('anndata', delay_load = TRUE)
```

The same set is repeated for virtualenv at `R/reticulate_setup.R:109`. So any user who
follows the article's manual-Python instructions instead of calling
`sctkPythonInstallConda()` gets a broken `exportSCEtoAnnData()` and a broken scanpy path.
Also imported and undocumented: `scipy.sparse` (`:21`) and `pkg_resources` (`:26`, from
setuptools).

**README does not mention Python or reticulate at all.** It defers at `README.md:42` — "…how
to install Python dependencies … is available on the Installation page" — which is defensible
in principle, except that link is one of the dead ones (§4). Given that a large fraction of
the toolkit (scanpy, scrublet, bbknn, scanorama) is Python-backed, one sentence in the README
saying so would set expectations correctly.

## 3. No runnable quick-start anywhere

This is the gap with the widest impact. `README.md` contains **zero code beyond the install
snippet**. `vignettes/singleCellTK.Rmd` — the only real vignette, and therefore what
`browseVignettes("singleCellTK")` shows — contains only a paragraph, a link, and
`sessionInfo()`.

So there is no place in the entire package where a new user can see what using it looks like
without leaving for an external website.

**Proposed quick-start.** Every symbol below was verified present in `NAMESPACE` and every
signature read from the corresponding source file:

```r
library(singleCellTK)

sce <- importExampleData(dataset = "pbmc3k")                    # R/importExampleData.R:50
sce <- runCellQC(sce)                                           # R/runQC.R:51
sce <- runNormalization(sce, useAssay = "counts",
                        outAssayName = "logcounts",
                        normalizationMethod = "logNormCounts")  # R/runNormalization.R:49
sce <- runFeatureSelection(sce, useAssay = "counts",
                           method = "modelGeneVar")             # R/runFeatureSelection.R:28
sce <- setTopHVG(sce, method = "modelGeneVar", hvgNumber = 2000,
                 featureSubsetName = "hvf")
sce <- runDimReduce(sce, method = "scaterPCA", useAssay = "logcounts",
                    reducedDimName = "PCA", nComponents = 20,
                    useFeatureSubset = "hvf")                   # R/runDimReduce.R:47
sce <- runScranSNN(sce, useReducedDim = "PCA", clusterName = "cluster",
                   nComp = 10, k = 14)                          # R/runCluster.R:80
sce <- runDimReduce(sce, method = "scaterUMAP", useReducedDim = "PCA",
                    reducedDimName = "UMAP")
plotSCEDimReduceColData(sce, colorBy = "cluster",
                        reducedDimName = "UMAP")                # R/ggPlotting.R:381
```

**Status: end-to-end execution unverified — requires runtime.** Two specific caveats:
`setTopHVG` formals were not read and must be confirmed before this is published, and
`importExampleData(dataset = "pbmc3k")` needs `TENxPBMCData` plus `ExperimentHub` network
access, so it is unsuitable for a `@examples` block even though it is right for a README.

Note also the interaction with `docs-audit/bug-candidates.md`: `getTopHVG()`/`setTopHVG` sit
on the suspected `NA`-padding defect at `R/getTopHVG.R:103`. This quick-start should not be
published until that candidate is resolved, or it may ship a path that silently produces
`NA`-padded feature sets.

## 4. URL check

Probed with `curl -I -L`.

**200 OK:** the Bioconductor package page; GitHub issues and discussions; codecov; both GitHub
Actions badge URLs; `compbiomed.slack.com`; `r-pkgs.had.co.nz`; `shiny.rstudio.com/tutorial`;
`twitter.com/camplab1`.

**302 → resolves:** `https://sctk.bu.edu/` (`README.md:13`).

**No response (`000`) — every `camplab.net` URL:**

| Location | URL |
|---|---|
| `README.md:7` | the hero image, `https://camplab.net/sctk/img/interior-2.png` |
| `README.md:25-29` | all five Tutorials links |
| `README.md:42` | the Installation link |
| `DESCRIPTION:147` | the `URL:` field |
| `_pkgdown.yml` | navbar home icon |
| `vignettes/singleCellTK.Rmd:96` | the vignette's only outbound link |

**Reported as unresolved, not confirmed dead.** The diagnostic matters: TCP connects to
`107.180.50.225:443` and the TLS handshake begins, then stalls — while a control request to
`cran.r-project.org` returns 200 from the same shell. That pattern is consistent with either
the host being down *or* the sandbox blocking it. **Re-verify from an unrestricted network
before acting.**

If it is genuinely down, this is the most user-visible problem in the repository: the README's
hero image and all six documentation links route through that host, and it is the `URL:` field
Bioconductor displays. `sctk.bu.edu` resolves and may be the intended replacement.

## 5. Fork identity — decided

All three badges at `README.md:3` point at `compbiomed/singleCellTK` (branches `master` and
`devel`), as does `DESCRIPTION:148` `BugReports` and every issue link in the README.

**Decision taken for this branch: the fork stands alone.** Consequences to apply in Step 4:

- Retarget the three badges to `Ashastry2/singleCellTK` on `agentic_ai_workshop`, or remove
  them — as written they render *upstream's* CI status, which is actively misleading, since a
  green badge here says nothing about this branch.
- Retarget `DESCRIPTION:148` `BugReports` to this fork's issue tracker.
- Add a short note near the top of the README stating that this is a fork of
  `compbiomed/singleCellTK`, and what diverges.

## 6. Citation

Two papers are cited correctly at `README.md:46-52`, each attributed to the right use case:

- Hong et al., *Nat Commun* 13:1688 (2022), doi `10.1038/s41467-022-29212-9` — QC
- Wang et al., *Patterns* 4(8):100814 (2023), doi `10.1016/j.patter.2023.100814` — console/GUI

**There is no `inst/CITATION` file.** So `citation("singleCellTK")` — what a user actually
runs when writing a methods section — falls back to an auto-generated entry from `DESCRIPTION`
and surfaces **neither paper**. For a package whose authors clearly want to be cited, this is
a concrete, cheap gap to close.

---

## Prioritized fixes

| # | Fix | Risk |
|---|---|---|
| 1 | Update the stale Bioconductor 3.6 floor at `installation.Rmd:140,146` | **low — apply now** |
| 2 | Add `anndata` to the pip line at `installation.Rmd:20` | **low — apply now** |
| 3 | Add `inst/CITATION` with both papers | **low — apply now** |
| 4 | Retarget badges and `BugReports` to the fork; add a fork note to the README | **low — apply now** |
| 5 | Add one README sentence stating that several tools are Python-backed via reticulate | **low — apply now** |
| 6 | Bump `DESCRIPTION` `R (>= 4.0)` to match the real Bioconductor 3.20 floor of 4.4 | low, but a declared-compatibility change — **flag in NEWS** |
| 7 | Add the quick-start to the README | **needs runtime — defer** |
| 8 | Re-verify `camplab.net` from an unrestricted network; if dead, repoint to `sctk.bu.edu` | **defer — needs a network you trust** |
| 9 | Rewrite `vignettes/singleCellTK.Rmd` into a real introduction | **needs runtime — defer** |
