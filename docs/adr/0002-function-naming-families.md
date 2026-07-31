# ADR-0002: Function naming families

- **Status:** Accepted (documents existing practice, with one new requirement)
- **Date:** 2026-07-31

## Context

The package exports 251 functions. The audit (`docs-audit/roxygen-coverage.md`) found that
**205 of them — 82% — already follow a verb-prefix naming convention**, applied consistently
enough that it is clearly intentional:

| Prefix | Count | Role |
|---|---|---|
| `plot*` | 69 | produce a plot object |
| `run*` | 68 | run an analysis method; SCE in, SCE out (ADR-0001) |
| `import*` | 20 | read external data into an SCE |
| `get*` | 16 | retrieve a stored result |
| `report*` | 16 | render an Rmarkdown HTML report |
| `export*` | 4 | write an SCE out to another format |
| `set*` | 3 | store a value into an SCE |
| `list*` | 3 | enumerate available results |
| `sctk*` | 3 | package-level utility |
| `generate*` | 3 | generate metadata |
| `compute*`, `find*` | 2 each | low-level computation; marker detection |

The same audit found that **zero of the 251 carry a `@family` roxygen tag**. So the convention
exists in the names but is invisible to the documentation system: the pkgdown reference index
is a flat alphabetical list of 251 entries. A user who knows a function's name can find its
help page. A user who knows what they want to *do* cannot find anything.

This is the single highest-leverage documentation fix available, because the grouping does not
have to be invented — it only has to be declared.

## Decision

**1. New exported functions use one of the established prefixes.** The prefix is a promise
about behaviour:

- `run*` — performs an analysis. Follows ADR-0001 strictly: takes `inSCE`, returns `inSCE`.
- `plot*` — returns a plot object (`ggplot`, `ComplexHeatmap`). **Does not modify the SCE and
  does not draw as a side effect** — the caller decides when to print.
- `import*` — takes file paths or an external object, returns a new SCE. Does not take `inSCE`.
- `export*` — takes an SCE, writes to disk or returns a foreign object. Crosses a boundary.
- `get*` / `set*` / `list*` — accessors for results already stored by a `run*` function.
  A `get*` must have a corresponding `run*`.
- `report*` — renders an Rmarkdown template from `inst/rmarkdown/`.

A function that does not fit any of these is a signal to reconsider the design before adding a
new prefix.

**2. Every exported function carries a `@family` tag.** This is the new requirement. The
family name matches the prefix (`@family run functions`, `@family plot functions`, …), so
pkgdown generates the cross-links and the reference index groups itself.

Two families have no verb prefix and are named explicitly:

- **`@family assay tagging`** — `expData`, `expDataNames`, `expSetDataTag`, `expTaggedData`,
  `expDeleteDataTag`. A coherent set (see ADR-0003) whose names are nouns.
- **`@family SCE manipulation`** — `combineSCE`, `subsetSCECols`, `subsetSCERows`,
  `mergeSCEColData`, `dedupRowNames`, and similar structural operations.

**3. Name for the action, not the backend.** `runNormalization(method = "logNormCounts")` is
right; `scaterlogNormCounts()` is wrong. The backend belongs in a `method` argument, so that
adding a second backend does not require a new exported name.

This is a change from current practice. `scaterCPM()`, `scaterPCA()`, and
`scaterlogNormCounts()` violate it — and the third also breaks the camelCase the other two
use. They are **not renamed by this ADR**: they are exported, so renaming is a breaking change
requiring a deprecation cycle. They are documented as known deviations and tracked in
`docs-audit/next-pass.md`. New code does not add more of them.

**4. Argument names are part of the convention** and are as load-bearing as the function name:

| Argument | Meaning |
|---|---|
| `inSCE` | the input object, always first |
| `useAssay` | name of the input assay |
| `useReducedDim` | name of the input reducedDim |
| `useAltExp` | name of the input altExp |
| `useFeatureSubset` | name of a stored feature subset |
| `sample` | `colData` column, or a full-length vector, identifying samples |
| `assayName` / `reducedDimName` / `clusterName` | name of the **output** |
| `seed` | RNG seed; must be passed to `withr::with_seed()`, never `set.seed()` |

The `use*` / `*Name` split — inputs are `use*`, outputs are `*Name` — is the important part,
and it is already applied consistently.

## Consequences

**Easier:** The pkgdown reference organizes itself, and adding a function automatically files
it in the right group. Users can guess function names correctly (`runX` has a `plotX`). Code
review has a concrete rule to apply. The 205 conforming functions gain "Other run functions:
…" cross-links at no authoring cost.

**Harder:** Prefixes constrain naming, and occasionally the natural English name will not fit
— `findMarkerDiffExp()` sits awkwardly between `find*` and `run*`. The `@family` requirement
adds a line to every new function's roxygen block and needs enforcement in review, since
nothing checks it automatically. Three exported functions now knowingly violate the convention
and will keep doing so until a deprecation cycle is affordable.

**Neutral:** The 46 exports that fit no prefix (enumerated in
`docs-audit/roxygen-coverage.md` §1) are mostly legitimate — utilities, converters, and the
`singleCellTK()` GUI launcher. They get `@family` tags by hand.

## References

- `docs-audit/roxygen-coverage.md` §1 — the counts and the full list of non-conforming exports
- `_pkgdown.yml` — the reference index that these families restructure
- ADR-0001 — the behavioural contract that `run*` promises
