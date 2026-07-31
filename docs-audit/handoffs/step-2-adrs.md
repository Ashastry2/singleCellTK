# Handoff — Step 2: ADR Infrastructure

**Status:** complete
**Next step:** Step 3 — contributor and agent guidance

---

## What this step did

Created `docs/adr/` and wrote seven records. **No package source was modified** — ADRs
describe, they do not change code.

| # | Title | What it pins down |
|---|---|---|
| 0000 | Record architecture decisions | The format, numbering, and supersession rule |
| 0001 | SingleCellExperiment in, SingleCellExperiment out | `inSCE` first, results added to the same object, input selection via the validity helpers |
| 0002 | Function naming families | The `run*`/`plot*`/`import*`/`get*` prefixes, the `use*`/`*Name` argument split, mandatory `@family` |
| 0003 | Result storage and assay tagging | Which slot each result shape goes in; a **closed** six-value tag vocabulary |
| 0004 | Documentation architecture | Roxygen vs vignette vs article vs README; the article taxonomy |
| 0005 | Dependency policy | The `Imports` test, the `requireNamespace()` gate, the 88 → ~60 path |
| 0006 | Testing strategy | The four contract assertions every `run*` test must make |

Numbering differs slightly from the approved plan: the plan had 0000 and 0001 both covering
the ADR process. They were merged into 0000 and everything shifted down by one, so the set is
0000-0006 rather than 0000-0007.

## The approach these were written with

Each ADR was written **after reading the code it describes**, not from the plan. This mattered
— several assumptions in the plan turned out to be wrong or incomplete, and the ADRs reflect
what is actually there:

- **`R/validityFunctions.R` is the keystone file**, and the plan did not mention it. It holds
  `.selectSCEMatrix()` (18 call sites) and `.manageCellVar()` (36 call sites) — helpers that
  exist precisely to validate user-supplied assay and annotation names. ADR-0001 makes using
  them mandatory, because the audit's "unhelpful error message" bug candidates
  (`plotDimRed.R:26`, `plotBatchVariance.R:176`, `getBiomarker.R:30`) are all cases of
  bypassing them. The contract and the bug list turn out to be the same finding.
- **The assay-tag vocabulary has drifted**, which the plan did not anticipate. Correct
  type-tags (`"raw"`, `"normalized"`, `"scaled"`, `"batchCorrected"`) sit alongside four
  entries that are assay *names* (`"counts"` ×3, `"decontXcounts"` ×1) and therefore carry no
  information and break the GUI's tag-based filtering. ADR-0003 closes the vocabulary.
- **The plan expected `runSoupX.R` or `runSingleR.R` to be the reference implementation.**
  `runSoupX.R` is the right choice — it exercises every part of the contract (assay write,
  colData, rowData, reducedDim, `metadata$sctk`, tagging, per-sample handling, and a `get*`
  accessor). Step 3's recipe should be derived from it.

## Deliberate scope limits

- **ADR-0005 authorizes no dependency change.** It sets policy; the 25 moves stay in
  `next-pass.md` until there is a runtime to verify them. The ADR is explicit that
  `.testFunctions()` must be deleted *first*, and that the resulting `R CMD check` NOTE is a
  tool, not a defect to re-suppress.
- **ADR-0006 sets no coverage target.** Coverage was never measured (needs `covr`, needs an
  install), and picking a number without measuring would be arbitrary.
- **ADR-0002 does not rename `scaterCPM`/`scaterPCA`/`scaterlogNormCounts`** despite their
  violating the "name for the action, not the backend" rule. They are exported; renaming needs
  a deprecation cycle.

Each ADR names its known deviations explicitly rather than pretending the codebase already
conforms. That is deliberate: an ADR that overstates compliance is worse than none, because
the next contributor trusts it.

---

## What Step 3 should do

Write the contributor and agent guidance, grounded in ADRs 0001-0003:

1. **`docs/adding-a-new-tool.md`** — the centerpiece. Derive it from `R/runSoupX.R` by walking
   the real code, not from the ADRs in the abstract. It must cover: file placement, the roxygen
   block (including `@family` per ADR-0002), `.selectSCEMatrix()`/`.manageCellVar()` for input
   validation, writing results to the right slot, tagging via `expSetDataTag()` with a valid
   tag, the `get*` accessor, `requireNamespace()` gating if a new dependency is involved,
   `devtools::document()`, the test file with the four ADR-0006 assertions, the `_pkgdown.yml`
   entry, and a `NEWS.md` line. Include an annotated skeleton that compiles.
2. **`docs/architecture.md`** — a map of `R/` by family, the SCE data-flow, where `inst/shiny/`
   sits relative to the console API, and how reticulate wires the Python tools.
3. **`CONTRIBUTING.md`** — dev setup, branch and commit conventions, roxygen regeneration,
   running tests, the PR checklist. Per the user's decision, this describes **the
   `Ashastry2` fork's own workflow**, not upstream contribution to `compbiomed`.
4. **`AGENTS.md`** + a `CLAUDE.md` pointer — agent-specific rules. At minimum: never hand-edit
   `man/*.Rd` or `NAMESPACE` (both roxygen-generated); no new `Imports` without ADR-0005
   justification; use the validity helpers; tag every assay written; add a test with every
   exported function; and append every prompt to `prompts.md`.

**Verification for Step 3:** walk the recipe end-to-end against `R/runSoupX.R` and confirm
every stated step matches the real file. A recipe that does not match the reference
implementation it claims to be derived from is worse than no recipe.

**Constraint that still holds:** static only. No install, no `R CMD check`, no `devtools::test()`.
`roxygen2` is available and may be used in Step 4 to regenerate `man/`.
