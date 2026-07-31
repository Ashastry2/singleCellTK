# Adding a New Tool to singleCellTK

This is the end-to-end recipe for adding an analysis method to the toolkit. It is derived from
[`R/runSoupX.R`](../R/runSoupX.R), which exercises every part of the contract, and
[`R/runSingleR.R`](../R/runSingleR.R), which is a simpler example of the same shape.

The rules it encodes are set out in [ADR-0001](adr/0001-sce-in-sce-out-contract.md),
[ADR-0002](adr/0002-function-naming-families.md), and
[ADR-0003](adr/0003-result-storage-and-tagging.md). Read those if you want the *why*. This
document is the *how*.

**Running example.** We will add `runMyDenoise()` — a wrapper around a hypothetical
`myDenoise` package that takes a count matrix and returns a denoised matrix of the same
dimensions, plus a per-cell noise estimate.

---

## The one-paragraph version

Create `R/runMyDenoise.R`. Write a function whose first argument is `inSCE` and which returns
`inSCE`. Validate inputs with `.selectSCEMatrix()` and `.manageCellVar()`. Put the denoised
matrix in an assay named by the user, tag it with `expSetDataTag()`, put the per-cell estimate
in `colData`, and put the parameters in `metadata(inSCE)$sctk$runMyDenoise`. Write roxygen
with `@family`, `@return`, and `@examples`. Run `devtools::document()`. Add a test asserting
the four contract properties. Add the function to `_pkgdown.yml` and a line to `NEWS.md`.

---

## Step 1 — Decide the name and the file

Per [ADR-0002](adr/0002-function-naming-families.md), the prefix is a promise:

| Prefix | Use when |
|---|---|
| `run*` | Your tool performs an analysis on an SCE. **This is almost certainly what you want.** |
| `import*` | Your tool reads external files and produces a *new* SCE |
| `plot*` | Your tool visualizes something already computed |
| `get*` | Your tool retrieves a result a `run*` function stored |
| `export*` | Your tool writes an SCE to another format |

**Name for the action, not the backend.** `runMyDenoise()` is acceptable if "MyDenoise" is
the method. But if denoising already exists in the package, do **not** add a new exported
name — add a `method = "myDenoise"` option to the existing `runDenoise()`. Look before you
add: `runNormalization()`, `runDimReduce()`, `runBatchCorrection()`, and `runCluster()` are
all multi-backend dispatchers, and extending one is usually right.

**File placement.** One file per tool or per tool family: `R/runMyDenoise.R`. If you are
adding a backend to an existing dispatcher, edit that dispatcher's file instead.

## Step 2 — Write the signature

```r
runMyDenoise <- function(inSCE,
                         useAssay = "counts",
                         sample = NULL,
                         assayName = "myDenoise",
                         strength = 0.5,
                         seed = 12345) {
```

Argument names are **not** free choice ([ADR-0002](adr/0002-function-naming-families.md)):

| Argument | Meaning | Notes |
|---|---|---|
| `inSCE` | the input object | always first, always this name |
| `useAssay` | name of the **input** assay | inputs are `use*` |
| `useReducedDim` | name of the input reducedDim | |
| `useAltExp` | name of the input altExp | |
| `sample` | a `colData` column name **or** a full-length vector | see Step 3 |
| `assayName` | name of the **output** assay | outputs are `*Name` |
| `reducedDimName` / `clusterName` | other output names | |
| `seed` | RNG seed | must go through `withr::with_seed()` |

Method-specific parameters (`strength` here) come last and keep the backend's own names, so a
user reading the backend's documentation can map them across.

If your tool offers a choice of algorithms, use a character vector default plus `match.arg()`,
as `runSoupX()` does with `adjustMethod`:

```r
                         adjustMethod = c("subtraction", "soupOnly", "multinomial"),
...
    adjustMethod <- match.arg(adjustMethod)
```

## Step 3 — Validate inputs with the helpers

**This is the step most often skipped, and it is the source of a whole class of bug in the
package today.** `R/validityFunctions.R` provides helpers that produce useful error messages.
Use them.

```r
    # Resolves and validates useAssay / useReducedDim / useAltExp, and optionally
    # returns the matrix. Errors with "Specified `useAssay` 'foo' not found."
    selected <- .selectSCEMatrix(inSCE, useAssay = useAssay, returnMatrix = TRUE)
    mat <- selected$mat

    # Accepts either a colData column name or a full-length vector, validates
    # the length, and returns the resolved vector.
    sample <- .manageCellVar(inSCE, var = sample)
    if (is.null(sample)) {
        sample <- rep("all_cells", ncol(inSCE))
    }
```

Do **not** write `assay(inSCE, useAssay)` or `colData(inSCE)[[sample]]` directly. A user who
types `"umap"` instead of `"UMAP"` should get *"Specified `useReducedDim` 'umap' not found"*,
not *"invalid subscript"*. `docs-audit/bug-candidates.md` catalogues where bypassing these
helpers has already caused exactly that.

Available helpers:

| Helper | Use for |
|---|---|
| `.selectSCEMatrix(inSCE, useAssay=, useReducedDim=, useAltExp=, returnMatrix=)` | resolving and validating the input matrix |
| `.manageCellVar(inSCE, var=, as.factor=)` | a user-supplied cell annotation (`sample`, `cluster`, `condition`) |
| `.manageFeatureVar(inSCE, var=)` | a user-supplied feature annotation |
| `.parseUseFeatureSubset(inSCE, useFeatureSubset)` | a stored HVG / feature subset |

## Step 4 — Gate an optional dependency

If `myDenoise` is not already in `DESCRIPTION`, read
[ADR-0005](adr/0005-dependency-policy.md) first. In almost all cases a new analysis backend
belongs in **`Suggests`**, not `Imports`, and is gated at the point of use:

```r
    if (!requireNamespace("myDenoise", quietly = TRUE)) {
        stop("Package 'myDenoise' is required for runMyDenoise(). ",
             "Install it with BiocManager::install('myDenoise').")
    }
```

The message must name the package **and** give the install command. Then add it to `Suggests`
in `DESCRIPTION` — not `Imports`.

Adding to `Imports` requires justifying, in the PR description, that the package cannot load
or perform a core operation without it.

## Step 5 — Handle the seed correctly

If your tool is stochastic, take a `seed` argument and route it through `withr`:

```r
    result <- withr::with_seed(seed, {
        myDenoise::denoise(mat, strength = strength)
    })
```

**Never call `set.seed()` directly** — it mutates the user's global RNG stream as a side
effect. `withr::with_seed()` restores it.

The package's record here is currently spotless: **zero bare `set.seed()` calls**, 16
`withr::with_seed()` sites, and 5 `reticulate::py_set_seed()` calls on the Python-backed paths
(which is the correct analogue there — it seeds the Python interpreter, not R's RNG). Keep it
that way.

## Step 6 — Write results back into the SCE

Per [ADR-0001](adr/0001-sce-in-sce-out-contract.md) and
[ADR-0003](adr/0003-result-storage-and-tagging.md), each result shape has one home:

```r
    # A matrix with the same dimensions as the input -> an assay, and it MUST be tagged
    expData(inSCE, assayName, tag = "transformed") <- result$denoised
    inSCE <- expSetDataTag(inSCE, "transformed", assayName)

    # A per-cell value -> colData
    colData(inSCE)$myDenoise_noise <- result$noisePerCell

    # A per-feature value -> rowData
    rowData(inSCE)$myDenoise_weight <- result$featureWeights

    # A cells x k embedding -> reducedDim
    # SingleCellExperiment::reducedDim(inSCE, reducedDimName) <- result$embedding

    # Everything else (parameters, diagnostics, model objects) -> metadata$sctk,
    # keyed by the function name
    S4Vectors::metadata(inSCE)$sctk$runMyDenoise <- list(
        useAssay    = useAssay,
        assayName   = assayName,
        strength    = strength,
        seed        = seed,
        sessionInfo = utils::sessionInfo()
    )

    return(inSCE)
}
```

**The tag is mandatory and its vocabulary is closed** ([ADR-0003](adr/0003-result-storage-and-tagging.md)).
Valid tags are exactly:

`"raw"`, `"normalized"`, `"scaled"`, `"batchCorrected"`, `"transformed"`, `"uncategorized"`

A tag describes *what kind of data the matrix holds*. **Never use the assay's own name as its
tag** — `expSetDataTag(inSCE, "myDenoise", assayName)` is wrong and carries no information.
The Shiny GUI filters assay dropdowns by tag, so an untagged or mis-tagged assay will be
offered to methods that should not receive it.

Recording `sessionInfo()` is not strictly required, but `runSoupX()` does it and it is good
practice — it makes a result reproducible from the object alone.

## Step 7 — Add a `get*` accessor if results are not in a standard slot

If your results live in `metadata(inSCE)$sctk`, users must not have to reach in by hand
([ADR-0003](adr/0003-result-storage-and-tagging.md) decision 4). For a simple case a plain
function is enough:

```r
#' @export
getMyDenoise <- function(inSCE) {
    res <- S4Vectors::metadata(inSCE)$sctk$runMyDenoise
    if (is.null(res)) {
        stop("No 'runMyDenoise' results found. Run runMyDenoise() first.")
    }
    return(res)
}
```

For per-sample results with a setter, follow the S4 pattern in `R/runSoupX.R:511-560`
(`setGeneric("getSoupX")` / `setGeneric("getSoupX<-")` / `setMethod(...)`).

## Step 8 — Write the roxygen block

```r
#' @title Denoise counts with myDenoise
#' @description A wrapper for \link[myDenoise]{denoise}. Removes technical noise
#' from a count matrix while preserving biological variation.
#' @param inSCE A \linkS4class{SingleCellExperiment} object.
#' @param useAssay A single character string specifying which assay in
#' \code{inSCE} to use. Default \code{"counts"}.
#' @param sample A single character specifying a name that can be found in
#' \code{colData(inSCE)} to directly use the cell annotation; or a character
#' vector with as many elements as cells. Default \code{NULL}.
#' @param assayName A single character string for the output denoised matrix.
#' Default \code{"myDenoise"}.
#' @param strength Numeric between 0 and 1. Denoising strength. Default \code{0.5}.
#' @param seed Random seed. Default \code{12345}.
#' @return The input \code{inSCE} object with the denoised matrix stored in
#' \code{assay(inSCE, assayName)}, a per-cell noise estimate in
#' \code{colData(inSCE)$myDenoise_noise}, and run parameters at
#' \code{getMyDenoise(inSCE)}.
#' @family run functions
#' @seealso \code{\link{getMyDenoise}}, \code{\link{plotMyDenoiseResults}}
#' @export
#' @author Your Name
#' @examples
#' data(scExample, package = "singleCellTK")
#' sce <- subsetSCECols(sce, colData = "type != 'EmptyDroplet'")
#' \dontrun{
#' sce <- runMyDenoise(sce)
#' }
```

Requirements, all of which the audit found are inconsistently met today:

- **`@return` is mandatory and must say *where* results land.** Nearly every function in this
  package returns "a SingleCellExperiment"; that is not informative. Name the slots.
  24 exported functions currently have no `@return` at all.
- **`@family` is mandatory** ([ADR-0002](adr/0002-function-naming-families.md)). It is what
  makes pkgdown group the reference index and generate cross-links. Use `run functions`,
  `plot functions`, `import functions`, `get functions`, `export functions`.
- **`@examples` must use a bundled fixture**, never the network. `data(scExample, package =
  "singleCellTK")` is the standard. Do **not** use `importExampleData()` in an example — it
  needs `ExperimentHub` and network access. Wrap slow or optional-dependency calls in
  `\dontrun{}`, but always give *some* runnable setup.
- **`@seealso`** should point across families — from `run*` to its `plot*` and `get*`
  counterparts. That is the link `@family` alone will not generate.

## Step 9 — Regenerate the documentation

```sh
Rscript -e 'devtools::document()'
```

**Never hand-edit `man/*.Rd` or `NAMESPACE`.** Both are generated. Editing them directly means
your change is silently reverted the next time anyone runs `document()`.

## Step 10 — Write the test

Add to the topic-appropriate file in `tests/testthat/` — one file per topic, not per function.

Every `run*` function's test asserts the four contract properties
([ADR-0006](adr/0006-testing-strategy.md)):

```r
test_that("runMyDenoise writes its result into the SCE", {
    skip_if_not_installed("myDenoise")

    data(scExample, package = "singleCellTK")
    sce <- subsetSCECols(sce, colData = "type != 'EmptyDroplet'")
    out <- runMyDenoise(sce, assayName = "denoised")

    expect_s4_class(out, "SingleCellExperiment")                # 1. returns an SCE
    expect_true("denoised" %in% assayNames(out))                # 2. named output present
    expect_equal(dim(out), dim(sce))                            # 3. dimensions preserved
    expect_true("denoised" %in%                                 # 4. tagged (ADR-0003)
                expTaggedData(out, showTags = FALSE))

    expect_false(any(is.na(assay(out, "denoised"))))            # no silent NA padding
})
```

`skip_if_not_installed()` is **mandatory** if you gated a `Suggests` dependency in Step 4 —
without it, the suite breaks for everyone who does not have your backend.

Assert on structure and invariants, not exact numbers. For a stochastic method, asserting
exact output makes the test fail on an upstream patch release rather than on a real defect.
The `expect_false(any(is.na(...)))` line is worth more than it looks — silent `NA` padding is
a real, live defect in this package.

## Step 11 — Register the function

**`_pkgdown.yml`** — add it to the matching `reference:` section so it appears in the website
index:

```yaml
  - title: Analysis
    contents:
      - runMyDenoise
      - getMyDenoise
```

**`NEWS.md`** — add a line under the current development version:

```markdown
- Added `runMyDenoise()`, a wrapper for the myDenoise package.
```

**`DESCRIPTION`** — only if you added a dependency in Step 4, and to `Suggests` unless you
justified otherwise.

## Step 12 — Check before opening the PR

```sh
Rscript -e 'devtools::document()'      # regenerate man/ and NAMESPACE
Rscript -e 'lintr::lint("R/runMyDenoise.R")'
Rscript -e 'devtools::test(filter = "yourtopic")'
Rscript -e 'BiocCheck::BiocCheck()'    # before any release-bound PR
```

---

## Checklist

- [ ] Function name uses an established prefix; extends an existing dispatcher if one fits
- [ ] First argument is `inSCE`; returns `inSCE`
- [ ] Argument names follow the `use*` (input) / `*Name` (output) convention
- [ ] Inputs validated via `.selectSCEMatrix()` / `.manageCellVar()`, not direct indexing
- [ ] New dependency is in `Suggests` and gated with `requireNamespace()` and a helpful message
- [ ] `seed` routed through `withr::with_seed()`, never `set.seed()`
- [ ] Results written to the slot matching their shape
- [ ] Assay output tagged with `expSetDataTag()` using a **valid** tag from the closed list
- [ ] Parameters recorded in `metadata(inSCE)$sctk$<functionName>`
- [ ] `get*` accessor added if results live in `metadata`
- [ ] Roxygen has `@return` naming the slots, `@family`, `@examples` using a bundled fixture
- [ ] `devtools::document()` run; `man/` and `NAMESPACE` **not** hand-edited
- [ ] Test added with the four contract assertions and `skip_if_not_installed()` if gated
- [ ] Added to `_pkgdown.yml` and `NEWS.md`

## Common mistakes

| Mistake | Why it bites |
|---|---|
| Returning the result matrix instead of the SCE | Breaks composition; the user cannot chain the next step |
| `assay(inSCE, useAssay)` instead of `.selectSCEMatrix()` | A typo'd name produces "invalid subscript" instead of a useful message |
| Forgetting `expSetDataTag()` | The assay silently becomes `"uncategorized"` and the GUI mis-files it |
| Using the assay name as its tag | Carries no information and breaks tag-based filtering |
| `set.seed()` instead of `withr::with_seed()` | Silently mutates the user's global RNG stream |
| `1:n` instead of `seq_len(n)` | `1:0` is `c(1, 0)` — iterates backwards on an empty collection |
| Subsetting without `drop = FALSE` | A single-row result silently degrades to a vector |
| Adding to `Imports` by reflex | Every user pays the install cost for your optional backend |
| Hand-editing `NAMESPACE` | Reverted on the next `devtools::document()` |
| `@examples` using `importExampleData()` | Needs network access; fails `R CMD check` on the build machines |
