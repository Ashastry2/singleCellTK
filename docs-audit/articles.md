# Vignette and Article Audit

**Method:** static. All 31 `vignettes/articles/*.Rmd` plus the one real vignette
`vignettes/singleCellTK.Rmd` were read, function references were extracted and diffed against
the 251 `export()` symbols in `NAMESPACE`, and every relative link and image path was resolved
against the filesystem. Nothing was knitted or installed.

**Context worth stating up front:** `.Rbuildignore` contains `^vignettes/articles/*`, so the
articles ship **only** via the pkgdown site — they are never in the source tarball and are
never built by `R CMD check`. That is why the defects below have survived: no automated check
in the repo ever looks at them.

---

## 1. Navigation coverage

**Result: clean.** All 31 articles have a matching `articles/<name>.html` href in
`_pkgdown.yml`. **Zero orphans, zero phantoms.**

Three real gaps around the edges:

- **`vignettes/singleCellTK.Rmd` has no navbar entry** and no `reference:` entry. This is the
  package's only true vignette (`VignetteIndexEntry{1. Introduction to singleCellTK}`) — the
  one document a user reaches via `browseVignettes("singleCellTK")`. It is a 102-line stub
  whose entire content is one paragraph, a pointer to camplab.net, and `sessionInfo()`. The
  canonical entry point to the package is effectively empty.
- **`scanpy_curated_workflow.Rmd` is missing from Documentation → "Curated Workflows"** in
  `_pkgdown.yml`, which lists only Seurat and Celda. It does appear under Tutorials, so it is
  reachable, just inconsistently filed.
- **`_pkgdown.yml` has no `articles:` section at all** — only `reference:` and `navbar:`. So
  pkgdown generates no article index; the hand-built navbar is the only structure, and it has
  to be maintained by hand forever.

## 2. Broken images — the single biggest structural defect

**207 relative image references across the articles. Zero image files in
`vignettes/articles/`.** That directory contains only `.Rmd` files plus `ieee.csl` and
`references.bib`. None of the 207 references is an `http` URL; all are relative paths like
`ui_screenshots/ui_tutorial/import_1.png`.

A clean `pkgdown::build_site()` today produces **207 broken images**, affecting essentially
every article. Worst by count: `02_a_la_carte_workflow` (21), `scanpy_curated_workflow` (19),
`heatmap` (18), `seurat_curated_workflow` (14), `import_data` (13), `celda_curated_workflow`
(12), `01_import_and_qc_tutorial` (11), `differential_expression` (10).

**The good news, verified: the images are not lost.** They are tracked in the repository under
`docs/articles/ui_screenshots/` (218 files), and **all 207 references resolve there** — a
scripted check found 207 hits and 0 misses. The fix is a copy, not a recovery effort:

```
cp -R docs/articles/ui_screenshots vignettes/articles/ui_screenshots
```

The underlying cause is a `.gitignore` inconsistency. `.gitignore:16` lists `docs`, but **771
files under `docs/` are tracked anyway** — they were committed before the ignore rule was
added, and `.gitignore` has no effect on already-tracked files. So the built pkgdown site is
in version control while the *sources* for its images are not, and the ignore rule that
appears to exclude the site is inert. `.Rbuildignore` also carries a stale `^images` rule,
suggesting the sources once lived in a root `images/` directory that has since been removed.

Separately: `exec/png/*.png` (6 files) do exist in-tree, but `cmd_qc.Rmd` references
`qc_inputShell.png`, `qc_singleInput.png`, and `qc_yamlParameters.png` — different filenames
from what is there. Those three need a manual match against `exec/png/`.

## 3. Stale function references

Method: every `identifier(` token in all 32 Rmd files plus every `` `fn()` `` in prose, diffed
against `NAMESPACE`.

### Genuinely broken

| Reference | Location | Evidence |
|---|---|---|
| `runLIGER()` | `batch_correction.Rmd:221` (methods table) | The entire function is **commented out** in `R/runBatchCorrection.R:375-406`. It is not in `NAMESPACE`. Documented as an available batch-correction method but uncallable. |
| `matadata(sce)` | `differential_expression.Rmd:340` (inside a fenced chunk), `02_a_la_carte_workflow.Rmd:354` (prose) | Typo for `metadata()`. |

That is the complete list — two defects across 32 documents. **All argument-name spot-checks
passed**, verified against the source: `runScranSNN` (`R/runCluster.R:80`),
`runFeatureSelection` (`R/runFeatureSelection.R:28`), `getTopHVG` (`R/getTopHVG.R:67`),
`importGeneSetsFromMSigDB` (`R/importGeneSets.R:361`), `runNormalization`
(`R/runNormalization.R:49`), `runDimReduce` (`R/runDimReduce.R:47`).

### Unqualified third-party calls (not bugs, but a readability defect)

These are real functions from other packages, called without `pkg::` or a visible
`library()`, so a reader copying the chunk gets "could not find function":

- **celda** — `plotGridSearchPerplexity`, `plotRPC`, `subsetCeldaList`, `plotDimReduceCluster`,
  `plotDimReduceModule`, `recursiveSplitCell`/`Module`, `celdaUmap`, `celdaTsne`,
  `moduleHeatmap`, `celdaProbabilityMap`, `celdaModules` in `celda_curated_workflow.Rmd`.
  `library(celda)` *is* present at line 242 — but the first celda call is at line 254 and
  **every chunk in that file is `eval=FALSE`** (11 of 11), so nothing is ever verified.
- **enrichR** — `listEnrichrSites`, `setEnrichrSite`, `listEnrichrDbs` are used **unqualified**
  at `enrichR.Rmd:188,189,192` while the *same functions* are used as `enrichR::` at
  `:144,145,148`. Straightforwardly inconsistent; the unqualified block errors without
  `library(enrichR)`.
- Also unqualified but lower-risk: scater `calculateUMAP`, scran `quickCluster`/`buildSNNGraph`,
  igraph `cluster_*`, reticulate `py_config`/`use_python`, cowplot `plot_grid`, Seurat
  `CreateDimReducObject`, DropletUtils `read10xCounts`.

## 4. The QC "duplication" hypothesis — one-third right

The six suspected-duplicate articles are **not six duplicates**:

| Article | Lines | Real scope | Audience |
|---|---|---|---|
| `01_import_and_qc_tutorial.Rmd` | 287 | Narrative PBMC3K walkthrough: import → `runCellQC` → filter. 1 evaluated chunk, 11 images, tabsets for both UI and console. | Beginner, both surfaces |
| `02_a_la_carte_workflow.Rmd` | 649 | **Not QC at all** — normalize → HVG → dimred → embed → cluster → markers → DE → labeling → abundance → pathway. | Beginner, downstream |
| `cmd_qc.Rmd` | 498 | SCTK-QC **shell pipeline**: docker/singularity, YAML params, CLI flags, output layout. No `library(singleCellTK)`. Genuinely distinct. | CLI / pipeline ops |
| `ui_qc.Rmd` | 50 | Pure screenshot tour of the Shiny QC tab. **Zero code chunks, zero R.** 6 images, all broken. | Shiny GUI |
| `cnsl_cellqc.Rmd` | 660 | Deep console reference: `runCellQC` + each method + each plot + filtering. 41 chunks (16 `eval=FALSE`). **The real reference doc.** | R console, advanced |
| `cnsl_dropletqc.Rmd` | 262 | Same shape for `runDropletQC`/`runBarcodeRankDrops`/`runEmptyDrops`. 19 chunks. | R console, advanced |

**The real redundancy is a three-way overlap on the same PBMC content** between
`01_import_and_qc_tutorial` (narrative), `cnsl_cellqc` (reference), and `ui_qc` (screenshots).
`01` already contains UI tabsets that duplicate all 50 lines of `ui_qc`, and `01`'s console
half is a lossy subset of `cnsl_cellqc`. `cmd_qc` is legitimately separate — a different
execution surface entirely. `02_a_la_carte` should be reclassified out of the QC group.

**Recommended taxonomy:**

1. `tutorials/01-import-and-qc` — one narrative on-ramp, keeps both UI and console tabsets,
   absorbs `ui_qc` wholesale (delete `ui_qc.Rmd`, add a redirect).
2. `tutorials/02-a-la-carte` — unchanged, relabeled as downstream analysis, not QC.
3. `reference/qc-cell` ← `cnsl_cellqc`, `reference/qc-droplet` ← `cnsl_dropletqc` — retitled
   as references and cross-linked from the tutorial.
4. `pipelines/sctk-qc-cli` ← `cmd_qc` — untouched, its own nav group.

**Import trio, checked separately: low overlap, one naming defect.** `import_data.Rmd`
(292 ln, platform importers), `import_annotation.Rmd` (171 ln, colData/rowData manipulation),
`import_genesets.Rmd` (127 ln, GMT/MSigDB collections). The shared `import*` prefix implies a
series they are not — and `import_annotation` does not import anything. Its own title is
already "Manage Annotation of Cell and Features"; rename the file to `manage_annotation`.

## 5. Reading order, cross-linking, and quality

**A learning path exists but is barely encoded.** It lives in the navbar and in one paragraph
at `01_import_and_qc_tutorial.Rmd:27-29`, which names the 01 → {02 | Seurat | Celda} fork.
Nothing else states prerequisites.

**Cross-links: essentially clean.** Every internal relative `*.html` link resolves to a real
article across all 32 files. One defect: `visualization.Rmd` links to
`../../reference/index.html#section-visualization` — the `../../` escapes the site root from
`articles/` (correct is `../`, as used in `batch_correction.Rmd` and `cmd_qc.Rmd`), and
`#section-` is a legacy pkgdown-1 anchor format.

**Prerequisite-free articles** (no intro naming the object or state they assume, and zero
outbound cross-links): `heatmap.Rmd`, `normalization.Rmd`, `celda_curated_workflow.Rmd`.
`webApp.Rmd` (41 ln) is an FAQ stub.

**Tabset convention:** 26 of 31 articles use the "Interactive Analysis / Console Analysis"
tabset pattern. The 5 that do not — `cmd_qc`, `cnsl_cellqc`, `cnsl_dropletqc`, `webApp`,
`singleCellTK.Rmd` — are all legitimately single-surface. This is a real and consistent
convention that should be written down (it is, in ADR-0005).

**Measured quality issues:**

- `library(singleCellTK)` **missing** in 6 files: `cmd_qc.Rmd`, `export_data.Rmd`,
  `import_genesets.Rmd`, `ui_qc.Rmd`, `webApp.Rmd`, `vignettes/singleCellTK.Rmd`.
- **Zero executable chunks** in `celda_curated_workflow.Rmd`, `installation.Rmd`, `ui_qc.Rmd`
  — so their code is never validated by anything.
- `installation.Rmd:19` and `:182` use a ```` ```{shell} ```` chunk. **`shell` is not a valid
  knitr engine** (`bash`/`sh` are), and `:182` — a `git clone` — has no `eval=FALSE`, so
  knitr would attempt to run it at build time.

**Clean results worth recording:** zero TODO/FIXME/XXX markers across all 32 files, and zero
hardcoded local paths (`/Users`, `/home`, `C:`, `~/`).

---

## Prioritized fixes

| # | Fix | Risk |
|---|---|---|
| 1 | Copy `docs/articles/ui_screenshots/` → `vignettes/articles/ui_screenshots/`, fixing all 207 broken images | **low — apply now** |
| 2 | Remove or mark-unavailable `runLIGER()` at `batch_correction.Rmd:221` | **low — apply now** |
| 3 | Fix `matadata` → `metadata` at `differential_expression.Rmd:340`, `02_a_la_carte_workflow.Rmd:354` | **low — apply now** |
| 4 | Fix `visualization.Rmd` link depth and anchor | **low — apply now** |
| 5 | `{shell}` → `{bash}` and add `eval=FALSE` at `installation.Rmd:19,182` | **low — apply now** |
| 6 | Add `library(singleCellTK)` setup chunks to the 6 articles lacking one | **low — apply now** |
| 7 | Add `scanpy_curated_workflow` to Curated Workflows; give `vignettes/singleCellTK.Rmd` a navbar home | **low — apply now** |
| 8 | Qualify the unqualified `enrichR` calls at `enrichR.Rmd:188,189,192` | **low — apply now** |
| 9 | Match `cmd_qc.Rmd`'s three image names against `exec/png/` | low — needs a manual eyeball |
| 10 | Execute the QC-taxonomy consolidation; un-`eval=FALSE` the celda/scanpy workflows | **needs runtime — defer** |
| 11 | Rewrite `vignettes/singleCellTK.Rmd` from a stub into a real introduction with a runnable quick-start | **needs runtime — defer** |
| 12 | Add an `articles:` section to `_pkgdown.yml` so the index is generated, not hand-maintained | low, but depends on #10's taxonomy — **defer** |
