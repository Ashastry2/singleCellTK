# Handoff — Step 3: Contributor and Agent Guidance

**Status:** complete
**Next step:** Step 4 — apply documentation improvements

---

## What this step did

Wrote the contributor-facing documentation. **No package source was modified** — these are all
new files.

| File | Audience | Contents |
|---|---|---|
| `docs/adding-a-new-tool.md` | Contributors adding a function | 12-step recipe derived from `R/runSoupX.R`, with a checklist and a common-mistakes table |
| `docs/architecture.md` | Anyone changing the package | Map of `R/` by family, SCE slot layout, the two interfaces, reticulate wiring, mermaid data-flow, known structural problems |
| `CONTRIBUTING.md` | Human contributors | Setup, conventions, "always wrong" list, PR checklist |
| `AGENTS.md` | AI agents | The same rules, weighted toward what agents get wrong; traps table |
| `CLAUDE.md` | Claude Code | Short pointer to `AGENTS.md` plus the seven rules that matter most |

`CLAUDE.md` is deliberately a pointer rather than a copy. Two files with the same content
drift, and the drift is invisible until someone follows the stale one.

## Verification performed

The Step 2 handoff required walking the recipe against `R/runSoupX.R` to confirm every claimed
step matches the real file. Done, with results:

| Claim | Verified |
|---|---|
| First argument is `inSCE` | ✅ `R/runSoupX.R:88` |
| Input annotation via `.manageCellVar()` | ✅ `:114`, `:681` |
| Assay written via `expData(inSCE, assayName, tag = ...)` | ✅ `:288` |
| Tagged with `expSetDataTag()` | ✅ `:289` |
| Non-matrix results to `metadata$sctk$<functionName>` | ✅ — `getSoupX<-` writes to `inSCE@metadata$sctk$runSoupX[[sampleID]]` |
| The four validity helpers exist as named | ✅ `R/validityFunctions.R:21,48,89`, `R/getTopHVG.R:274` |
| `@family` present in `runSoupX.R` | ❌ **0** — consistent with the audit: no function anywhere has one. ADR-0002 introduces it as the one genuinely new requirement, and the recipe presents it that way. |

**One correction made.** The draft claimed "all 19 seed-handling sites use `withr::with_seed()`".
Actual counts: **0** bare `set.seed()`, **16** `withr::with_seed()`, and **5**
`reticulate::py_set_seed()` on the Python-backed paths — which is the correct analogue there,
since it seeds the Python interpreter rather than R's RNG. Corrected in both
`adding-a-new-tool.md` and `AGENTS.md`. The underlying point (RNG hygiene is clean; keep it
that way) held.

## Design notes

- **The recipe is built from the code, not the ADRs.** Every code sample is either lifted from
  `runSoupX.R`/`runSingleR.R` or written to match their shape. The running example
  (`runMyDenoise`) is fictional so it can be shown end to end without pretending an existing
  function does something it does not.
- **Step 1 of the recipe tells contributors *not* to add a function** when an existing
  multi-backend dispatcher (`runNormalization`, `runDimReduce`, `runBatchCorrection`,
  `runCluster`) should gain a `method =` option instead. Given 251 exports, restraint is the
  more valuable guidance.
- **The "common mistakes" table is drawn from real defects** in
  `docs-audit/bug-candidates.md`, not from generic R advice. `1:n`, missing `drop = FALSE`,
  and untagged assays are each live in this codebase.
- **`AGENTS.md` leads with the generated-files rule** because `NAMESPACE` looks like a config
  file, is not one, and is the most common agent error in R packages.

---

## What Step 4 should do

Apply the low-risk fixes the audit marked "apply now". Static-only still holds: `roxygen2` is
available, the full dependency tree is not.

**Documentation content:**

1. **Add `@family` tags to the 205 prefix-conforming exports**, plus the two hand-named
   families in ADR-0002 (`assay tagging`, `SCE manipulation`). Highest-value change in the
   pass — it converts a flat 251-entry reference index into a navigable one.
2. **Add `@return` to the 24 exports lacking it**, listed in `docs-audit/roxygen-coverage.md`
   §2. Read each function's `return()` statement; name the slots results land in, not just
   "a SingleCellExperiment".
3. **Add `@seealso` for run→plot and run→get pairs** — the cross-links `@family` will not
   generate.
4. **Restructure `_pkgdown.yml`** reference sections into the ADR-0002 families; add
   `scanpy_curated_workflow` to Curated Workflows; give `vignettes/singleCellTK.Rmd` a navbar
   entry.

**Article and README fixes** (from `docs-audit/articles.md` and
`docs-audit/readme-and-install.md`, both marked apply-now):

5. `cp -R docs/articles/ui_screenshots vignettes/articles/ui_screenshots` — fixes all 207
   broken images. **User-approved.**
6. `matadata` → `metadata` at `differential_expression.Rmd:340`, `02_a_la_carte_workflow.Rmd:354`
7. `runLIGER()` at `batch_correction.Rmd:221` — remove or mark unavailable
8. `visualization.Rmd` link depth and legacy anchor
9. `{shell}` → `{bash}` plus `eval=FALSE` at `installation.Rmd:19,182`
10. Bioconductor 3.6 → 3.20 at `installation.Rmd:140,146`
11. Add `anndata` to the pip line at `installation.Rmd:20`
12. `library(singleCellTK)` chunks in the 6 articles lacking one
13. Qualify the unqualified `enrichR` calls at `enrichR.Rmd:188,189,192`
14. Retarget badges and `BugReports` to `Ashastry2/singleCellTK`; add a fork note.
    **User-approved: the fork stands alone.**
15. Add `inst/CITATION` with both papers

**Then:**

16. `Rscript -e 'devtools::document()'` and inspect `git diff man/ NAMESPACE`

**Do not** in this pass: fix any of the 35 bug candidates, move any dependency, delete
`.testFunctions()`, add the README quick-start (unverified), or consolidate articles. All need
a runtime.

**Verification for Step 4:**

- `roxygen2::roxygenise()` succeeds; `git diff man/ NAMESPACE` shows only intended changes
- `lintr` count does not increase
- every image reference resolves against `vignettes/articles/`
- no `@examples` added that has not been syntax-checked with `parse()`
