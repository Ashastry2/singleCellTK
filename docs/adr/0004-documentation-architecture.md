# ADR-0004: Documentation architecture

- **Status:** Accepted
- **Date:** 2026-07-31

## Context

singleCellTK has four documentation surfaces and no written rule about which is for what:

1. **Roxygen → `man/`** — 237 man pages, one per exported function.
2. **The vignette** — `vignettes/singleCellTK.Rmd`, the only true vignette, shipped in the
   tarball and reachable via `browseVignettes()`. Currently a **102-line stub**: one
   paragraph, a link to an external site, and `sessionInfo()`.
3. **pkgdown articles** — 31 files in `vignettes/articles/`, excluded from the tarball by
   `.Rbuildignore` and published only to the website.
4. **`README.md`** — the GitHub and Bioconductor landing page. No code beyond the install
   snippet.

The audit (`docs-audit/articles.md`) found the consequences of having no rule:

- **The canonical entry point is empty.** A user who does the standard thing —
  `browseVignettes("singleCellTK")` — gets the stub. Everything real is on a website.
- **207 broken images**, because articles are never built by `R CMD check` and so nothing ever
  noticed.
- **Three articles have zero executable chunks** and one (`celda_curated_workflow.Rmd`) has
  `eval=FALSE` on all 11 of its chunks, so its code has never been validated by anything.
- **Genuine overlap** between `01_import_and_qc_tutorial`, `cnsl_cellqc`, and `ui_qc`, with
  `ui_qc` (50 lines, zero code) fully contained in `01`.
- A **real and consistent convention nobody wrote down**: 26 of 31 articles use an
  "Interactive Analysis / Console Analysis" tabset to document the GUI and console paths side
  by side. The 5 exceptions are legitimately single-surface.

The root cause is structural. Articles live outside the tarball, so no automated check ever
looks at them, so defects accumulate indefinitely. That is not an argument against articles —
it is an argument for knowing which content can afford to live there.

## Decision

**1. Each surface has one job.**

| Surface | Answers | Rule |
|---|---|---|
| **Roxygen** | "What does this function do, exactly?" | Complete `@param`, `@return`, `@examples`, `@family`. The reference, not a tutorial. |
| **Vignette** (`vignettes/singleCellTK.Rmd`) | "What is this package and how do I use it?" | Must contain a **runnable end-to-end workflow** — import → QC → normalize → cluster → plot. Ships in the tarball, so `R CMD check` runs it. |
| **Articles** (`vignettes/articles/`) | "How do I do this specific task?" | Task-focused, screenshot-heavy, GUI-inclusive. Website only. |
| **README** | "Should I use this, and how do I install it?" | Pitch, install, quick-start, citation. |

**2. The vignette must become real.** A package whose only shipped documentation is a link to
an external site is a package with no documentation when that site is unreachable — and
`docs-audit/readme-and-install.md` records that every `camplab.net` URL currently fails to
respond from at least one network. The vignette is the one surface that is version-controlled
with the code, shipped with the tarball, and executed by `R CMD check`. It should carry the
canonical workflow.

**3. Article conventions, now written down:**

- Every article opens with a `library(singleCellTK)` setup chunk. Six currently lack one.
- Every article states its prerequisites — what object it assumes and which article produced
  it. Three currently have neither prerequisites nor any outbound link.
- Articles that cover both interfaces use the **"Interactive Analysis / Console Analysis"
  tabset**, matching the existing 26. Single-surface articles (the CLI pipeline, the console
  references) do not, and say so in their intro.
- Third-party functions are called **qualified** (`celda::plotRPC()`), because a reader copies
  a chunk out of context. `enrichR.Rmd` currently does this both ways in one file.
- `eval=FALSE` is a last resort — for genuinely slow, network-dependent, or GUI-only code —
  and carries a comment saying why. An article with no evaluated chunks is unverified prose.

**4. Article taxonomy.** Adopt the grouping worked out in `docs-audit/articles.md` §4:

- **Tutorials** — the narrative on-ramp. `01-import-and-qc` (absorbing `ui_qc`),
  `02-a-la-carte` (which is downstream analysis, not QC, and is currently misfiled).
- **Curated workflows** — Seurat, Celda, Scanpy. All three, not the two currently listed.
- **References** — the deep per-topic articles, including `cnsl_cellqc` and `cnsl_dropletqc`
  retitled as references.
- **Pipelines** — `cmd_qc`, the shell/Docker surface. Genuinely separate.

**5. `_pkgdown.yml` gets an `articles:` section** so the index is generated from this taxonomy
rather than hand-maintained in the navbar, which is the current arrangement and the reason
`scanpy_curated_workflow` went missing from one menu while appearing in another.

**6. Image sources live in `vignettes/articles/`, not in the built site.** The current
inversion — sources absent, built output committed — is what produced 207 broken references.

## Consequences

**Easier:** A contributor knows where to put a new document. The vignette becomes a real,
tested entry point, so `R CMD check` starts catching workflow breakage that nothing catches
today. The article taxonomy gives users a reading order rather than an alphabetical list.

**Harder:** Making the vignette runnable means it must stay runnable — it becomes a
maintenance obligation and slows `R CMD check`. Fixture choice is constrained: the vignette
cannot use `importExampleData("pbmc3k")`, which needs network access, so it must use the
bundled `scExample` data even though that is small enough to make some steps degenerate.
Enforcing the article conventions is manual; nothing checks them.

**Neutral:** Articles remain outside `R CMD check` by design — they document the GUI, need
screenshots, and would make the tarball unreasonably large. The mitigation is not to move them
but to keep the *canonical* workflow in the vignette, where it is tested, and let articles
elaborate.

## References

- `docs-audit/articles.md` — the audit, the overlap analysis, and the proposed taxonomy
- `docs-audit/readme-and-install.md` — the URL findings that motivate decision 2
- `_pkgdown.yml`, `.Rbuildignore`
