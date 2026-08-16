# Run one scientific domain's test files and write its result + accounting.
#
# SPEC section 53. Every job emits structured accounting rather than relying on
# the process exit status alone, because the failure mode this guards against
# is a job that exits 0 having discovered and run nothing at all.
#
# Usage:
#   Rscript .github/scripts/run-domain.R <job-name> <file...>

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2L) stop("usage: run-domain.R <job-name> <test-file>...")

job <- args[[1]]
wanted <- args[-1]

results_dir <- Sys.getenv("MYSTERYMAPS_RESULTS_DIR", "ci-results")
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)

result_path <- file.path(results_dir, paste0(job, ".result"))
acct_path   <- file.path(results_dir, paste0(job, ".accounting"))

# Fail closed. If anything below aborts before the sentinel is written, the
# result file already on disk says "fail" and the gate reads that.
writeLines("fail", result_path)

suppressMessages(library(testthat))
suppressMessages(library(mysterymaps))

test_dir_path <- "tests/testthat"
present <- file.path(test_dir_path, wanted)
absent <- wanted[!file.exists(present)]

if (length(absent)) {
  writeLines(c(sprintf("job: %s", job),
               "sentinel: MISSING-TEST-FILES",
               sprintf("absent: %s", paste(absent, collapse = ", "))), acct_path)
  for (a in absent) {
    writeLines(sprintf("::error::job `%s` expects %s, which does not exist", job, a))
  }
  quit(status = 1)
}

# Memory ceiling. A domain that quietly grows past the runner's limit is
# OOM-killed, and an OOM-killed job looks like infrastructure flakiness rather
# than like a test that started retaining everything it touched. Fail on the
# package's own terms instead, with a number attached.
mem_limit_mb <- as.numeric(Sys.getenv("MYSTERYMAPS_MEM_LIMIT_MB", "3500"))
peak_heap_mb <- function() sum(gc()[, "max used"] * c(56, 8)) / 1024^2

started <- Sys.time()
res <- try(testthat::test_dir(
  test_dir_path, package = "mysterymaps", reporter = "silent",
  stop_on_failure = FALSE,
  filter = paste0("^(", paste(tools::file_path_sans_ext(sub("^test-", "", wanted)),
                              collapse = "|"), ")$")),
  silent = TRUE)

if (inherits(res, "try-error")) {
  writeLines(c(sprintf("job: %s", job), "sentinel: SUITE-CRASHED",
               paste("error:", conditionMessage(attr(res, "condition")))), acct_path)
  writeLines(sprintf("::error::job `%s` crashed before completing", job))
  quit(status = 1)
}

d <- as.data.frame(res)
elapsed <- as.numeric(difftime(Sys.time(), started, units = "secs"))

n_files <- length(unique(d$file))
passed <- sum(d$passed); failed <- sum(d$failed)
errored <- sum(d$error); skipped <- sum(d$skipped)

# A domain that discovered nothing is a failure, not a pass. This is the
# specific way a validation suite silently stops validating.
discovered_nothing <- n_files == 0L || (passed + failed + errored) == 0L

peak_mb <- peak_heap_mb()

writeLines(c(
  sprintf("job: %s", job),
  sprintf("peak_r_heap_mb: %.0f", peak_mb),
  sprintf("test_files_expected: %d", length(wanted)),
  sprintf("test_files_executed: %d", n_files),
  sprintf("tests_passed: %d", passed),
  sprintf("tests_failed: %d", failed),
  sprintf("tests_errored: %d", errored),
  sprintf("tests_skipped: %d", skipped),
  sprintf("elapsed_seconds: %.1f", elapsed),
  sprintf("sentinel: %s", if (discovered_nothing) "NO-TESTS-DISCOVERED"
                          else "SUITE-COMPLETED")
), acct_path)

cat(readLines(acct_path), sep = "\n")

if (length(d$test[d$failed > 0 | d$error])) {
  cat("\nFailing tests:\n")
  for (t in d$test[d$failed > 0 | d$error]) {
    cat("  - ", t, "\n", sep = "")
    writeLines(sprintf("::error::%s: %s", job, t))
  }
}

if (discovered_nothing) {
  writeLines(sprintf("::error::job `%s` discovered no tests", job))
  quit(status = 1)
}
if (is.finite(mem_limit_mb) && peak_mb > mem_limit_mb) {
  writeLines(sprintf(
    "::error::job `%s` peaked at %.0f MB of R heap, above the %.0f MB ceiling",
    job, peak_mb, mem_limit_mb))
  quit(status = 1)
}
if (failed > 0 || errored > 0) quit(status = 1)

writeLines("pass", result_path)
cat("\n", job, ": pass\n", sep = "")
