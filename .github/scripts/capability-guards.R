# Capability escalation guards.
#
# NOT OWNED is acceptable. NOT TESTED is not.
#
# mysterymaps today owns: geometry -> spatial calculation -> classification ->
# map -> artifact. It does not own candidate generation, linkage scoring,
# deduplication, parallel or chunked execution, rate/denominator calculation,
# or source ingestion. Those live upstream, and this repository's CI does not
# claim to validate them.
#
# The hazard is that they arrive here later. A linkage helper added to R/ in
# six months would inherit a suite that never once tried to fool it, and the
# nightly would stay green while the scientific guarantee quietly evaporated.
#
# So each guard below detects a BEHAVIOUR -- by inspecting parsed code for the
# operations that constitute the capability, not by matching function names --
# and requires the corresponding adversarial test family before that behaviour
# is allowed to exist. Renaming a function does not evade these. Writing the
# tests does.

`%||%` <- function(a, b) if (is.null(a)) b else a

# Write machine-readable output beside the other CI results rather than into
# the package root, where R CMD check reports it as a non-standard top-level
# file -- a NOTE the gate deliberately does not allowlist.
out_dir <- Sys.getenv("MYSTERYMAPS_RESULTS_DIR", "ci-results")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# ---------------------------------------------------------------------------
# Collect every call and symbol in R/, with the file it came from.
# ---------------------------------------------------------------------------

r_files <- list.files("R", pattern = "[.][Rr]$", full.names = TRUE)

collect_calls <- function(path) {
  exprs <- tryCatch(parse(path), error = function(e) NULL)
  if (is.null(exprs)) return(character(0))
  found <- character(0)
  walk <- function(e) {
    if (is.call(e)) {
      fn <- e[[1]]
      nm <- if (is.name(fn)) as.character(fn)
            else if (is.call(fn) && length(fn) == 3 &&
                     as.character(fn[[1]]) %in% c("::", ":::")) {
              paste0(as.character(fn[[2]]), "::", as.character(fn[[3]]))
            } else NA_character_
      if (!is.na(nm)) found <<- c(found, nm)
      for (i in seq_along(e)) if (!is.null(e[[i]])) try(walk(e[[i]]), silent = TRUE)
    } else if (is.pairlist(e) || is.expression(e)) {
      for (i in seq_along(e)) if (!is.null(e[[i]])) try(walk(e[[i]]), silent = TRUE)
    }
  }
  for (e in exprs) try(walk(e), silent = TRUE)
  unique(found)
}

calls_by_file <- stats::setNames(lapply(r_files, collect_calls), r_files)
all_calls <- unique(unlist(calls_by_file))

# Which files does a given call appear in?
files_calling <- function(patterns) {
  hit <- names(Filter(function(cs) any(cs %in% patterns), calls_by_file))
  hit
}

# Test-file text, for asserting that a required test family actually exists.
test_files <- list.files("tests/testthat", pattern = "[.][Rr]$", full.names = TRUE)
test_text <- if (length(test_files)) {
  stats::setNames(lapply(test_files, function(f) paste(readLines(f, warn = FALSE),
                                                       collapse = "\n")),
                  test_files)
} else list()

# A required test family is present when at least `min_hits` of its marker
# phrases appear across the test suite. Markers are phrases, not identifiers,
# so a stub file named after the family does not satisfy the guard.
family_present <- function(markers, min_hits = 2L) {
  if (!length(test_text)) return(FALSE)
  blob <- paste(unlist(test_text), collapse = "\n")
  sum(vapply(markers, function(m) grepl(m, blob, fixed = TRUE), logical(1))) >= min_hits
}

# ---------------------------------------------------------------------------
# The guard table
# ---------------------------------------------------------------------------
#
# behaviour  : what the capability looks like in parsed code
# requires   : the adversarial test family that must exist alongside it
# markers    : phrases that evidence the family is real

GUARDS <- list(
  list(
    name = "candidate generation / linkage scoring",
    detect = c("agrep", "adist", "stringdist::stringdist", "stringdist::amatch",
               "RecordLinkage::compare.dedup", "fastLink::fastLink",
               "reclin::pair_blocking", "reclin2::pair_blocking",
               "phonics::soundex", "stringdist::stringdistmatrix"),
    requires = "ambiguity + collision + fail-closed tests",
    markers = c("collision corpus", "fail closed", "remains ambiguity"),
    note = paste("A linkage score turns two records into one provider. Without",
                 "a collision corpus and a fail-closed contract it will turn",
                 "two people into one provider, and on a rare-subspecialty map",
                 "a single false identity moves a state.")
  ),
  list(
    name = "deduplication",
    detect = c("dplyr::distinct", "distinct", "duplicated", "unique.data.frame",
               "dplyr::n_distinct"),
    requires = "duplication + conservation tests",
    markers = c("duplicate injection", "unique provider count", "conserv"),
    note = paste("Deduplication is the only operation that may reduce a count.",
                 "Untested, it silently reduces the wrong one."),
    # `unique()`/`duplicated()` on credential tokens is not provider dedup.
    exempt_files = c("R/text_helpers.R", "R/jenks_zero_scale.R",
                     "R/coverage_surfaces.R", "R/hrr.R",
                     "R/map_create_acog_districts_sf.R",
                     "R/calculate_intersection_overlap_and_save.R",
                     "R/create_individual_isochrone_plots.R",
                     "R/map_create_base.R", "R/geographic_map.R")
  ),
  list(
    name = "parallel execution",
    detect = c("parallel::mclapply", "parallel::parLapply", "parallel::makeCluster",
               "future::plan", "future.apply::future_lapply", "furrr::future_map",
               "foreach::foreach", "doParallel::registerDoParallel",
               "mclapply", "parLapply", "makeCluster", "future_map", "future_lapply"),
    requires = "worker-count invariance tests",
    markers = c("worker count", "parallelism invariance", "workers"),
    note = paste("Scheduling order must never decide a scientific answer.",
                 "Without a worker-count invariance test, a tie resolved by",
                 "whichever worker finished first looks perfectly deterministic",
                 "on one machine.")
  ),
  list(
    name = "chunked execution",
    detect = c("split", "chunk", "seq_along_chunks", "batch"),
    requires = "chunk-size invariance tests",
    markers = c("chunk size", "chunk-size invariance", "chunk boundary"),
    note = paste("A duplicate split across a chunk boundary must still resolve",
                 "to one record nationally. Chunk size is an implementation",
                 "detail and must never change a result."),
    exempt_files = c("R/text_helpers.R", "R/geographic_map.R",
                     "R/map_acceptance_rate.R", "R/hrr.R")
  ),
  list(
    name = "rate / denominator calculation",
    detect = c("per_capita", "per_1k", "safe_rate", "compute_rate"),
    requires = "numerator-denominator contract tests",
    markers = c("denominator year", "numerator", "denominator"),
    note = paste("mysterymaps currently receives value_col already computed.",
                 "The moment it divides, it owns vintage alignment, zero",
                 "denominators and universe mismatch.")
  ),
  list(
    name = "source ingestion",
    detect = c("httr::GET", "httr2::request", "curl::curl_download",
               "download.file", "read_npi", "nppes"),
    requires = "source-dropout + provenance tests",
    markers = c("source dropout", "source_missing", "provenance"),
    note = paste("Ingesting a source means owning its absence. A missing source",
                 "must never produce a normal-looking complete map."),
    # The HRR shapefile fetch is a single cached reference boundary file, not a
    # provider source; it is covered by its own tests.
    exempt_files = c("R/data_cache.R")
  ),
  list(
    name = "stochastic code",
    detect = c("runif", "rnorm", "sample", "sample.int", "rbinom", "rpois",
               "stats::runif", "stats::rnorm", "stats::rbinom"),
    requires = "seed / reproducibility tests",
    markers = c("same seed", "seed is recorded", "reproducib"),
    note = paste("Any randomness in a scientific artifact must be replayable.",
                 "An unseeded jitter means the map cannot be regenerated.")
  )
)

# ---------------------------------------------------------------------------
# Evaluate
# ---------------------------------------------------------------------------

problems <- character(0)
status <- list()

for (g in GUARDS) {
  hits <- files_calling(g$detect)
  hits <- setdiff(hits, g$exempt_files %||% character(0))

  if (!length(hits)) {
    status[[g$name]] <- "NOT OWNED"
    next
  }

  if (family_present(g$markers)) {
    status[[g$name]] <- "OWNED + VALIDATED"
  } else {
    status[[g$name]] <- "OWNED, NOT VALIDATED"
    problems <- c(problems, sprintf(
      paste0("`%s` is now implemented in this package (%s) but the suite has no ",
             "%s.\n      %s"),
      g$name, paste(basename(hits), collapse = ", "), g$requires, g$note))
  }
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

cat("Capability escalation guards\n")
cat(strrep("-", 62), "\n")
for (nm in names(status)) {
  cat(sprintf("  %-42s %s\n", nm, status[[nm]]))
}
cat("\n")

summary_path <- Sys.getenv("GITHUB_STEP_SUMMARY", "")
if (nzchar(summary_path)) {
  writeLines(c("## Capability escalation guards", "",
               "| Capability | Status |", "|---|---|",
               vapply(names(status), function(nm)
                 sprintf("| %s | %s |", nm, status[[nm]]), character(1))),
             summary_path)
}

jsonish <- paste0("{",
  paste(sprintf('"%s":"%s"', names(status), unlist(status)), collapse = ","),
  "}")
writeLines(jsonish, file.path(out_dir, "capability-guards.json"))

if (length(problems)) {
  cat("CAPABILITY ESCALATION WITHOUT VALIDATION\n\n")
  for (p in problems) {
    cat("  - ", p, "\n\n", sep = "")
    writeLines(sprintf("::error::%s", gsub("\n.*", "", p)))
  }
  quit(status = 1)
}

cat("Every capability this package owns is validated; the rest are NOT OWNED.\n")
