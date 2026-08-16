# Measure test coverage and fail below the floor.
#
# The floor lives in .github/coverage-floor.txt so raising it is a one-line,
# reviewable change. It is a floor and not a target: it only ever goes up.
#
# History, so the ratchet is visible: 90/75 when the scientific suite landed at
# 94.09%; raised to 93/85 at 95.29% measured, lowest file 91.7%. The gap is
# headroom for platform variance, not slack to spend.
# A per-file floor sits alongside the package floor, because a package at 80%
# can still contain a wholly untested file, and that file is where the bug is.

`%||%` <- function(a, b) if (is.null(a)) b else a

floor_file <- ".github/coverage-floor.txt"
cfg <- if (file.exists(floor_file)) {
  kv <- read.dcf(floor_file)
  as.list(kv[1, , drop = TRUE])
} else {
  list(Package = "0", File = "0")
}

pkg_floor  <- as.numeric(cfg$Package %||% 0)
file_floor <- as.numeric(cfg$File %||% 0)
exempt <- if (!is.null(cfg$ExemptFiles)) {
  trimws(strsplit(cfg$ExemptFiles, ",", fixed = TRUE)[[1]])
} else character(0)

cov <- covr::package_coverage(
  quiet = FALSE,
  clean = FALSE,
  install_path = file.path(normalizePath(tempdir(), winslash = "/"), "pkg")
)

pct <- covr::percent_coverage(cov)
by_file <- covr::coverage_to_list(cov)$filecoverage

cat(sprintf("\nPackage coverage: %.2f%% (floor %.2f%%)\n\n", pct, pkg_floor))
print(round(sort(by_file), 2))

# Machine-readable artefacts for the summary and for Codecov.
covr::to_cobertura(cov, filename = "cobertura.xml")
jsonlite::write_json(
  list(package = pct, files = as.list(by_file)),
  "coverage.json", auto_unbox = TRUE, pretty = TRUE
)

summary_path <- Sys.getenv("GITHUB_STEP_SUMMARY", "")
if (nzchar(summary_path)) {
  rows <- sprintf("| `%s` | %.1f%% |", names(by_file), by_file)
  writeLines(c(
    sprintf("## Coverage: %.2f%% (floor %.2f%%)", pct, pkg_floor),
    "", "| File | Coverage |", "|---|---|",
    rows[order(by_file)]
  ), summary_path)
}

failures <- character(0)

if (pct < pkg_floor) {
  failures <- c(failures, sprintf(
    "package coverage %.2f%% is below the floor of %.2f%%", pct, pkg_floor))
}

gated <- by_file[!names(by_file) %in% exempt]
low <- gated[gated < file_floor]
if (length(low)) {
  failures <- c(failures, sprintf(
    "%s at %.1f%% is below the per-file floor of %.1f%%",
    names(low), low, file_floor))
}

if (length(failures)) {
  for (f in failures) writeLines(sprintf("::error::%s", f))
  quit(status = 1)
}

cat("Coverage gate passed.\n")
