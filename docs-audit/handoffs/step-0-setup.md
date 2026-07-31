# Handoff — Step 0: Setup

**Status:** complete
**Date:** 2026-07-31
**Next step:** Step 1 — Baseline static audit

---

## What this step did

Established the working environment for the documentation and audit effort. No package
source was modified.

### Repository

Cloned `https://github.com/Ashastry2/singleCellTK.git` into the working directory and checked
out the existing remote branch **`agentic_ai_workshop`**, which tracks `origin` and was at
`6723890f "Updated news and docs"` — identical to `master` at the time of cloning. All work in
this effort lands on that branch and is pushed there; no pull request is opened.

Other remote branches present, for reference: `master`, `devel`, `tutorial_refactor`.

### Skills

The Bioconductor agent skills from `seandavi/ai-agent-skills` were installed at pinned commit
`6117255f15afa291c3ac1a01583697b92812bfd9` into `~/.claude/skills/` (user-level, deliberately
*not* committed into this repo, so the package stays free of agent-tooling clutter). Twelve
skills are available; the ones relevant to this effort:

| Skill | Used in |
| --- | --- |
| `analyze-r-package` | Step 1 — structural profile |
| `create-package-instructions` | Step 3 — first draft of `AGENTS.md` |
| `improve-code-coverage` | Step 5 — scoping test gaps |
| `security-audit-r-package` | Step 5 — scoping |
| `update-r-news` | Step 4 — `NEWS.md` entry |
| `bioc-howto` | reference throughout |

The repo's own agent contract (`AGENTS.md` from the skills repo) and index (`SKILLS.md`) were
copied alongside as `BIOC-AGENTS-STANDARD.md` and `BIOC-SKILLS-INDEX.md`. Note that skills in
that repo are **prompts, not code** — they are read and followed, and their instructions are
adapted to whatever tools the agent has.

### Prompt log

Created `prompts.md` at the repo root containing all four session-1 prompts verbatim, plus
the clarifying question/answer pairs that shaped the scope. **This file must be appended to
for every subsequent prompt** — that rule is restated in `AGENTS.md` once Step 3 writes it.

---

## Baseline measurements

Taken at `6723890f`, for later before/after comparison:

| Metric | Value |
| --- | --- |
| Files in `R/` | 87 |
| Man pages in `man/` | 237 |
| Exported symbols in `NAMESPACE` | 264 (of 328 total directives) |
| testthat files | 24 |
| pkgdown articles (`vignettes/articles/*.Rmd`) | 31 |
| Real vignettes (`vignettes/*.Rmd`) | 1 (`singleCellTK.Rmd`) |
| Package version | 2.18.0 |
| RoxygenNote | 7.3.2 |

Ratio worth noting: **264 exports against 24 test files**, and **87 source files against 31
articles**. Both are inputs to Steps 1 and 5.

## Confirmed absences

These were verified as missing and are the reason Step 3 exists:

- `CONTRIBUTING.md` — none, at root or under `.github/`
- `AGENTS.md` / `CLAUDE.md` / `.github/instructions/` — none
- `.github/ISSUE_TEMPLATE/`, PR template — none (`.github/` holds only two workflow files,
  `BioC-check.yaml` and `R-CMD-check.yaml`)
- Any architecture overview or "how to add a tool" document — none
- Any ADR directory — none

Also noted: a legacy `.travis.yml` sits alongside the live GitHub Actions workflows.

---

## Environment

- R 4.4.1 (2024-06-14) at `/usr/local/bin/R`
- `git` available; **`gh` is not installed**, so no GitHub CLI operations are possible.
  Pushes go through Git Credential Manager (`/usr/local/share/gcm-core/git-credential-manager`)
  and the first push may prompt for interactive authentication.
- **The package is not installed and its dependency tree is not resolved.** This is
  deliberate — the first pass is static-only. Any command requiring the package to load
  (`devtools::test()`, `R CMD check`, `covr`) will fail and must not be attempted until the
  follow-up pass.
- Tools that *do* work without the dependency tree, and which Steps 1 and 4 rely on:
  `roxygen2` (parsing and regeneration), `lintr` (static linting), `tools::checkRd()`,
  and plain `parse()` for syntax-checking example code.

---

## What Step 1 should do

Produce `docs-audit/` — a set of markdown findings files, no source changes:

1. **`roxygen-coverage.md`** — for every exported function, whether `@param` covers all
   formals, and whether `@return`, `@examples`, `@seealso`, `@family` are present. Reconcile
   `NAMESPACE` exports against `man/*.Rd` to find drift in both directions.
2. **`articles.md`** — audit the 31 articles for `_pkgdown.yml` navigation coverage, stale
   function references, and overlap. The QC articles (`cmd_qc`, `ui_qc`, `cnsl_cellqc`,
   `cnsl_dropletqc`, `01_import_and_qc_tutorial`) are the obvious suspected duplication.
3. **`readme.md`** — accuracy of install instructions, including the reticulate/Python path.
4. **`dependencies.md`** — per-`Imports` call-site inventory. Record usage count and whether
   each is reachable only from `inst/shiny/`. Evidence only; no `DESCRIPTION` edits.
5. **`bug-candidates.md`** — `lintr` output plus targeted greps for R hazards, each with
   file:line and a one-line failure scenario. **Do not fix anything** — these are unverified
   without a runtime, and Step 5 ranks them for the follow-up pass.

Constraint to carry forward: no `DESCRIPTION`/`NAMESPACE`/`R/` edits in Step 1. It is a
read-only measurement step, and Steps 2–4 depend on its findings being untainted by changes
made while measuring.
