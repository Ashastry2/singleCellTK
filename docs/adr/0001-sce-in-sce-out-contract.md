# ADR-0001: SingleCellExperiment in, SingleCellExperiment out

- **Status:** Accepted (documents existing practice)
- **Date:** 2026-07-31

## Context

singleCellTK wraps a large number of third-party analysis tools — Seurat, scran, scater,
celda, SoupX, SingleR, GSVA, scDblFinder, and a set of Python tools via reticulate. Each of
those tools has its own idea of what an input is and what a result looks like: Seurat wants a
`Seurat` object, scanpy wants an `AnnData`, `scran::quickCluster()` returns a bare factor,
`SoupX::adjustCounts()` returns a matrix.

If each wrapper returned whatever its backend returned, the package would be a bag of
unrelated functions and no two steps could be chained. The value singleCellTK adds over
calling those packages directly is precisely that it makes them interoperable.

Reading the source confirms a consistent contract already in force. `runSoupX()`
(`R/runSoupX.R`) is representative: it takes `inSCE`, runs SoupX per sample, and writes the
corrected matrix, the per-cell metrics, the per-feature soup profile, the UMAP embedding, and
the full parameter record back into the *same* object, returning it. It never returns the
corrected matrix on its own — even though that is what the user asked it to compute.

Two helpers in `R/validityFunctions.R` exist to support this contract and are used widely:
`.selectSCEMatrix()` (18 call sites) resolves and validates the
`useAssay`/`useReducedDim`/`useAltExp` triple, and `.manageCellVar()` (36 call sites) accepts
either a `colData` column name or a full-length vector and validates the length.

## Decision

**Every analysis function takes a `SingleCellExperiment` as its first argument, named `inSCE`,
and returns that same object with results added. It does not return a bare result.**

Concretely:

1. **First argument is `inSCE`.** Not `sce`, not `x`, not `object`.
2. **The return value is the input object.** Results are *added*; nothing already present is
   removed or overwritten unless the user named the target explicitly.
3. **Results go in the slot that matches their shape:**
   - a matrix with the same dimensions as the input → an `assay`
   - a per-cell value → a `colData` column
   - a per-feature value → a `rowData` column
   - a cells × k embedding → a `reducedDim`
   - anything else (parameters, diagnostics, model objects) → `metadata(inSCE)$sctk`
   - a differently-dimensioned sub-object (e.g. a feature subset) → an `altExp`
4. **The user names the output.** Every function that writes takes an argument — `assayName`,
   `reducedDimName`, `clusterName` — defaulting to something descriptive, so results never
   silently collide.
5. **Input selection goes through the helpers.** Use `.selectSCEMatrix()` to resolve
   `useAssay`/`useReducedDim`/`useAltExp`, and `.manageCellVar()` /`.manageFeatureVar()` for
   any user-supplied annotation variable. **Do not index `assay(inSCE, useAssay)` or
   `colData(inSCE)[[var]]` directly** — that is what produces the unhelpful "invalid
   subscript" errors catalogued in `docs-audit/bug-candidates.md`.
6. **Conversion is explicit and separate.** Functions that genuinely produce a different type
   — `convertSCEToSeurat()`, `exportSCEtoAnnData()` — are named `convert*`/`export*` and are
   understood as boundary crossings, not analysis steps.

**Known deviations.** This contract is not currently universal, and the exceptions are not
blessed by this ADR — they are debt:

- `plotDimRed()` (`R/plotDimRed.R:26`) indexes `reducedDim()` directly instead of using
  `.selectSCEMatrix()`, producing a bare subscript error on a mistyped name.
- `plotBatchVariance()` (`R/plotBatchVariance.R:176`) has the same shape.
- `getBiomarker()` (`R/getBiomarker.R:30`) looks up a gene without validating it exists.

New code must follow the contract. Existing deviations are tracked in
`docs-audit/next-pass.md`.

## Consequences

**Easier:** Steps compose — `sce |> runCellQC() |> runNormalization() |> runDimReduce()` works
because every step has the same shape. Provenance accumulates in one object, so an analysis is
reproducible from the object alone. The Shiny GUI can be a thin layer over the console API
because there is exactly one object to pass around. A contributor adding a tool has no design
decisions to make about the interface.

**Harder:** The SCE grows monotonically through an analysis, and nothing prunes it — a
long workflow produces a large object, and there is no `dropResults()` function. Wrapping a
backend requires unpacking its native return value and mapping each piece into the right slot,
which is more work than passing the result through. And a function that *only* wants to compute
a value still has to accept and return the whole object, which is awkward for genuinely pure
computations.

**Neutral:** The contract makes `metadata(inSCE)$sctk` a catch-all. ADR-0003 constrains what
goes in there and how it is named.

## References

- `R/runSoupX.R` — the reference implementation
- `R/validityFunctions.R` — `.selectSCEMatrix()`, `.manageCellVar()`, `.manageFeatureVar()`
- `docs-audit/bug-candidates.md` — the errors caused by bypassing the helpers
- [SingleCellExperiment](https://bioconductor.org/packages/SingleCellExperiment/) documentation
