# Roxygen Documentation Coverage

**Method:** static. `R/*.R` is parsed syntactically (`parse(keep.source = TRUE)` — no
evaluation, no package load), each top-level function definition is paired with the roxygen
block immediately preceding it, and the extracted tags are reconciled against `NAMESPACE`.
Script: `roxaudit.R` in the session scratchpad.

**Scope:** 416 function definitions parsed across 87 files; **251 exported functions** plus
13 `exportMethods` entries. Analysis below covers the 251 plain exported functions
(S4 `setMethod` blocks are excluded — the parser cannot resolve their formals, so any
per-parameter finding on them would be unreliable).

---

## Summary

| Check | Result |
| --- | --- |
| Exported functions with no roxygen block at all | **0** ✅ |
| Parameters in the signature but missing `@param` | **0** ✅ |
| `@param` documenting a parameter that doesn't exist | **0** ✅ |
| Exports in `NAMESPACE` with no definition in `R/` | **0** ✅ |
| `@export` in roxygen but absent from `NAMESPACE` | **0** ✅ |
| Missing `@return` | **24** (10%) |
| Missing `@examples` | **49** (20%) |
| Missing `@seealso` | **216** (86%) |
| Missing `@family` | **251** (100%) |

**The headline is that the baseline is much better than expected.** Parameter documentation
is complete — every formal argument of every exported function has a `@param`, and there are
no orphaned `@param` tags. `NAMESPACE` and the roxygen `@export` tags agree exactly in both
directions, meaning `devtools::document()` has been run consistently and `man/` is not stale.

This is unusual for a package this size and it changes the priority: there is **no
documentation emergency to fix**, only a discoverability problem to solve. With 251 exported
functions and zero `@family` tags, the pkgdown reference index is a flat alphabetical list of
251 entries. A user who knows a function's name can find its help page; a user who knows what
they want to *do* cannot find anything.

> **Caveat on `@param` completeness.** The check compares formals to `@param` names. It
> confirms every parameter is *mentioned*; it cannot confirm the prose is accurate, current,
> or useful. Spot-reading suggests quality varies considerably — several `@param` entries
> restate the argument name without adding information. That is a manual-review finding, not
> something this method can quantify.

---

## Finding 1 (High) — no `@family` tags anywhere

Zero of 251 exported functions carry a `@family` tag, so pkgdown has no grouping signal.

The naming convention, however, is already strong and consistent — 205 of 251 exports (82%)
carry a family prefix:

| Prefix | Count | Meaning |
| --- | --- | --- |
| `plot*` | 69 | visualization |
| `run*` | 68 | analysis method, SCE in / SCE out |
| `import*` | 20 | data ingestion |
| `get*` | 16 | result accessor |
| `report*` | 16 | Rmarkdown HTML report generation |
| `export*` | 4 | data egress |
| `set*` | 3 | result setter |
| `list*` | 3 | enumerate available results |
| `sctk*` | 3 | package-level utility |
| `generate*` | 3 | metadata generation |
| `compute*` | 2 | low-level computation |
| `find*` | 2 | marker detection |

The convention exists; it is just not expressed in the documentation. Adding `@family` tags
mechanically from the prefix would give pkgdown a usable structure at very low risk, and
would generate cross-links ("Other run functions: ...") on all 205 pages for free.

The 46 exports that don't follow a prefix are listed below and need a judgment call rather
than a mechanical rule:

```
calcEffectSizes    combineSCE          constructSCE        convertSCEToSeurat
convertSeuratToSCE dedupRowNames       detectCellOutlier   diffAbundanceFET
discreteColorPalette distinctColors     downSampleCells     downSampleDepth
expData            expDataNames        expDeleteDataTag    expSetDataTag
expTaggedData      featureIndex        iterateSimulations  mergeSCEColData
qcInputProcess     readSingleCellMatrix retrieveSCEIndex   sampleSummaryStats
scaterCPM          scaterPCA           scaterlogNormCounts selectSCTKConda
selectSCTKVirtualEnvironment           singleCellTK        subDiffEx
subDiffExANOVA     subDiffExttest      subsetSCECols       subsetSCERows
summarizeSCE       trimCounts          + 5 replacement functions (`foo<-`)
```

Two things stand out in that list. `scaterCPM` / `scaterPCA` / `scaterlogNormCounts` are
inconsistently cased (`scaterlogNormCounts` breaks the camelCase the other two use) and are
named after their backend package rather than their action — everything else in the package
is named for what it does. And `expData` / `expDataNames` / `expSetDataTag` /
`expTaggedData` / `expDeleteDataTag` form a coherent unnamed family (the assay-tagging
accessor set) that deserves a `@family` even though it has no verb prefix.

## Finding 2 (Medium) — 24 exported functions missing `@return`

`@return` is the tag users actually read first, and it matters more than usual here because
almost every function in this package returns *the same type* — a `SingleCellExperiment` —
but modified in a different place. Without `@return`, the user cannot tell whether
`runDESeq2()` put its results in `colData`, `metadata`, or somewhere else.

The gap clusters revealingly:

**Differential expression — the entire family (`R/runDEAnalysis.R`):**
`runDESeq2`, `runLimmaDE`, `runANOVA`, `runMAST`, `runWilcox`

**Marker detection (`R/runFindMarker.R`):** `findMarkerDiffExp`, `findMarkerTopTable`

**Result accessors — the functions whose *entire purpose* is their return value:**
`getEnrichRResult`, `getSoupX`, `getTSCANResults<-`, `listTSCANResults`,
`listTSCANTerminalNodes`, `getDiffAbundanceResults<-`, `getTSNE`, `getUMAP`, `setTopHVG`

**Embedding shortcuts:** `runQuickTSNE`, `runQuickUMAP`

**Import (`R/importCellRanger.R`, `R/importGeneSets.R`):** `importCellRangerV2`,
`importCellRangerV3`, `importGeneSetsFromMSigDB`, `importMitoGeneSet`,
`sctkListGeneSetCollections`

**Plotting:** `plotMarkerDiffExp`

That the accessor functions are the worst-documented is the sharpest finding here — a
`get*`/`list*` function with no `@return` is missing the only documentation that matters.

**Risk to fix: low.** The return value can be determined by reading the function's own
`return()` statement. No runtime needed.

## Finding 3 (Medium) — 49 exported functions missing `@examples`

Two of these are Bioconductor review issues in waiting: Bioconductor's package guidelines
expect runnable examples on exported functions, and `R CMD check` reports undocumented
examples as a NOTE.

The gap concentrates in four files:

| File | Count | Note |
| --- | --- | --- |
| `htmlReports.R` | 13 | every `report*` function — these generate HTML and are slow, so `\dontrun{}` is legitimate, but *some* example is still needed |
| `seuratFunctions.R` | 6 | `runSeuratTSNE`, `plotSeuratHeatmap`, `runSeuratIntegration`, `runSeuratFindMarkers`, `plotSeuratGenes`, `getSeuratVariableFeatures` |
| `sctkQCUtils.R` | 6 | `exportSCEToSeurat`, `generateMeta`, `generateHTANMeta`, `getSceParams`, `constructSCE`, `qcInputProcess` |
| `runDEAnalysis.R` | 5 | the whole DE family again — same functions as Finding 2 |

The DE family appearing in both Finding 2 and Finding 3 makes `R/runDEAnalysis.R` the single
highest-value file to fix: five heavily-used exported functions, none with a documented
return value or an example.

**Risk to fix: medium.** Writing an example is easy; writing one that *runs* requires knowing
the fixture (`data(scExample, package = "singleCellTK")`, used elsewhere in the package) and
verifying it executes — which needs the package installed. Examples added in this pass are
syntax-checked with `parse()` only, and any that cannot be verified should be wrapped in
`\dontrun{}` and flagged for the follow-up pass rather than asserted to work.

## Finding 4 (Low) — 86% missing `@seealso`

216 of 251. Less critical than `@family`, since well-chosen `@family` tags generate the
cross-links automatically. Worth adding manually only where the relationship crosses family
boundaries — e.g. `runUMAP()` → `plotUMAP()`, `runDESeq2()` → `plotDEGViolin()`,
`runSoupX()` → `getSoupX()`. Those run→plot and run→get pairings are the ones users actually
need and that `@family` alone will not produce.

---

## Recommended actions

| # | Action | Risk | Pass |
| --- | --- | --- | --- |
| 1 | Add `@family` tags to the 205 prefix-conforming exports; define the 12 families in `_pkgdown.yml` reference sections | Low — additive tags only | **now** |
| 2 | Add `@family` for the `exp*` assay-tagging accessor set | Low | **now** |
| 3 | Add `@return` to the 24 functions listed, reading each `return()` statement | Low | **now** |
| 4 | Add `@seealso` for run→plot and run→get pairs | Low | **now** |
| 5 | Add `@examples` to the 49, using the `scExample` fixture; `\dontrun{}` for the slow `report*` ones | Medium — needs runtime to verify | **defer** |
| 6 | Review `@param` prose quality (completeness is confirmed; usefulness is not) | Medium — manual, 251 functions | **defer** |
| 7 | Decide on `scaterlogNormCounts` casing inconsistency | Breaking change — needs deprecation cycle | **defer, needs ADR** |

Actions 1-4 are the Step 4 work. Actions 5-7 go to `next-pass.md`.
