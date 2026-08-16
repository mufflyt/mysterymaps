# SPEC section 52: prove the CI is not decorative.
#
# Every other job in this workflow answers "is the science right?". This one
# answers the question underneath it: "did the validation actually run?"
#
# The failure mode is specific and it is the worst one, because it looks
# exactly like success. A test file gets renamed and stops being collected. A
# filter stops matching. A runner exits 0 having discovered nothing. The gate
# goes green and the scientific guarantee has quietly evaporated.
#
# So this job deliberately breaks the harness in each of those ways and
# requires the harness to notice.

results_dir <- file.path(tempdir(), "selftest-results")
runner <- normalizePath(".github/scripts/run-domain.R")
gate <- normalizePath(".github/scripts/scientific-gate.R")

rscript <- file.path(R.home("bin"), "Rscript")

run <- function(script, args = character(), env = character()) {
  out <- suppressWarnings(system2(rscript, c(shQuote(script), args),
                                  stdout = TRUE, stderr = TRUE, env = env))
  list(status = attr(out, "status") %||% 0L, out = paste(out, collapse = "\n"))
}
`%||%` <- function(a, b) if (is.null(a)) b else a

failures <- character(0)
check <- function(label, condition, detail = "") {
  if (isTRUE(condition)) {
    cat(sprintf("  PASS  %s\n", label))
  } else {
    cat(sprintf("  FAIL  %s\n        %s\n", label, detail))
    failures <<- c(failures, label)
  }
}

# Report into the same results directory every other domain uses, so a
# self-test that silently stops running is itself caught by the gate.
results_dir_out <- Sys.getenv("MYSTERYMAPS_RESULTS_DIR", "ci-results")
dir.create(results_dir_out, recursive = TRUE, showWarnings = FALSE)
writeLines("fail", file.path(results_dir_out, "ci-selftest.result"))

cat("CI self-test: proving the harness detects its own absence\n")
cat(strrep("-", 66), "\n")

# ---------------------------------------------------------------------------
# 1. A job naming a test file that does not exist must fail, not skip.
# ---------------------------------------------------------------------------
unlink(results_dir, recursive = TRUE, force = TRUE)
r <- run(runner, c("selftest-missing", "test-file-that-does-not-exist.R"),
         env = paste0("MYSTERYMAPS_RESULTS_DIR=", results_dir))
check("a missing test file fails the job",
      r$status != 0,
      sprintf("exit status was %s", r$status))
check("a missing test file leaves a 'fail' result on disk",
      identical(trimws(readLines(file.path(results_dir, "selftest-missing.result"),
                                 warn = FALSE))[1], "fail"))

# ---------------------------------------------------------------------------
# 2. A job that discovers zero tests must fail, not report success.
# ---------------------------------------------------------------------------
empty_dir <- file.path(tempdir(), "selftest-empty", "tests", "testthat")
dir.create(empty_dir, recursive = TRUE, showWarnings = FALSE)
writeLines("# no tests here", file.path(empty_dir, "test-empty-selftest.R"))

unlink(results_dir, recursive = TRUE, force = TRUE)
dir.create(results_dir, recursive = TRUE, showWarnings = FALSE)
owd <- setwd(file.path(tempdir(), "selftest-empty"))
r <- run(runner, c("selftest-empty", "test-empty-selftest.R"),
         env = paste0("MYSTERYMAPS_RESULTS_DIR=", results_dir))
setwd(owd)
check("a test file containing no assertions fails the job",
      r$status != 0 || grepl("NO-TESTS-DISCOVERED", r$out),
      sprintf("exit %s", r$status))

# ---------------------------------------------------------------------------
# 3. The gate must fail when any domain reports nothing at all.
# ---------------------------------------------------------------------------
gate_dir <- file.path(tempdir(), "selftest-gate")
unlink(gate_dir, recursive = TRUE, force = TRUE)
dir.create(gate_dir, recursive = TRUE, showWarnings = FALSE)

all_jobs <- c("package-check", "geometry-assault", "spatial-conservation",
              "crs-s2-invariance", "map-semantics", "zero-vs-missing",
              "boundary-assignment", "metamorphic", "property-tests",
              "mutation-assault", "output-contracts", "state-leakage",
              "national-map-fixture", "named-regressions", "ci-selftest",
              "capability-guards")

write_all <- function(dir, jobs, value = "pass") {
  for (j in jobs) writeLines(value, file.path(dir, paste0(j, ".result")))
}

invisible(write_all(gate_dir, all_jobs))
r <- run(gate, env = paste0("MYSTERYMAPS_RESULTS_DIR=", gate_dir))
check("the gate passes when every domain reports pass", r$status == 0)

# Remove one result file: the gate must go red on NOT TESTED.
invisible(file.remove(file.path(gate_dir, "zero-vs-missing.result")))
r <- run(gate, env = paste0("MYSTERYMAPS_RESULTS_DIR=", gate_dir))
check("a silent domain fails the gate as NOT TESTED",
      r$status != 0 && grepl("NOT TESTED", r$out))
check("the gate names the domain that went silent",
      grepl("ZERO-vs-MISSING", r$out))

# Restore it, then make it fail: the gate must go red on FAIL.
writeLines("fail", file.path(gate_dir, "zero-vs-missing.result"))
r <- run(gate, env = paste0("MYSTERYMAPS_RESULTS_DIR=", gate_dir))
check("a failing domain fails the gate", r$status != 0 && grepl("FAIL", r$out))

# NOT OWNED rows must never be the reason the gate goes red.
invisible(write_all(gate_dir, all_jobs))
r <- run(gate, env = paste0("MYSTERYMAPS_RESULTS_DIR=", gate_dir))
check("NOT OWNED rows do not fail the gate",
      r$status == 0 && grepl("NOT OWNED", r$out))

# ---------------------------------------------------------------------------
# 4. The capability guards must fire when a guarded behaviour appears.
# ---------------------------------------------------------------------------
guard_root <- file.path(tempdir(), "selftest-guard")
unlink(guard_root, recursive = TRUE, force = TRUE)
dir.create(file.path(guard_root, "R"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(guard_root, "tests", "testthat"), recursive = TRUE,
           showWarnings = FALSE)
invisible(file.copy(".github", guard_root, recursive = TRUE))
writeLines("x <- 1", file.path(guard_root, "R", "harmless.R"))
writeLines("# no markers here", file.path(guard_root, "tests", "testthat",
                                          "test-nothing.R"))

owd <- setwd(guard_root)
r <- run(file.path(guard_root, ".github", "scripts", "capability-guards.R"))
setwd(owd)
check("guards pass on a package that owns nothing guarded", r$status == 0)

# Now introduce parallel execution with no invariance tests at all.
writeLines(c("run_all <- function(x) {",
             "  parallel::mclapply(x, identity)",
             "}"),
           file.path(guard_root, "R", "harmless.R"))
owd <- setwd(guard_root)
r <- run(file.path(guard_root, ".github", "scripts", "capability-guards.R"))
setwd(owd)
check("introducing parallel execution without invariance tests fails the guard",
      r$status != 0 && grepl("parallel execution", r$out))

# And the guard must be semantic: renaming the wrapper does not evade it.
writeLines(c("innocuously_named <- function(x) {",
             "  parallel::mclapply(x, identity)",
             "}"),
           file.path(guard_root, "R", "harmless.R"))
owd <- setwd(guard_root)
r <- run(file.path(guard_root, ".github", "scripts", "capability-guards.R"))
setwd(owd)
check("renaming the function does not evade the guard",
      r$status != 0 && grepl("parallel execution", r$out))

# ---------------------------------------------------------------------------
cat(strrep("-", 66), "\n")
if (length(failures)) {
  cat(sprintf("CI self-test FAILED (%d checks)\n", length(failures)))
  for (f in failures) writeLines(sprintf("::error::CI self-test: %s", f))
  quit(status = 1)
}
writeLines("pass", file.path(results_dir_out, "ci-selftest.result"))
cat("CI self-test passed: the harness detects its own absence.\n")
