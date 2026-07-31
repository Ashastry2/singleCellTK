# Static Bug Candidates

**These are UNVERIFIED static candidates. Every entry requires runtime confirmation before
being treated as a real defect.** No code was executed, the package was not loaded, and its
dependency tree was not resolved. Nothing here has been fixed — this pass only catalogues.

Scope: the 87 files in `R/`.

**Framing matters here.** This tree is already largely modernized against the classic R
hazards. In all of `R/` there is exactly **one** `1:n` construct on a bound variable, exactly
**one** `sapply()` (and it passes `simplify = FALSE`, so it is safe), **zero** bare `T`/`F`
outside comments, and **zero** `if (class(x) == ...)` on an object — the `class == "matrix"`
hits are all comparisons of a character *argument named* `class` that has already passed
`match.arg`. The usual checklist is therefore nearly empty. The real defects cluster in three
places: **scaling and plotting semantics**, **unvalidated argument handling**, and
**NA-unsafe conditionals**.

35 candidates follow.

## Findings

| Sev | file:line | Pattern | Failure scenario |
|---|---|---|---|
| High | `R/getTopHVG.R:103` | `1:n` where n unrelated to length | `getTopHVG(sce)` on the default path (`useFeatureSubset = "hvf"`) never shrinks `hvgNumber`, so a 200-gene subset returns `topGenes[1:2000]` = 200 genes + 1800 `NA`s, which then poison `sce[hvgs, ]` downstream. |
| High | `R/getTopHVG.R:103` | `1:n`, n can be 0 | `getTopHVG(sce, useFeatureSubset = NULL, hvgNumber = 0)`, or any filter path where `nrow(metrics) == 0` (line 92 clamps `hvgNumber` to 0), evaluates `topGenes[1:0]` → `c(1,0)` → returns 2 elements (one `NA`) instead of none. |
| High | `R/plotSCEHeatmap.R:273` | Wrong margin | `@param scale` documents "z-score … on **each row**", but `base::scale()` standardizes **columns**; `plotSCEHeatmap(sce, scale = TRUE)` z-scores each *cell* across genes, producing a visually plausible but wrong heatmap. |
| High | `R/plotSCEHeatmap.R:218` | Wrong margin | `.minmax` uses `apply(mat, FUN = min_max, MARGIN = 2)` — min-max per cell, not per gene, contradicting the same doc line. |
| High | `R/plotDEAnalysis.R:101`, `:211` | Missing `drop = FALSE` | DE run on a `reducedDim` yielding exactly one significant gene: `t(expData(...))[geneToPlot,]` drops to a length-`ncells` vector, `as.matrix()` at line 105/214 turns it into an `ncells × 1` matrix (transposed), then `rownames(expres) <- replGeneName` (length 1) errors or silently mislabels. |
| High | `R/ggPlotting.R:554,1307,1933,2780` | `exists()` with `inherits = TRUE` | `exists("featureDisplay", inSCE@metadata)` searches enclosing frames after the metadata list; if any object named `featureDisplay` exists in the user's global env, the branch is taken and `inSCE@metadata$featureDisplay` returns `NULL`, so gene labels silently fall back to rownames. Also `where=` is being used positionally where `envir=` was meant. |
| High | `R/plotSCEHeatmap.R:274` vs `:17` | Doc/code literal mismatch | Doc says `"min-max"`; code tests `scale == "min_max"`. `plotSCEHeatmap(sce, scale = "min-max")` applies **no** scaling at all and then falls through every `colorScheme` branch (lines 349–370) leaving `colorScheme` `NULL`. |
| High | `R/subsetSCE.R:100` | Missing separator | `subsetSCERows(sce, rowData = "...", prependAltExpName = TRUE)` renames assays to `"subsetcounts"`, not `"subset_counts"`; any downstream `assay(altExp(sce), "counts")` lookup fails. |
| High | `R/plotDEAnalysis.R:604-608` | Unary minus on `NULL` | `plotDEGVolcano(sce, res, log2fcThreshold = NULL)` (documented as allowed by the `if (!is.null(log2fcThreshold))` guard at line 621) reaches `X = c(-log2fcThreshold, log2fcThreshold)` → "invalid argument to unary operator". Same for `fdrThreshold = NULL` at the `hlineLab` block. |
| High | `R/combineSCE.R:101` | `DataFrame` single-column drop | `.mergeRowDataSCE` on two SCEs built from bare matrices (empty `rowData`): `unionFe` has only the `rownames` column, so `newFe[allGenes,]` drops to a character vector and `combineSCE` fails with an opaque error. |
| Med | `R/combineSCE.R:51`, `:67` | Missing `drop = FALSE` | `mat[row, ]` / `mat[, col]` degrade to a vector when the union has exactly one feature/cell, breaking the subsequent `rbind`/`cbind` and dimnames. |
| Med | `R/miscFunctions.R:17` | Roxygen example uses a non-existent argument | `summarizeSCE(mouseBrainSubsetSCE, sample = NULL)` — the formal is `sampleVariableName` and there is no `...`; the example errors with "unused argument". **`R CMD check` would catch this one.** |
| Med | `R/subsetSCE.R:87`, `:177` | NA in logical subscript assignment | `subsetSCERows(sce, rowData = "x < 5")` where `rowData(sce)$x` has any `NA` → `temp` has `NA` → `final.ix[!temp] <- FALSE` → "NAs are not allowed in subscripted assignments". |
| Med | `R/subsetSCE.R:59`, `:149` | `min`/`max` on empty | `index = integer(0)` gives `min()` = `Inf` with a warning, passes validation, and silently returns a zero-row object plus two spurious warnings. |
| Med | `R/getBiomarker.R:30,50` | Unvalidated lookup + length mismatch | `getBiomarker(sce, gene = "NOTAGENE")` → `gene.ix` empty → `colnames(bio) <- c("sample", gene)` has 2 names for a 1-column frame → error. Duplicated rownames give the mirror-image failure. |
| Med | `R/getBiomarker.R:37-41` | No `match.arg`; undefined variable | `getBiomarker(sce, gene, binary = "binary")` (lower case) leaves `expression` unbound → "object 'expression' not found" instead of an argument error. |
| Med | `R/plotDimRed.R:26,28` | Unvalidated `reducedDim` / dim index | `plotDimRed(sce, useReduction = "umap")` when the name is `"UMAP"` → low-level "invalid subscript"; `xDim = 3` on a 2-column reducedDim → "subscript out of bounds". No helpful message either way. |
| Med | `R/ggPlotting.R:2777` | Inconsistent `match.arg` choices | Unlike lines 549/1304/1930, this site omits `"rownames"` from the choices, so `featureDisplay = "rownames"` — valid in the sibling plot functions — errors here. |
| Med | `R/ggPlotting.R:549,1304,1930` | `match.arg` partial matching | A `rowData` column named `feature_name_long` plus a user passing `featureDisplay = "feature"` silently partial-matches rather than erroring. |
| Med | `R/ggPlotting.R:1707` | `if()` on possibly-`NA` / length-0 | `all(unique(groupBy) == "Sample")` errors on "missing value where TRUE/FALSE needed" if any cell's sample label is `NA`; with zero cells `all(logical(0))` is `TRUE` and strip labels are wrongly blanked. |
| Med | `R/ggPlotting.R:962` | `levels()` on a character vector | `length(levels(groupBy))` is 0 for a character `groupBy`, so the ">5 sample types → truncate labels" branch never fires and long summary labels overflow the plot. |
| Med | `R/ggPlotting.R:963,969` | `if(all(x > 1))` with `NA` | A sample group whose metric is all-`NA` makes `summ$value` `NA` → `all(NA)` is `NA` → `if()` errors. |
| Med | `R/ggPlotting.R:2893` | `all(class(x) %in% ...)` instead of `inherits` | A patchwork/cowplot-wrapped plot has class `c("patchwork","gg","ggplot")` → `all(...)` is `FALSE` → the plot is routed into the `plot_grid` list branch and re-gridded. |
| Med | `R/detectCellOutlier.R:63` | Always takes the upper threshold | `detectCellOutlier(sce, type = "lower")` stores `attr(scaterRes,"thresholds")[2]`, which is `Inf` for a lower-tail test; the recorded threshold column is useless. |
| Med | `R/detectCellOutlier.R:68-71` | Partial-overlap column replacement | If only one of the two generated column names already exists in `colData`, `replaceIx` has length 1 while `outlierDF` has 2 columns → recycling/length error; and `which(... %in% ...)` returns colData order, not `outlierDF` order, so values can land in the wrong column. |
| Med | `R/runClusterSummaryMetrics.R:20-23` | Result discarded | The `if (isTRUE(scale))` block calls `runNormalization()` without assigning it — pure dead code (correctly redone at line 51). Misleading and wastes a full normalization pass. |
| Med | `R/runClusterSummaryMetrics.R:28,47` | Rownames overwritten with a possibly non-unique column | `displayName = "feature_name"` with duplicated or `NA` gene symbols makes `inSCE[featureNames, ]` silently select only the first match per symbol, so the bubble plot reports one gene's expression under a shared label. |
| Med | `R/plotBubble.R:56,60` | `data.frame()` name mangling | Cluster ids like `1`,`2` become `X1`,`X2` after `data.frame(avgExpr)`, so the bubble plot's y-axis labels no longer match the cluster names in `colData`. |
| Med | `R/scDblFinder_doubletDetection.R:94` | `if (all(sample == 1))` | `sample` derived from a `colData` column containing `NA` → `all()` returns `NA` → `if()` errors **after** the expensive scDblFinder run has already completed. |
| Med | `R/plotBatchVariance.R:176` | Unvalidated `reducedDim` name | `corrMat` naming a reducedDim that the BBKNN run did not produce yields a bare "invalid subscript" rather than a message naming the missing result. |
| Low | `R/plotBubble.R:46,52` | Wrong variable in error message | The `groupNames` validation failures both say `'featureNames' must be…`, misdirecting the user. |
| Low | `R/importMultipleSources.R:314-344`, `R/scds_doubletdetection.R:80-89,212-224,351-362` | `try(silent = TRUE)` swallowing errors | A failed import/doublet call leaves the target variable `NULL` (or unassigned) with no message; the failure surfaces much later as a `NULL` subscript error. |
| Low | `R/importOptimus.R:35-62` | `error <- try({...}, silent = TRUE)` | Same shape; the code path afterwards needs checking for whether `error` is actually inspected before use. |
| Low | `R/runGSVA.R:50-56` | Unconditional append | Re-running `runGSVA` with the same `geneSetCollectionName` appends a duplicate entry to `metadata$pathwayAnalysisResultNames` on every call. |
| Low | `R/ggPlotting.R:196` | `all(!is.null(x))` | `is.null` always returns length 1; the `all()` is a no-op that reads as a vectorized NULL check and will mislead future edits. |

### Not findings (checked and dismissed)

- `class == "matrix"` in the eight importer files — `class` is a character *formal* already
  run through `match.arg`, not `class(x)`.
- The single `sapply()` (`R/scDblFinder_doubletDetection.R:99`) passes `simplify = FALSE`.
- `R/ggPlotting.R:862` `cols = 1:dim(y)[2]` — guarded by `length(colnames(y)) > 1`.
- `R/computeZScore.R:18` division by `rowSds` — a zero-variance gene gives `0/0` = `NaN`,
  which line 19 already zeroes out.
- Every `seed` argument routes through `withr::with_seed`, which restores `.Random.seed`.
  RNG hygiene is clean throughout.

---

## The five most serious

### 1. `getTopHVG()` pads its return with `NA` — `R/getTopHVG.R:75-105`

```r
    topGenes <- character()
    if (!is.null(useFeatureSubset)) {
        topGenes <- .parseUseFeatureSubset(inSCE, useFeatureSubset, ...)
    } else {
        ...
        hvgNumber <- min(hvgNumber, nrow(metrics))          # only clamped here
        topGenes <- as.character(metrics$featureNames)[seq_len(hvgNumber)]
    }
    ...
    topGenes <- topGenes[!is.na(topGenes)]
    topGenes <- topGenes[1:hvgNumber]                        # line 103
```

Two defects in one line. On the **default** branch (`useFeatureSubset = "hvf"`) `hvgNumber`
keeps its default of 2000 while `topGenes` is however long the stored subset is, so the
function returns a vector padded with `NA`s — and the `!is.na` filter one line earlier shows
the author expected `NA`s to be gone by that point. On the other branch `hvgNumber` can be
clamped to `0`, and `1:0` is `c(1, 0)`, returning two elements from an empty selection.
`seq_len(min(hvgNumber, length(topGenes)))` is the shape this wants.

This is the highest-impact candidate in the list: `getTopHVG()` feeds feature selection for
downstream dimensionality reduction, so `NA`s here propagate into every subsequent step.

### 2. `plotSCEHeatmap()` scales the wrong margin — `R/plotSCEHeatmap.R:17, 214-218, 271-275`

```r
#' @param scale Whether to perform z-score or min-max scaling on each row. ...
  .minmax<-function(mat){
    min_max<- function(x) { new_x =  (x - min(x))/ (max(x) - min(x)); return(new_x)}
    new_mat<-as.matrix(apply(mat, FUN = min_max, MARGIN = 2))
    }
  ...
  if(isTRUE(scale)) scale <- "zscore"
  if ((scale == "zscore")) {
    assay(SCE) <- as.matrix(base::scale(assay(SCE)))
  } else if (scale ==  "min_max") {
```

Rows are genes, columns are cells. `base::scale()` centres and scales *columns*, and
`.minmax` explicitly passes `MARGIN = 2`. Since `scale = TRUE` is the **default**, the
standard heatmap is z-scored per cell rather than per gene. This does not error — it just
draws the wrong picture, which makes it the most dangerous kind of bug in an analysis
package. Separately, the documented `"min-max"` spelling never matches the `"min_max"` test,
so that option silently no-ops and leaves `colorScheme` `NULL`.

### 3. Reduced-dim DE plots break on a single gene — `R/plotDEAnalysis.R:101-107`

```r
    expres <- t(expData(inSCE[, c(cells1, cells2)], useReducedDim))[geneToPlot,]
    useMat <- useReducedDim
  }
  if(!is.matrix(expres)){ expres <- as.matrix(expres) }
  rownames(expres) <- replGeneName
```

With exactly one row selected the subscript drops to a plain vector; `as.matrix()` then
produces an `ncells × 1` matrix — transposed relative to what `MAST::FromMatrix` expects —
and the length-1 `rownames<-` assignment fails or mislabels. The parallel `useAssay` branch
is safe because `expData` returns a matrix; only the reducedDim branch is exposed.
`[geneToPlot, , drop = FALSE]` is the fix. Duplicated at line 211.

### 4. `exists()` leaks into the global environment — `R/ggPlotting.R:551-557` (×4)

```r
  }else{
    if(exists(x = "featureDisplay", inSCE@metadata)){
      featureDisplay <- inSCE@metadata$featureDisplay
    }
  }
```

The second positional argument of `exists()` is `where`, not `envir`, and `inherits` defaults
to `TRUE`. So the lookup walks past the metadata list into the calling frames and the global
environment. Any user who happens to have a variable named `featureDisplay` in their session
makes this branch fire on an SCE whose metadata has no such entry, assigning `NULL` — feature
labels then silently revert to rownames with no warning. Repeated verbatim at 1307, 1933,
2780.

### 5. `subsetSCERows()` concatenates the altExp prefix without a separator — `R/subsetSCE.R:99-102`

```r
    if(isTRUE(prependAltExpName)) {
      names(assays(temp.SCE)) <- paste0(altExpName, names(assays(temp.SCE)))
    }
    SingleCellExperiment::altExp(inSCE, altExpName) <- temp.SCE
```

With the defaults this renames `counts` to `subsetcounts`. Since `prependAltExpName` is on by
default and this is the documented way to carry a feature subset around, every downstream
`assay(altExp(sce, "subset"), "counts")` — including the pattern used by the QC vignette —
fails with "invalid subscript". The intent is clearly `paste0(altExpName, "_", ...)`.

---

## How to use this list

Do **not** apply these as a batch. Each needs, in order:

1. A failing test written against the stated scenario, with the package installed.
2. Confirmation the test fails for the stated reason (several will turn out to be guarded by
   a caller this analysis did not trace).
3. The fix, plus the test kept as a regression guard.

`getTopHVG.R:103`, `plotSCEHeatmap.R:218/273`, and `miscFunctions.R:17` are the three to start
with: the first two produce silently wrong scientific output, and the third is a documented
example that cannot run and would fail `R CMD check` today.
