# Handoff — Step 1: Baseline Static Audit

**Status:** complete
**Next step:** Step 2 — ADR infrastructure

---

## What this step did

Measured the package before changing it. Five findings files were produced under
`docs-audit/`; **no file under `R/`, `man/`, `vignettes/`, `DESCRIPTION`, or `NAMESPACE` was
touched.** That separation was deliberate: Steps 2-4 act on these numbers, so the numbers had
to be taken from a clean tree.

Two subagents ran the reading-heavy audits (articles/README, and the bug hunt) in parallel
while the scripted analyses (roxygen parsing, dependency call-site counting) ran here.

## Deliverables

| File | Contents |
|---|---|
| `docs-audit/README.md` | Index and the top-five findings |
| `docs-audit/roxygen-coverage.md` | 251 exports scored on `@param`/`@return`/`@examples`/`@family`/`@seealso`; `NAMESPACE` drift check |
| `docs-audit/articles.md` | 31 articles + 1 vignette: nav, images, stale refs, overlap taxonomy, quality metrics |
| `docs-audit/readme-and-install.md` | Install accuracy, Python/reticulate drift, URL probe, citation, fork identity |
| `docs-audit/dependencies.md` | Call-site inventory for all 88 hard dependencies; a costed reduction path |
| `docs-audit/bug-candidates.md` | 35 unverified static defect candidates, severity-ranked |

Scripts used are in the session scratchpad (`roxaudit.R`, `depaudit.R`). They are pure
`parse()`/`read.dcf()`/`grep` and can be re-run against any commit to regenerate the numbers.
They were **not** committed — they are measurement tooling, not package code. If the follow-up
pass wants trend tracking over time, promoting them to `inst/scripts/` would be reasonable.

---

## Findings the next steps depend on

### Feeds ADR-0003 (naming families) and Step 4

**82% of exports already follow a prefix convention**, but **zero carry a `@family` tag**:

| Prefix | Count | | Prefix | Count |
|---|---|---|---|---|
| `plot*` | 69 | | `export*` | 4 |
| `run*` | 68 | | `set*` | 3 |
| `import*` | 20 | | `list*` | 3 |
| `get*` | 16 | | `sctk*` | 3 |
| `report*` | 16 | | `generate*` | 3 |
| | | | `compute*` / `find*` | 2 each |

46 exports don't fit a prefix; they are enumerated in `roxygen-coverage.md` §1. Two need a
judgment call in ADR-0003: the `exp*` assay-tagging accessor set (a real family with no verb
prefix), and `scaterCPM`/`scaterPCA`/`scaterlogNormCounts` (inconsistently cased, and named
after the backend rather than the action).

### Feeds ADR-0006 (dependency policy)

88 hard dependencies; 46 have ≤3 call sites in `R/`. A ~32% reduction to roughly 60 is
available in four tiers (remove outright / GUI-gated / example-data-gated / feature-gated),
costed in `dependencies.md`. The blocker is that `.testFunctions()` must be deleted **first**,
because it is currently suppressing the `R CMD check` NOTE that would validate every one of
these moves.

### Feeds ADR-0005 (documentation architecture)

- The "Interactive Analysis / Console Analysis" tabset convention is real and consistently
  applied in 26 of 31 articles; the 5 exceptions are legitimately single-surface. Write it
  down as a contract.
- The QC-article consolidation taxonomy is worked out in `articles.md` §4 and should be
  adopted by ADR-0005 rather than re-derived.

### Feeds ADR-0007 (testing strategy)

24 test files against 251 exports. The audit did not measure coverage (that needs `covr`,
which needs an install), so ADR-0007 should set the *policy* — what a new tool must test —
and leave the coverage numbers to the follow-up pass.

---

## Corrections made to subagent findings

Recorded because they affect how much to trust the rest:

- The articles agent reported the 207 article images as **lost** — present only in the
  git-ignored built site. Independent verification found the opposite: `docs/` is listed in
  `.gitignore` but **771 files under it are tracked anyway** (the rule was added after they
  were committed, so it is inert), and all 207 references resolve against
  `docs/articles/ui_screenshots/`. The fix is a `cp`, not a recovery. **The finding was right;
  the severity was wrong.**
- The image count is 207, not 183 — the difference is counting method.

Both subagent reports were otherwise accurate on spot-check, including the harder claims
(`runLIGER()` commented out at `R/runBatchCorrection.R:375-406`, the `anndata` gap between
`installation.Rmd:20` and `R/reticulate_setup.R:62`).

## Explicitly unverified

Carry these labels forward; do not let them harden into fact:

- **All 35 bug candidates.** Static only. Each needs a failing test before it is called a bug.
- **The `camplab.net` outage.** TLS stalls from this network while a control request to CRAN
  succeeds — consistent with either a dead host or a sandbox block. Re-verify elsewhere.
- **`@param` prose quality.** Completeness is confirmed; usefulness is not, and spot-reading
  suggests it varies.
- **The proposed README quick-start.** Symbols verified against `NAMESPACE`, signatures read
  from source, but never executed. `setTopHVG`'s formals in particular were not read.

---

## Decisions taken by the user during this step

1. **The fork stands alone.** Badges, `BugReports`, and issue links get retargeted from
   `compbiomed/singleCellTK` to `Ashastry2/singleCellTK`; the README notes the divergence.
   `CONTRIBUTING.md` describes this fork's workflow, not an upstream contribution flow.
2. **Copy the article images in** — `docs/articles/ui_screenshots/` →
   `vignettes/articles/ui_screenshots/`. `.Rbuildignore` already excludes
   `vignettes/articles/*`, so the source tarball does not grow.

Both are applied in Step 4, not here.

---

## What Step 2 should do

Create `docs/adr/` and write ADRs 0000-0007 per the approved plan. Two constraints:

- **These ADRs mostly document conventions that already exist**, rather than inventing new
  ones. ADR-0002 (SCE-in/SCE-out), ADR-0003 (naming families), and ADR-0004 (tagging) should
  be written by reading `R/runSoupX.R`, `R/sctkTagging.R`, and `R/allGenerics.R` and
  describing what is actually there. An ADR that contradicts the code is worse than no ADR.
- **ADR-0006 sets dependency policy but changes no dependency.** The moves stay in
  `next-pass.md` until there is a runtime to verify them against.

Read before writing: `R/sctkTagging.R`, `R/runSoupX.R`, `R/runSingleR.R`, `R/allGenerics.R`,
`R/validityFunctions.R`.
