# Documentation and Code Audit

A static audit of singleCellTK 2.18.0, performed on the `agentic_ai_workshop` branch at
commit `6723890f`. Everything here is **findings, not changes** — the audit was deliberately
run before any edits so the measurements are untainted by them.

**Method constraint, applied throughout:** no package installation, no `R CMD check`, no
`devtools::test()`, nothing loaded. Every finding comes from reading source, parsing it
syntactically, or `grep`. Where a claim could not be established statically it is labelled
**unverified** rather than asserted.

## Contents

| File | What it covers |
|---|---|
| [`roxygen-coverage.md`](roxygen-coverage.md) | Per-export documentation matrix: `@param`/`@return`/`@examples`/`@family`, and `NAMESPACE` ↔ `R/` drift |
| [`articles.md`](articles.md) | The 31 pkgdown articles + 1 vignette: navigation, broken images, stale references, overlap, quality |
| [`readme-and-install.md`](readme-and-install.md) | `README.md` and `installation.Rmd`: install accuracy, the Python/reticulate path, URLs, citation, fork identity |
| [`dependencies.md`](dependencies.md) | Call-site inventory for all 88 hard dependencies, and where they can be reduced |
| [`bug-candidates.md`](bug-candidates.md) | 35 unverified static defect candidates with concrete failure scenarios |
| [`handoffs/`](handoffs/) | Step-by-step handoff documents recording what each stage did and what the next one should do |

## The five findings that matter most

1. **207 broken images** — every image reference in every article fails in a clean pkgdown
   build. Recoverable: all 207 resolve against the tracked `docs/articles/ui_screenshots/`.
   ([articles.md](articles.md) §2)
2. **251 exports, zero `@family` tags**, and **12 exports in no `_pkgdown.yml` reference
   section at all** — the latter fails a pkgdown build. 82% of exports already follow a prefix
   convention, so the grouping was mechanical to add.
   ([roxygen-coverage.md](roxygen-coverage.md) §1)
   *Corrected: an earlier version of this file called the reference index "a flat alphabetical
   list of 251 entries". It is not — `_pkgdown.yml` already defines 21 topical sections. See
   the correction note in `roxygen-coverage.md`.*
3. **A dead function pins four dependencies.** `.testFunctions()` at `R/miscFunctions.R:146`
   is uncalled and exists only to suppress the `R CMD check` unused-import NOTE — silencing
   the exact signal that identifies unused dependencies. ([dependencies.md](dependencies.md) §1)
4. **`plotSCEHeatmap(scale = TRUE)`, the default, scales the wrong margin** — z-scoring per
   cell while documenting per row. It does not error; it draws a wrong picture.
   ([bug-candidates.md](bug-candidates.md) §2)
5. **`inst/shiny/ui.R:1-9` runs `install.packages()`** on GUI launch, writing to the user's
   library without consent, including undeclared `tidyverse`.
   ([dependencies.md](dependencies.md) §3)

## What the audit found that was *better* than expected

Worth stating, because it changes the priorities: the roxygen baseline is strong. Zero
exported functions lack a documentation block, zero parameters are undocumented, zero
orphaned `@param` tags, and `NAMESPACE` agrees with the roxygen `@export` tags in both
directions. Article navigation has zero orphans and zero phantoms. The `R/` source is already
modernized against the classic R hazards — one `1:n`, one (safe) `sapply()`, zero bare
`T`/`F`, clean RNG handling via `withr::with_seed` throughout.

The problems are concentrated in **discoverability** (no grouping), **the build-only surface**
(articles, which `R CMD check` never sees), and **dependency hygiene** — not in the core
documentation or code quality.

## Status of the findings

- **Applied in this pass:** the low-risk documentation fixes listed as "apply now" in each
  file. See `handoffs/` for exactly what was done.
- **Deferred:** everything requiring a runtime — all 35 bug candidates, example verification,
  article consolidation, and the dependency moves. These are ranked in
  [`next-pass.md`](next-pass.md).

Design decisions arising from this audit are recorded as ADRs in [`../docs/adr/`](../docs/adr/).
