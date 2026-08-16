# The scientific gate.
#
# One line at the end of the nightly, and no ambiguous yellow "mostly green"
# release state.
#
# The gate distinguishes three verdicts, and the distinction is the point:
#
#   PASS       this package owns the responsibility and validated it
#   NOT OWNED  this package does not implement the capability at all, and a
#              capability guard fails the build if it ever starts to
#   FAIL       owned, and either broken or unvalidated
#
# NOT OWNED is acceptable. NOT TESTED is not. A domain that reports nothing at
# all is treated as FAIL rather than skipped, because a silent job is exactly
# how a validation suite stops running without anyone noticing.

`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

results_dir <- Sys.getenv("MYSTERYMAPS_RESULTS_DIR", "ci-results")

# ---------------------------------------------------------------------------
# The scope registry: the single source of truth for what this repo claims.
#
# `job` is the workflow job whose result file settles the row. `owned = FALSE`
# rows are settled by the capability guards instead, and are expected to stay
# NOT OWNED until the package grows the capability.
# ---------------------------------------------------------------------------

SCOPE <- list(
  list(label = "SOFTWARE CONTRACTS",           job = "package-check",        owned = TRUE),
  list(label = "GEOMETRY ADVERSARIAL",         job = "geometry-assault",     owned = TRUE),
  list(label = "SPATIAL CONSERVATION",         job = "spatial-conservation", owned = TRUE),
  list(label = "CRS / S2 INVARIANCE",          job = "crs-s2-invariance",    owned = TRUE),
  list(label = "MAP SEMANTICS",                job = "map-semantics",        owned = TRUE),
  list(label = "ZERO-vs-MISSING",              job = "zero-vs-missing",      owned = TRUE),
  list(label = "BOUNDARY ASSIGNMENT",          job = "boundary-assignment",  owned = TRUE),
  list(label = "METAMORPHIC TESTS",            job = "metamorphic",          owned = TRUE),
  list(label = "PROPERTY TESTS",               job = "property-tests",       owned = TRUE),
  list(label = "MUTATION ASSAULT",             job = "mutation-assault",     owned = TRUE),
  list(label = "OUTPUT CONTRACTS",             job = "output-contracts",     owned = TRUE),
  list(label = "GLOBAL-STATE LEAKAGE",         job = "state-leakage",        owned = TRUE),
  list(label = "NATIONAL MAP FIXTURE",         job = "national-map-fixture", owned = TRUE),
  list(label = "NAMED REGRESSIONS",            job = "named-regressions",    owned = TRUE),
  list(label = "CI SELF-TEST",                 job = "ci-selftest",          owned = TRUE),

  list(label = "LINKAGE VALIDATION",           job = NA, owned = FALSE,
       because = "no candidate generation or linkage scoring in R/"),
  list(label = "DEDUP VALIDATION",             job = NA, owned = FALSE,
       because = "address dedup in geocode.R is owned and validated; provider identity dedup is upstream"),
  list(label = "DENOMINATOR VALIDATION",       job = NA, owned = FALSE,
       because = "value_col arrives already computed; this package never divides"),
  list(label = "SOURCE-DROPOUT VALIDATION",    job = NA, owned = FALSE,
       because = "no provider source ingestion in R/"),
  list(label = "PARALLEL LINKAGE VALIDATION",  job = NA, owned = FALSE,
       because = "no parallel execution in R/")
)

GUARD_ROW <- list(label = "CAPABILITY ESCALATION GUARDS", job = "capability-guards")

# ---------------------------------------------------------------------------
# Read job results
# ---------------------------------------------------------------------------
#
# Each job drops <job>.result containing one line: "pass" or "fail", plus
# optional accounting lines. A missing file is a missing job.

read_result <- function(job) {
  if (is.na(job)) return(NULL)
  path <- file.path(results_dir, paste0(job, ".result"))
  if (!file.exists(path)) return(NA_character_)
  lines <- trimws(readLines(path, warn = FALSE))
  lines <- lines[nzchar(lines)]
  if (!length(lines)) return(NA_character_)
  tolower(lines[[1]])
}

rows <- list()
failures <- character(0)
missing <- character(0)

for (s in SCOPE) {
  if (!isTRUE(s$owned)) {
    rows[[length(rows) + 1L]] <- list(label = s$label, verdict = "NOT OWNED",
                                      note = s$because)
    next
  }
  res <- read_result(s$job)
  if (is.null(res) || is.na(res)) {
    rows[[length(rows) + 1L]] <- list(label = s$label, verdict = "NOT TESTED",
                                      note = sprintf("job `%s` reported nothing", s$job))
    missing <- c(missing, s$job)
  } else if (identical(res, "pass")) {
    rows[[length(rows) + 1L]] <- list(label = s$label, verdict = "PASS", note = "")
  } else {
    rows[[length(rows) + 1L]] <- list(label = s$label, verdict = "FAIL",
                                      note = sprintf("job `%s` failed", s$job))
    failures <- c(failures, s$job)
  }
}

guard_res <- read_result(GUARD_ROW$job)
guard_verdict <- if (is.na(guard_res)) "NOT TESTED" else
  if (identical(guard_res, "pass")) "PASS" else "FAIL"
if (identical(guard_verdict, "FAIL")) failures <- c(failures, GUARD_ROW$job)
if (identical(guard_verdict, "NOT TESTED")) missing <- c(missing, GUARD_ROW$job)

# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

owned_rows <- Filter(function(r) r$verdict != "NOT OWNED", rows)
unowned_rows <- Filter(function(r) r$verdict == "NOT OWNED", rows)

line <- function(label, verdict) sprintf("%-34s %s", label, verdict)

out <- c(
  vapply(owned_rows, function(r) line(r$label, r$verdict), character(1)),
  "",
  vapply(unowned_rows, function(r) line(r$label, r$verdict), character(1)),
  "",
  line(GUARD_ROW$label, guard_verdict),
  ""
)

gate_pass <- !length(failures) && !length(missing)
out <- c(out, line("SCIENTIFIC GATE", if (gate_pass) "PASS" else "FAIL"))

cat(paste(out, collapse = "\n"), "\n")

summary_path <- Sys.getenv("GITHUB_STEP_SUMMARY", "")
if (nzchar(summary_path)) {
  writeLines(c("## Scientific gate", "", "```", out, "```", "",
               if (length(unowned_rows))
                 c("**NOT OWNED** means the capability is absent from this package and a",
                   "capability guard fails the build if it ever appears without its",
                   "adversarial tests. It does not mean untested.", "")),
             summary_path)
}

writeLines(paste(out, collapse = "\n"), file.path(results_dir, "scientific-gate.txt"))

# ---------------------------------------------------------------------------
# Verdict
# ---------------------------------------------------------------------------

if (length(missing)) {
  for (j in unique(missing)) {
    writeLines(sprintf(
      "::error::job `%s` produced no result file -- a domain that reports nothing is NOT TESTED, not skipped",
      j))
  }
}
for (j in unique(failures)) {
  writeLines(sprintf("::error::job `%s` failed its scientific validation", j))
}

if (!gate_pass) quit(status = 1)
cat("\nScientific gate is green.\n")
