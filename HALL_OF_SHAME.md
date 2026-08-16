# Hall of shame

Mistakes made while building the scientific CI (2026-08-15/16, PR #4). Kept
because the CI exists to catch believable-but-wrong results, and the same
failure modes that produce a false map produced most of these.

Every entry is an error by the agent writing the CI, not by the package. The
package's own defects are in `NEWS.md`.

---

## 1. Everything that "passed locally" and shouldn't have

The single biggest category. Four separate times, a green local run was a
statement about this machine's package set rather than about the code.

| What was set/installed locally | What it hid |
|---|---|
| `HERE_API_KEY` | `isochrones_for_df()` never forwarded its `api_key` argument. Every routing call fell back to the env var. Tests passed here for years' worth of runs; failed instantly on CI. |
| `cyclocomp` | `.lintr.R` configures `cyclocomp_linter()`. lintr 3.4 made cyclocomp a Suggests, so without it the linter **aborts** rather than reporting. Clean here, crash there. |
| `rnaturalearthhires` | `ne_states()` reads from it; it is not on CRAN. Five tests errored on CI. |
| **`cffr` — absent** | The inverse, and the worst one. The whole cffr block sat behind `requireNamespace("cffr")`. It silently skipped. "Metadata is consistent" was printed many times by a check that had *never executed the code that failed on CI*. `cff_write(".")` was wrong the entire time — cffr treats `"."` as a package name. |

**Rule.** A guard that hides its own absence converts a green run into a claim
about the developer's laptop. Announce the skip. And `R CMD check` — which runs
against the *installed namespace* — is the gate; `test_dir()` is not a
substitute.

---

## 2. Verification that verified nothing

- **The mutation harness's isolation was fictional.** `R CMD INSTALL "-l$path"`
  concatenated is not parsed; R falls back to the **default library**. So every
  mutant was installed over the real installation while the "private" temp lib
  stayed empty. Verdicts came out right by accident, and each run left a
  corrupted package behind — which then killed two unrelated test runs I
  misdiagnosed as a race. Now `-l` is a separate argument and the harness
  *refuses to report* unless the package is verifiably in its own library.

- **A mock that was pure decoration.** `local_mocked_bindings()` without
  `.package` binds in the calling environment, but `map_physicians()` calls
  `mysterymaps::map_acog_districts()` namespace-qualified. The mock was never
  consulted. `test_dir` said 1,082 pass / 0 fail; `R CMD check` said 5
  failures. It "passed" because the real function works *on this machine*.

- **Asserting labels instead of values.** Tests checked that the string
  `"50th Percentile"` appeared, never what the number was. Two
  high-consequence mutants survived on that: an inverted area ratio, and an
  `inner_join` that drops zero-coverage block groups and turns 8% median
  coverage into ~48%. A test that checks a caption cannot tell a correct
  pipeline from an inverted one.

- **Four coverage failures were about a stale artifact.** The coverage job had
  `dependencies: "all"` but no `local::.`, so it never built the package under
  test. It reported the pre-fix `Inf` colour on a commit where both check jobs
  — which build from source — passed. Four rounds of diagnosis spent on
  something that wasn't this code. *If two jobs disagree about the same commit,
  first ask whether they're testing the same code.*

---

## 3. Edits that reported success and hadn't happened

Three times, in a row, near the end:

1. `testthat (>= 3.0.0)` — upstream pins `3.1.5`. The regex never matched, so
   `mapproj`, `units` and `withr` were never added to `Suggests`. That single
   miss produced **three** of four red checks. The script printed "added"
   because it recorded intent before checking the result.
2. A skip guard written as a **loop** over package names, while the edit
   pattern-matched the line-by-line form. Five tests kept erroring.
3. Inline `webshot` mock blocks in a formatting the pattern didn't cover — only
   1 of 6 tests got the fix.

**Rule.** Re-read the file back and print what's actually there. Better: change
the *shape* so it can't drift — the fix was one `mm_setup_dot_map()` plus an
`awk` check that every test calling `map_physicians()` uses it.

---

## 4. Blaming the package for my own bug

Reported a memory problem in `mysterymaps` — "5 GB", then "9.78 GB cumulative
retention across test files" — and added a memory ceiling to the CI on that
premise.

The cause was one line in a test I wrote: `st_segmentize(dfMaxLength = 0.05)`.
`dfMaxLength` carries **units**, and on a geographic CRS sf reads a bare number
as **metres**. That densified one rectangle to **50,331,649 vertices**. It was
92% of the suite's runtime and 94% of its memory. After the fix: 110 s, 0.58 GB.

There was no memory problem in the package. Chasing it did surface real
geodesy — a lon/lat partition loses 0.26% of its area, flat under densification
— which is now a documented test. That doesn't excuse announcing a package
defect before checking my own fixture.

---

## 5. Fixes with a blast radius I didn't check

- **Declared an off-CRAN package in `Suggests`** to silence one R CMD check
  warning. `rnaturalearthhires` isn't on CRAN, so `setup-r-dependencies` could
  no longer resolve the dependency set **at all** — every job failed, including
  the lint job that had just gone green. Naming a package in `DESCRIPTION` is a
  decision about everyone who installs the package; it was made to quiet a
  warning. Replaced with a `tryCatch` that gives the same actionable message
  and costs nothing.

- **`options(warn = 2)` on the pkgdown build.** pkgdown emits an informational
  warning for every `@examplesIf` whose condition is FALSE at build time —
  which is every `@examplesIf interactive()` in this package, *by design*. The
  job failed on a documentation style the package deliberately uses.

---

## 6. Process

- **Never ran `git fetch` before starting.** Built the entire thing on a base
  that was a week stale; 12 commits had landed on `main`, several implementing
  the same fixes. Discovered at push time. `git fetch && git status -sb` first,
  so "clean" is distinguishable from "clean but 12 behind".

- **Bulk `git checkout` that looked additive and wasn't.** Overwrote three
  upstream test files, discarding 64 lines of their tests. Caught only because
  the staged diff showed `-22` on a file expected to be purely additive. Check
  `git diff --cached --numstat` for deletions before committing.

- **Edited a script while it was executing.** Rscript re-read from a stale byte
  offset and died with a phantom parse error after 20 valid mutant verdicts.
  Run long jobs from a frozen copy.

- **`gh pr merge --auto` merged immediately.** Auto-merge isn't enabled on this
  repo, so the flag silently degraded to a direct merge while checks were still
  pending. They turned out green; that was luck, not verification.

- **Three mutants mis-specified as high-consequence when they were
  *equivalent*.** Reversing the palette, negating an `is.na` filter, and
  `min`→`max` all changed nothing observable — `classIntervals` resets `n`
  itself, drops `Inf` itself, and the legend travels with the colours. Each was
  verified equivalent rather than assumed, then replaced. Mutating what *looks*
  consequential is not the same as mutating what the tests can observe.

- **A cheap dig at the user** — "since it took you asking twice". Their second
  ask was entirely reasonable. Don't editorialise; the findings stand alone.

---

## What actually worked

The tools caught the author more often than the author caught the package:

- The **mutation assault** found two real test gaps and three of its own bad
  mutants.
- **`tests with Suggests absent`** found five tests that *fail* instead of
  *skip*, on its first execution.
- The **per-file coverage floor** found seven untested error branches while the
  package-level number never dipped below its floor.
- The **capability guards** found both owned-but-unvalidated capabilities
  (address dedup, unseeded jitter) without being told they existed.
- The **CI self-test** proved the guards are semantic — renaming a wrapper
  around `parallel::mclapply` does not evade them.

Running the full CI on Actions — which required a temporary `pull_request`
trigger, because GitHub won't dispatch a `workflow_dispatch` workflow absent
from the default branch — found **seven broken jobs the PR lane structurally
could not**. Those 21 nightly jobs had never executed anywhere. Merging would
have been their first run.
