# Mutation testing as scientific validation, not as a coverage metric.
#
# A generic mutation percentage is a weak claim: it can be 95% while the one
# surviving mutant is the one that turns missing data into observed zeros.
# What matters is that a specific list of high-consequence scientific
# corruptions cannot survive this test suite.
#
# Each mutant below is a deliberate, plausible corruption of the kind a tired
# person makes at 2am. Every one of them still produces a map. The suite must
# kill every single one.
#
# Usage:
#   Rscript .github/scripts/mutation-assault.R
#   Rscript .github/scripts/mutation-assault.R --mutant=na_becomes_zero

`%||%` <- function(a, b) if (is.null(a)) b else a

# Write machine-readable output beside the other CI results rather than into
# the package root, where R CMD check reports it as a non-standard top-level
# file -- a NOTE the gate deliberately does not allowlist.
out_dir <- Sys.getenv("MYSTERYMAPS_RESULTS_DIR", "ci-results")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

args <- commandArgs(trailingOnly = TRUE)
only <- sub("^--mutant=", "", grep("^--mutant=", args, value = TRUE))

# ---------------------------------------------------------------------------
# The mutant catalogue
# ---------------------------------------------------------------------------
#
# domain : which scientific responsibility the mutant attacks
# file   : source file to corrupt
# from   : exact text to replace (must appear exactly once unless `all`)
# to     : the corruption
# harm   : what a surviving mutant would mean for a published map

MUTANTS <- list(

  # -- Zero versus missing --------------------------------------------------
  list(id = "na_becomes_zero", domain = "zero-vs-missing",
       killers = c("test-zero-vs-missing.R", "test-national-map-fixture.R"),
       file = "R/jenks_zero_scale.R",
       from = "out[is.na(x)] <- na_col",
       to   = "out[is.na(x)] <- zero_col",
       harm = paste("An unmeasured county is painted as a measured zero and",
                    "the legend calls it 0. On a rare-subspecialty map this is",
                    "indistinguishable from the finding.")),

  list(id = "zero_becomes_na", domain = "zero-vs-missing",
       killers = c("test-zero-vs-missing.R", "test-national-map-fixture.R"),
       file = "R/jenks_zero_scale.R",
       from = "out[!is.na(x) & x <= 0] <- zero_col",
       to   = "out[!is.na(x) & x <= 0] <- na_col",
       harm = paste("A genuine provider desert is reported as missing data,",
                    "erasing the finding the map exists to show.")),

  list(id = "is_na_negated", domain = "zero-vs-missing",
       killers = c("test-zero-vs-missing.R", "test-jenks-zero-scale.R"),
       file = "R/jenks_zero_scale.R",
       from = "pos  <- n[!is.na(n) & n > 0]",
       to   = "pos  <- n[is.na(n) | n > 0]",
       harm = "NA re-enters the classifier and the break computation."),

  list(id = "na_legend_suppressed", domain = "zero-vs-missing",
       killers = c("test-zero-vs-missing.R", "test-national-map-fixture.R"),
       file = "R/jenks_zero_scale.R",
       from = "has_na <- anyNA(n)",
       to   = "has_na <- FALSE",
       harm = paste("The map still separates the colours but never tells the",
                    "reader that a no-data class exists.")),

  # -- Spatial operators ----------------------------------------------------
  list(id = "intersection_becomes_union", domain = "spatial",
       killers = c("test-spatial-conservation.R", "test-calculate-overlap.R"),
       file = "R/calculate_intersection_overlap_and_save.R",
       from = "intersect <- suppressWarnings(sf::st_intersection(block_groups_proj, isochrones_proj))",
       to   = "intersect <- suppressWarnings(sf::st_union(block_groups_proj, isochrones_proj))",
       harm = paste("Overlap becomes combined extent. Every block group appears",
                    "fully covered and the access gap disappears.")),

  list(id = "transform_removed", domain = "spatial",
       killers = c("test-spatial-conservation.R", "test-crs-s2-invariance.R"),
       file = "R/calculate_intersection_overlap_and_save.R",
       from = "block_groups_proj <- sf::st_transform(block_groups, area_crs)",
       to   = "block_groups_proj <- block_groups",
       harm = paste("Areas are measured in square degrees. The error varies",
                    "with latitude, so the national map gains a north-south",
                    "gradient that is pure projection artifact.")),

  list(id = "s2_left_off", domain = "spatial",
       killers = c("test-hrr.R", "test-boundary-and-state.R"),
       file = "R/hrr.R",
       from = "on.exit(suppressMessages(sf::sf_use_s2(old_s2)), add = TRUE)",
       to   = "invisible(old_s2)",
       harm = paste("Spherical geometry stays off for the rest of the session,",
                    "silently changing every later boundary assignment.")),

  list(id = "geometry_repair_skipped", domain = "spatial",
       killers = c("test-geometry-assault.R", "test-regressions-named.R"),
       file = "R/geospatial_validators.R",
       from = "obj <- sf::st_make_valid(obj)",
       to   = "obj <- obj",
       harm = paste("Self-intersecting isochrones from the routing API are",
                    "rejected or silently mismeasured."),
       all = TRUE),

  # -- Conservation and joins ----------------------------------------------
  list(id = "area_ratio_inverted", domain = "conservation",
       killers = c("test-spatial-conservation.R"),
       file = "R/calculate_intersection_overlap_and_save.R",
       from = "overlap = ifelse(.data$bg_area > 0, .data$intersect_area / .data$bg_area, NA_real_)",
       to   = "overlap = ifelse(.data$bg_area > 0, .data$bg_area / .data$intersect_area, NA_real_)",
       harm = "Overlap proportion is inverted; coverage exceeds 1 and is unbounded."),

  list(id = "left_join_becomes_inner", domain = "conservation",
       killers = c("test-calculate-overlap.R", "test-spatial-conservation.R"),
       file = "R/calculate_intersection_overlap_and_save.R",
       from = 'block_groups_proj <- dplyr::left_join(block_groups_proj, intersect_df, by = "GEOID")',
       to   = 'block_groups_proj <- dplyr::inner_join(block_groups_proj, intersect_df, by = "GEOID")',
       harm = paste("Block groups with no overlap vanish instead of scoring",
                    "zero. The denominator shrinks and coverage rises.")),

  list(id = "dedup_removed", domain = "conservation",
       killers = c("test-rng-and-dedup-discipline.R", "test-geocode.R"),
       file = "R/geocode.R",
       from = "unique_add <- dplyr::distinct(data, address)",
       to   = "unique_add <- data[, 'address', drop = FALSE]",
       harm = paste("Duplicate addresses are geocoded repeatedly and the join",
                    "back multiplies rows: providers are counted twice.")),

  # -- Comparison and ordering ---------------------------------------------
  list(id = "gt_becomes_gte", domain = "classification",
       killers = c("test-coverage-gates.R", "test-property-geometry.R"),
       file = "R/coverage_gates.R",
       from = "if (pct > max_missing_pct) {",
       to   = "if (pct >= max_missing_pct) {",
       harm = paste("The coverage gate fires when nothing is missing, or with",
                    "max_missing_pct = 0 never passes at all.")),

  list(id = "interval_closed_wrong_side", domain = "classification",
       killers = c("test-map-semantics.R", "test-jenks-zero-scale.R"),
       file = "R/jenks_zero_scale.R",
       from = "out <- cols[findInterval(x, brks, rightmost.closed = TRUE, all.inside = TRUE)]",
       to   = "out <- cols[findInterval(x, brks, rightmost.closed = FALSE, all.inside = FALSE)]",
       harm = paste("Values exactly on a break, and the maximum, fall outside",
                    "every class and render as transparent holes.")),

  # `min(k, length(upos))` -> `max(...)` was tried here and is an EQUIVALENT
  # MUTANT: classIntervals() resets n to the number of distinct finite values
  # internally, and k is then recomputed as length(brks) - 1, so the breaks are
  # byte-identical for every input tested. It was replaced rather than left in
  # the catalogue, because an unkillable mutant reports as a test gap forever.
  list(id = "k_ignored", domain = "classification",
       killers = c("test-jenks-zero-scale.R", "test-property-geometry.R"),
       file = "R/jenks_zero_scale.R",
       from = "k    <- min(k, length(upos))",
       to   = "k    <- length(upos)",
       harm = paste("The caller's requested class count is discarded, so a map",
                    "asked for 4 classes silently gets as many as the data have",
                    "distinct values.")),

  # Two earlier attempts at this slot were EQUIVALENT MUTANTS, and the second
  # is the more instructive:
  #
  #   sort(unique(pos), decreasing = TRUE)
  #     upos is used only for length() and for upos[[1]] in a branch reached
  #     only when length(upos) == 1. Nothing observable changes.
  #
  #   cols <- rev(palette(k))
  #     Measured, not assumed: reversing the palette also reverses leg_cols,
  #     so the legend travels WITH the colours and each value still lands on
  #     the legend line that describes it (value 1 -> "1-12", value 90 ->
  #     "51-90"). The map changes visual convention -- dark for low instead of
  #     dark for high -- and stays truthful, because the legend documents it.
  #
  # The scientifically fatal mutation is desynchronising the labels from the
  # colours, which is what this one does: value 1 is painted the colour the
  # legend captions "51-90".
  list(id = "labels_reversed", domain = "classification",
       killers = c("test-map-semantics.R", "test-property-geometry.R"),
       file = "R/jenks_zero_scale.R",
       from = "c(list(color = color, has_na = has_na), legend(c(zero_col, cols), c(zlab, labs)))",
       to   = "c(list(color = color, has_na = has_na), legend(c(zero_col, cols), c(zlab, rev(labs))))",
       harm = paste("The legend labels are desynchronised from the colours they",
                    "sit beside, so the counties with the most providers are",
                    "captioned as the ones with the fewest. Every class is still",
                    "mutually exclusive and exhaustive, the ranking is still",
                    "monotone in colour-space, and the map is exactly wrong.")),

  # -- Coverage gate --------------------------------------------------------
  list(id = "gate_inverted", domain = "coverage-gate",
       killers = c("test-coverage-gates.R", "test-geometry-assault.R"),
       file = "R/coverage_gates.R",
       from = "inside <- lengths(suppressMessages(sf::st_intersects(providers, g))) > 0",
       to   = "inside <- lengths(suppressMessages(sf::st_intersects(providers, g))) == 0",
       harm = paste("Providers inside their own surface are reported missing",
                    "and vice versa. The gate reports the opposite defect.")),

  # -- Artifact integrity ---------------------------------------------------
  list(id = "csv_not_written", domain = "output-contract",
       killers = c("test-output-contracts.R", "test-regressions-named.R"),
       file = "R/calculate_intersection_overlap_and_save.R",
       from = "utils::write.csv(intersect_df, output_csv, row.names = FALSE)",
       to   = "invisible(output_csv)",
       harm = paste("The canonical non-truncated tabular record disappears and",
                    "downstream scripts silently read zero rows.")),

  list(id = "csvt_types_numeric", domain = "output-contract",
       killers = c("test-output-contracts.R", "test-regressions-named.R"),
       file = "R/calculate_intersection_overlap_and_save.R",
       from = 'if (is.character(col) || is.factor(col)) "String" else "Real"',
       to   = '"Real"',
       harm = paste("GEOID is declared numeric, so 080010001 loads as",
                    "80010001 and Colorado's FIPS 08 becomes 8.")),

  list(id = "mapproj_guard_removed", domain = "software-contract",
       killers = c("test-regressions-named.R", "test-geographic-map.R"),
       file = "R/geographic_map.R",
       from = 'if (!requireNamespace("mapproj", quietly = TRUE)) {',
       to   = 'if (FALSE) {',
       harm = paste("The function returns a ggplot that cannot be rendered;",
                    "the failure surfaces inside someone else's ggsave().")),

  list(id = "seed_ignored", domain = "reproducibility",
       killers = c("test-rng-and-dedup-discipline.R"),
       file = "R/map_create_base.R",
       from = "    set.seed(seed)",
       to   = "    invisible(seed)",
       harm = "A published dot map cannot be regenerated.")
)

if (length(only)) {
  MUTANTS <- Filter(function(m) m$id %in% only, MUTANTS)
  if (!length(MUTANTS)) stop("No mutant matched --mutant=", paste(only, collapse = ","))
}

# ---------------------------------------------------------------------------
# Harness
# ---------------------------------------------------------------------------

pkg_root <- normalizePath(".")
work_root <- file.path(tempdir(), "mutation-assault")
dir.create(work_root, recursive = TRUE, showWarnings = FALSE)

# Keep the property tests cheap; mutants are found by targeted assertions, not
# by luck across thousands of random draws.
Sys.setenv(MYSTERYMAPS_PROPERTY_N = "3")

run_suite <- function(src_dir, files = NULL) {
  lib <- file.path(src_dir, "..", "lib")
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)

  # `-l` must be a SEPARATE argument. Passing "-l<path>" concatenated is not
  # parsed by R CMD INSTALL, which then silently falls back to the DEFAULT
  # library -- so every mutant was being installed over the developer's real
  # installation while the temp lib stayed empty. The verdicts still came out
  # right, because the mutant was what got loaded, but the isolation was
  # fictional and each run left a corrupted package behind.
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  install_log <- suppressWarnings(system2(
    file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-docs", "--no-byte-compile",
      "-l", shQuote(lib), shQuote(src_dir)),
    stdout = TRUE, stderr = TRUE))
  if (!is.null(attr(install_log, "status")) && attr(install_log, "status") != 0) {
    # A mutant that will not even install is killed by the compiler, which
    # counts: the corruption cannot reach a map.
    return(list(status = "install-failed",
                detail = paste(utils::tail(install_log, 5), collapse = " | ")))
  }
  # Prove the isolation rather than assuming it. If the package is not in the
  # temp library, the run would be testing whatever is in the user library and
  # every verdict would be meaningless.
  if (!dir.exists(file.path(lib, "mysterymaps"))) {
    stop("mutation harness: package did not install into its private library (",
         lib, "); refusing to report verdicts against the user library.",
         call. = FALSE)
  }

  # Build the runner as a FILE rather than passing it with -e. The filter is a
  # regex containing characters the shell cares about, and shQuote()ing it
  # inside an already-shQuote()d -e argument produced nested single quotes:
  # the shell ate them, R received a truncated expression, and the process sat
  # waiting on stdin forever instead of failing.
  filt <- if (is.null(files)) "NULL" else
    sprintf('"^(%s)$"',
            paste(tools::file_path_sans_ext(sub("^test-", "", files)),
                  collapse = "|"))

  runner <- file.path(src_dir, "..", "run-tests.R")
  writeLines(c(
    sprintf('.libPaths(c(%s, .libPaths()))', encodeString(lib, quote = '"')),
    'suppressMessages(library(testthat)); suppressMessages(library(mysterymaps))',
    sprintf('r <- try(testthat::test_dir(%s, package = "mysterymaps",',
            encodeString(file.path(src_dir, "tests", "testthat"), quote = '"')),
    '                            reporter = "silent", stop_on_failure = FALSE,',
    sprintf('                            filter = %s), silent = TRUE)', filt),
    'if (inherits(r, "try-error")) { cat("RESULT fail\n"); quit(status = 0) }',
    'd <- as.data.frame(r)',
    'cat("RESULT", if (sum(d$failed) + sum(d$error) > 0) "fail" else "pass", "\n")',
    'cat("COUNTS", sum(d$passed), sum(d$failed), sum(d$error), "\n")'
  ), runner)

  out <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
                                  shQuote(runner),
                                  stdout = TRUE, stderr = TRUE,
                                  stdin = nullfile()))

  verdict <- trimws(sub("^RESULT ", "", grep("^RESULT ", out, value = TRUE)))
  counts <- grep("^COUNTS ", out, value = TRUE)
  if (!length(verdict)) {
    return(list(status = "suite-crashed",
                detail = paste(utils::tail(out, 5), collapse = " | ")))
  }
  list(status = verdict[[1]], detail = if (length(counts)) counts[[1]] else "")
}

apply_mutation <- function(src_dir, m) {
  path <- file.path(src_dir, m$file)
  txt <- readLines(path, warn = FALSE)
  blob <- paste(txt, collapse = "\n")
  n <- lengths(regmatches(blob, gregexpr(m$from, blob, fixed = TRUE)))
  if (n == 0L) return(FALSE)
  if (n > 1L && !isTRUE(m$all)) return(NA)
  blob <- if (isTRUE(m$all)) gsub(m$from, m$to, blob, fixed = TRUE)
          else sub(m$from, m$to, blob, fixed = TRUE)
  writeLines(strsplit(blob, "\n", fixed = TRUE)[[1]], path)
  TRUE
}

fresh_copy <- function(tag) {
  dst <- file.path(work_root, tag, "pkg")
  unlink(file.path(work_root, tag), recursive = TRUE, force = TRUE)
  dir.create(dst, recursive = TRUE, showWarnings = FALSE)
  for (item in c("R", "tests", "man", "inst", "DESCRIPTION", "NAMESPACE")) {
    from <- file.path(pkg_root, item)
    if (file.exists(from)) file.copy(from, dst, recursive = TRUE)
  }
  dst
}

# ---------------------------------------------------------------------------
# Baseline: the unmutated suite must be green, or every mutant "dies" for the
# wrong reason and the whole exercise proves nothing.
# ---------------------------------------------------------------------------

cat("Mutation assault\n"); cat(strrep("=", 74), "\n\n")
all_killers <- unique(unlist(lapply(MUTANTS, function(m) m$killers)))
cat(sprintf("Baseline (unmutated, %d killer files) ... ", length(all_killers)))
baseline <- run_suite(fresh_copy("baseline"), all_killers)
cat(baseline$status, "\n\n")
if (!identical(baseline$status, "pass")) {
  writeLines("::error::Mutation baseline is not green; mutant results are meaningless.")
  cat(baseline$detail, "\n")
  quit(status = 1)
}

# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------

results <- list()
for (m in MUTANTS) {
  cat(sprintf("%-30s [%s] ... ", m$id, m$domain))
  src <- fresh_copy(m$id)
  applied <- apply_mutation(src, m)

  if (isTRUE(is.na(applied))) {
    verdict <- "AMBIGUOUS"
    detail <- "pattern matched more than once; set all=TRUE or narrow it"
  } else if (!applied) {
    verdict <- "STALE"
    detail <- "pattern no longer present in the source"
  } else {
    res <- run_suite(src, m$killers)
    verdict <- if (res$status %in% c("fail", "install-failed", "suite-crashed"))
      "KILLED" else "SURVIVED"
    detail <- paste(res$status, res$detail)
  }
  cat(verdict, "\n")
  results[[m$id]] <- list(id = m$id, domain = m$domain, verdict = verdict,
                          detail = detail, harm = m$harm)
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

survived <- Filter(function(r) r$verdict == "SURVIVED", results)
broken   <- Filter(function(r) r$verdict %in% c("STALE", "AMBIGUOUS"), results)
killed   <- Filter(function(r) r$verdict == "KILLED", results)

cat("\n", strrep("=", 74), "\n", sep = "")
cat(sprintf("killed %d/%d   survived %d   unusable %d\n",
            length(killed), length(results), length(survived), length(broken)))

by_domain <- split(results, vapply(results, function(r) r$domain, character(1)))
cat("\nBy scientific domain:\n")
for (d in names(by_domain)) {
  k <- sum(vapply(by_domain[[d]], function(r) r$verdict == "KILLED", logical(1)))
  cat(sprintf("  %-20s %d/%d killed\n", d, k, length(by_domain[[d]])))
}

summary_path <- Sys.getenv("GITHUB_STEP_SUMMARY", "")
if (nzchar(summary_path)) {
  rows <- vapply(results, function(r)
    sprintf("| `%s` | %s | %s |", r$id, r$domain, r$verdict), character(1))
  writeLines(c("## Mutation assault", "",
               sprintf("killed **%d/%d**", length(killed), length(results)), "",
               "| Mutant | Domain | Verdict |", "|---|---|---|", rows),
             summary_path)
}

writeLines(paste0("{", paste(vapply(results, function(r)
  sprintf('"%s":"%s"', r$id, r$verdict), character(1)), collapse = ","), "}"),
  file.path(out_dir, "mutation-assault.json"))

fail <- FALSE
if (length(broken)) {
  cat("\nUNUSABLE MUTANTS (the catalogue has drifted from the source):\n")
  for (r in broken) {
    cat(sprintf("  - %s: %s\n", r$id, r$detail))
    writeLines(sprintf("::error::mutant `%s` is %s: %s", r$id, r$verdict, r$detail))
  }
  fail <- TRUE
}
if (length(survived)) {
  cat("\nSURVIVING HIGH-CONSEQUENCE MUTANTS:\n")
  for (r in survived) {
    cat(sprintf("  - %s [%s]\n      %s\n      declared killers: %s\n",
                r$id, r$domain, r$harm,
                paste(MUTANTS[[which(vapply(MUTANTS, function(m) m$id, character(1)) == r$id)]]$killers,
                      collapse = ", ")))
    writeLines(sprintf("::error::mutant `%s` SURVIVED: %s", r$id, r$harm))
  }
  fail <- TRUE
}

if (fail) quit(status = 1)
cat("\nEvery high-consequence scientific mutant was killed.\n")
