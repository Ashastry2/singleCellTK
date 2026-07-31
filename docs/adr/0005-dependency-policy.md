# ADR-0005: Dependency policy

- **Status:** Accepted
- **Date:** 2026-07-31

## Context

singleCellTK declares **88 hard dependencies** — 4 in `Depends`, 84 in `Imports` — plus 19 in
`Suggests`. Every one of the 88 must install before `library(singleCellTK)` will load. The set
spans Seurat, DESeq2, celda, SoupX, GSVA, zinbwave, scMerge, batchelor, SingleR, a Shiny
application, and a Python bridge via reticulate.

This is the largest single barrier to using the package, and it is disproportionate to the
value delivered. The audit (`docs-audit/dependencies.md`) found the distribution is extremely
long-tailed: the top 20 packages account for nearly all call sites, while **46 of the 88 have
three or fewer call sites in `R/`**, and 27 have exactly one.

Three specific findings shape this ADR:

1. **A dead function is suppressing the signal.** `.testFunctions()` at
   `R/miscFunctions.R:146` is uncalled, wrapped in `if (interactive())`, and does nothing but
   reference a list of packages — manufacturing syntactic uses to silence the `R CMD check`
   NOTE *"Namespaces in Imports field not imported from"*. It converts the one automated check
   that identifies unused dependencies into silence. `ape`, `cluster`, and `ggtree` are in
   `Imports` solely because of it, with no functional use anywhere in the package.

2. **The Shiny split is arbitrary.** `shinythemes`, `shinyBS`, `shinyjqui`, `shinyWidgets`,
   and `shinyFiles` are correctly in `Suggests`. But `shinyjs` (258 GUI call sites), `DT` (64),
   `colourpicker` (14), `shinyalert` (14), and `shinycssloaders` (4) are in `Imports` despite
   being reached **only** from `inst/shiny/` — an interface that is entirely optional.

3. **`inst/shiny/ui.R:1-9` calls `install.packages()`** on GUI launch, silently installing
   seven packages into the user's library — including all of `tidyverse`, which is declared
   nowhere in `DESCRIPTION`.

Bioconductor guidance is that `Imports` is for what the package cannot function without.
Nothing in the current arrangement reflects that test.

## Decision

**1. `Imports` means "the package cannot load or perform a core operation without this."**
Everything else goes in `Suggests`, gated at the point of use. Apply this test:

| Question | Placement |
|---|---|
| Needed to construct, validate, or manipulate the SCE? | `Imports` |
| Needed by one analysis method among several alternatives? | `Suggests`, gated |
| Needed only by the Shiny GUI? | `Suggests`, gated at `singleCellTK()` |
| Needed only to fetch example data? | `Suggests`, gated |
| Needed only by tests, vignettes, or reports? | `Suggests` |
| Provides a language feature R now has natively? | Remove |

**2. Optional dependencies are gated with `requireNamespace()` and a message that tells the
user what to do:**

```r
if (!requireNamespace("scMerge", quietly = TRUE)) {
    stop("Package 'scMerge' is required for method = 'scMerge'. ",
         "Install it with BiocManager::install('scMerge').")
}
```

The message must name the package **and** the install command. Silent failure, or a raw
`there is no package called 'x'`, is not acceptable — it is strictly worse for the user than a
hard dependency.

**3. Adding a new `Imports` entry requires justification in the PR description.** Adding one
that fails the test in decision 1 requires superseding this ADR. There is no barrier to adding
a `Suggests` entry with proper gating.

**4. `.testFunctions()` will be deleted.** It must go *first*, before any dependency is moved,
because the `R CMD check` NOTE it suppresses is the authoritative version of the audit — it
knows about bare (unqualified) uses that `grep` cannot see. Deleting it will surface a NOTE
naming every unused dependency. **That NOTE is the point.** It is a tool, not a defect, and it
must not be re-suppressed by any means.

**5. The GUI must not install packages.** `inst/shiny/ui.R` checks with `requireNamespace()`
and stops with a message listing what to install. It never calls `install.packages()`.
`tidyverse` gets declared or — better — replaced by the specific packages actually used.

**6. Declared minimum versions must be true.** `DESCRIPTION` says `R (>= 4.0)` while
Bioconductor 3.20 requires R >= 4.4. A floor three years below the real one provides no
protection and misleads users into a failing install.

## Scope of the reduction

Costed in `docs-audit/dependencies.md`, in four tiers:

| Move | Packages | Count |
|---|---|---|
| Remove — genuinely unused | `ape`, `cluster`, `ggtree` | 3 |
| Remove — native language feature (`\|>` for `%>%`) | `magrittr` | 1 |
| → `Suggests`, GUI-gated | `shinyjs`, `DT`, `colourpicker`, `shinyalert`, `shinycssloaders` | 5 |
| → `Suggests`, example-data-gated | `TENxPBMCData`, `ExperimentHub`, `AnnotationHub`, `ensembldb`, `GSVAdata` | 5 |
| → `Suggests`, feature-gated | `zinbwave`, `scMerge`, `sva`, `batchelor`, `SingleR`, `GSVA`, `VAM`, `msigdbr`, `enrichR`, `Rtsne`, `multtest`, `metap`, `ROCR`, `tximport`, `eds` | 15 |

**88 → roughly 60**, about a 32% reduction, with no functionality removed.

**This ADR authorizes none of these moves.** It sets the policy. Each move needs the gate in
place, an informative error message, `skip_if_not_installed()` in the affected tests, and a
passing `R CMD check` — all of which require a working installation. The moves are queued in
`docs-audit/next-pass.md`.

## Consequences

**Easier:** A much faster install for the majority of users who never touch scMerge, zinbwave,
or the GUI. CI gets meaningfully cheaper. Adding a new backend stops being a decision about
imposing a dependency on everyone. The Bioconductor build system gets a smaller graph to
resolve.

**Harder:** Every gated function needs a runtime check, an error message, and a test that
skips cleanly — real work, repeated 25 times. Users who *do* want a gated feature now hit an
error where previously it just worked, so the message quality is load-bearing. Test suites get
more conditional and harder to reason about. And deleting `.testFunctions()` will make
`R CMD check` noisier before it makes it quieter, which takes discipline to sit with.

**Neutral:** `Depends` keeps `SummarizedExperiment` and `SingleCellExperiment` — users
manipulate SCE objects directly and having the accessors attached is Bioconductor-idiomatic.
`DelayedArray` and `Biobase` are open questions for the follow-up pass.

## References

- `docs-audit/dependencies.md` — full call-site inventory and the evidence for each tier
- `R/miscFunctions.R:146` — `.testFunctions()`
- `inst/shiny/ui.R:1-9` — the runtime installer
- [Bioconductor package guidelines](https://contributions.bioconductor.org/description.html)
