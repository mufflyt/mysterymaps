# =============================================================================
# Downstream-consumer smoke test
# =============================================================================
# mysterymaps_geographic_map() shipped for months missing a `labels` argument
# that mufflyt/midwifery's manuscript (Figures 3-4,
# manuscript/midwife_persistence.qmd) already called. This package's own test
# suite never called it that way -- every existing test used the default
# percent formatter -- so R-CMD-check, coverage, and Scientific Nightly all
# stayed green while the actual caller broke with "unused argument (labels =
# ...)". None of those suites can catch that class of bug: they test this
# package against itself, not against how a real project outside it calls in.
#
# This script runs the exact argument shapes lifted from real consumer code
# (not invented scenarios) against a fresh install of this package built from
# the commit under test -- see the workflow's `local::.` dependency, which is
# what makes that "the commit under test" rather than whatever the dependency
# cache happens to hold.
#
# ADD A SCENARIO HERE whenever a consumer's call breaks in a way this file did
# not anticipate. That is the failure this file exists to stop from recurring
# silently. Keep each scenario traceable to the real call site it was lifted
# from -- an invented scenario tests this package's idea of how it is used,
# which is exactly what already failed once.

stopifnot(requireNamespace("mysterymaps", quietly = TRUE))
stopifnot(requireNamespace("ggplot2", quietly = TRUE))

# Fixture shaped like manuscript/midwife_persistence.qmd's `sw` object
# (artifacts/state_obstetric_workforce.csv): 50 states + DC, a per-1,000 rate
# that is NOT a [0, 1] proportion, and a percentage-point share. Synthetic
# values -- this script does not have access to that repository's real data,
# nor does it need it; only the shape of the call matters.
set.seed(1)
sw <- data.frame(
  state       = c(state.abb, "DC"),
  rate_per_1k = runif(51, 0.5, 11),
  share_pct   = runif(51, 5, 60)
)

scenarios <- list(
  list(
    source = "mufflyt/midwifery manuscript/midwife_persistence.qmd, Figure 3",
    call = function() mysterymaps::mysterymaps_geographic_map(
      data            = sw,
      state_col       = "state",
      outcome_col     = "rate_per_1k",
      fill_label      = "Midwives per\n1,000 births",
      palette         = "viridis",
      low_states_warn = 0L,
      # The scenario this file exists to catch: a rate per 1,000, not a
      # proportion on [0, 1]. The default percent formatter rendered this as
      # "1 000%" before `labels` existed.
      labels          = function(x) sprintf("%.0f", x))
  ),
  list(
    source = "mufflyt/midwifery manuscript/midwife_persistence.qmd, Figure 4",
    call = function() mysterymaps::mysterymaps_geographic_map(
      data            = sw,
      state_col       = "state",
      outcome_col     = "share_pct",
      fill_label      = "Midwife share of\nbirth attendants",
      palette         = "cividis",
      low_states_warn = 0L,
      labels          = function(x) paste0(sprintf("%.0f", x), "%"))
  )
)

failures <- character(0)
for (s in scenarios) {
  cat(sprintf("--- %s ---\n", s$source))
  ok <- tryCatch({
    p <- s$call()
    if (!inherits(p, "ggplot")) stop("did not return a ggplot object")
    # print() is where coord_map() resolves mapproj. The manuscript comment
    # that found this the hard way calls print() "load-bearing" for the same
    # reason: a builder can return happily and fail only once someone prints
    # or ggsaves it.
    grDevices::pdf(NULL)
    print(p)
    grDevices::dev.off()
    TRUE
  }, error = function(e) {
    cat("FAILED:", conditionMessage(e), "\n")
    FALSE
  })
  if (!ok) failures <- c(failures, s$source)
}

if (length(failures)) {
  stop(sprintf(
    "%d downstream-consumer scenario(s) failed:\n%s",
    length(failures),
    paste("  -", failures, collapse = "\n")
  ), call. = FALSE)
}

cat(sprintf("All %d downstream-consumer scenario(s) passed.\n", length(scenarios)))
