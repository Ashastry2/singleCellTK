# ADR-0003: Result storage and assay tagging

- **Status:** Accepted (documents existing practice, and fixes a drifting vocabulary)
- **Date:** 2026-07-31

## Context

ADR-0001 says results go back into the SCE. That raises two questions it does not answer:
*where exactly*, and *how does anything later know what a given assay contains?*

An SCE accumulates assays through an analysis: `counts`, then `logcounts`, then
`decontXcounts`, then `SoupX`, then `seuratScaledData`. By name alone, nothing can tell which
of these are raw counts and which are normalized — but the distinction matters, because
handing a normalized matrix to a method that expects counts produces wrong answers silently.
The Shiny GUI has the sharper version of this problem: when it populates a dropdown of
"assays you may normalize", it must not offer an already-normalized one.

`R/sctkTagging.R` solves this with a tag registry. `expSetDataTag(inSCE, assayType, assays)`
records a `(tag, assayName)` pair in a tibble at `metadata(inSCE)$assayType`;
`expTaggedData()` reads it back, grouped by tag, with support for marking some tags
"recommended". `expData<-` is a tagging-aware replacement for `assay<-`.

The mechanism is sound. **The vocabulary has drifted.** Actual tags in use across `R/`:

| Tag | Uses | Assessment |
|---|---|---|
| `"raw"` | 6 | correct — a data *type* |
| `"normalized"` | several | correct |
| `"scaled"` | 1 | correct |
| `"batchCorrected"` | 1 | correct |
| `"counts"` | 3 | **wrong** — that is an assay name, not a type |
| `"decontXcounts"` | 1 | **wrong** — an assay name |

A tag whose value is the assay's own name carries no information. Worse, it silently breaks
the GUI's filtering: an assay tagged `"decontXcounts"` appears under its own private heading
rather than grouped with other raw-count assays.

Separately, non-matrix results (parameters, model objects, diagnostics) go to
`metadata(inSCE)$sctk`, keyed by the function that produced them —
`metadata(inSCE)$sctk$runEmptyDrops[[sampleName]]`. This convention is consistent where it is
used, but it is nowhere stated.

## Decision

**1. Any function that writes an assay must tag it**, in the same call:

```r
expData(inSCE, assayName, tag = "normalized") <- newMatrix
inSCE <- expSetDataTag(inSCE, "normalized", assayName)
```

**2. The tag vocabulary is closed.** A tag describes *what kind of data the matrix holds*, and
must be one of:

| Tag | Meaning |
|---|---|
| `"raw"` | unmodified counts, or counts corrected in count space (decontX, SoupX) |
| `"normalized"` | library-size normalized and/or log-transformed |
| `"scaled"` | centred and/or variance-scaled |
| `"batchCorrected"` | batch effects removed |
| `"transformed"` | any other transformation not covered above |
| `"uncategorized"` | the default when nothing is set; not to be chosen deliberately |

**Adding a tag to this list requires superseding this ADR.** Using an assay name as a tag is
an error.

The four existing miscategorizations (`"counts"` ×3, `"decontXcounts"` ×1) are debt tracked in
`docs-audit/next-pass.md`. Fixing them changes GUI dropdown grouping, so it needs a runtime to
verify.

**3. Non-matrix results go to `metadata(inSCE)$sctk[[functionName]]`,** keyed by the name of
the `run*` function that produced them, and by sample beneath that when the function is
per-sample:

```r
metadata(inSCE)$sctk$runEmptyDrops[[sampleName]] <- argsList
```

Each entry records the parameters it was called with. `runSoupX()` additionally stores
`utils::sessionInfo()`, which is good practice worth generalizing but is not required here.

**4. A stored result gets a `get*` accessor.** Users must not be expected to reach into
`metadata()` by hand. A `run*` function whose results are only reachable via
`metadata(inSCE)$sctk$...` is incomplete.

**5. Writes are additive.** Re-running a function with the same output name overwrites that
one entry and touches nothing else. Note the existing counter-example:
`runGSVA()` (`R/runGSVA.R:50-56`) appends to `metadata$pathwayAnalysisResultNames`
unconditionally, so re-running it duplicates the entry — a bug, not a pattern to copy.

## Consequences

**Easier:** The GUI can populate assay dropdowns correctly and safely, filtering by tag rather
than guessing from names. A user inspecting an unfamiliar object can call `expTaggedData()`
and see what it holds. Provenance for every result is in the object, so an analysis is
auditable without the script that produced it.

**Harder:** Every assay-writing function now has two obligations rather than one, and nothing
enforces the second — an untagged assay silently becomes `"uncategorized"`, which is a quiet
failure mode. The closed vocabulary will occasionally not fit a genuinely novel transformation,
and `"transformed"` is the deliberately vague escape hatch. Tags live in `metadata`, so an
operation that drops metadata loses them silently.

**Neutral:** `metadata(inSCE)$sctk` is unstructured and untyped. That is a deliberate
trade — the alternative, a formal S4 results class, would be more robust but would make every
wrapper harder to write and would not survive `SingleCellExperiment` subsetting any better.

## References

- `R/sctkTagging.R` — `expSetDataTag`, `expTaggedData`, `expData<-`, `expDeleteDataTag`
- `R/scater_logNormCounts.R:20`, `R/runBatchCorrection.R:743` — correct usage
- `R/celda_decontX.R:302` — a miscategorized tag
- `R/dropletUtils_emptyDrops.R:124` — the `metadata$sctk` convention
- ADR-0001 — the contract this implements
