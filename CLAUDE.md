# CLAUDE.md

Guidance for Claude Code working in this repository.

**The instructions live in [`AGENTS.md`](AGENTS.md).** Read it before your first edit. This
file exists so that Claude Code discovers them automatically; keeping one source avoids the
two drifting apart.

## The short version

- **Never edit `man/*.Rd` or `NAMESPACE`** — both are generated. Edit the roxygen block in
  `R/`, then run `Rscript -e 'devtools::document()'`.
- **Never add to `Imports`** without explicit sign-off. New backends go in `Suggests`, gated
  with `requireNamespace()`.
- **Never call `install.packages()`** anywhere.
- **Analysis functions take `inSCE` first and return it.** Validate inputs with
  `.selectSCEMatrix()` / `.manageCellVar()` from `R/validityFunctions.R`.
- **Tag every assay you write** with `expSetDataTag()`, using the closed vocabulary in
  [ADR-0003](docs/adr/0003-result-storage-and-tagging.md).
- **Append every prompt verbatim to [`prompts.md`](prompts.md).**
- **The package may not be installed here.** If you cannot run the tests, say so rather than
  describing untested code as verified.

## Orientation

| Document | Purpose |
|---|---|
| [`AGENTS.md`](AGENTS.md) | Full agent instructions |
| [`docs/architecture.md`](docs/architecture.md) | How the package fits together |
| [`docs/adding-a-new-tool.md`](docs/adding-a-new-tool.md) | Step-by-step recipe for a new function |
| [`docs/adr/`](docs/adr/) | Why the conventions exist |
| [`docs-audit/`](docs-audit/) | Known problems — check here before reporting one |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The human-facing version |
