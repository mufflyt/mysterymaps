# mysterymaps_hrr_maps() draws its assembled grob with grid::grid.draw(), which
# is correct in a session and unwanted in a test run: with no device open, R
# opens the default one and leaves an Rplots.pdf next to the tests. That file
# then shows up as leftover detritus in R CMD check and as an untracked file in
# every subsequent `git status`.
#
# Send the whole suite's graphics to a throwaway device instead. teardown_env()
# closes it after the last test file.
withr::local_pdf(file.path(tempdir(), "mysterymaps-test-plots.pdf"),
                 .local_envir = testthat::teardown_env())

# The package memoises isochrone results in a namespace-level cache that lives
# for the whole session. Across a full suite run that cache is never released,
# and each entry holds an sf object.
#
# Measured: any single test file peaks around 0.35 GB, but the whole suite in
# one process climbs past 5 GB -- enough to be OOM-killed on a standard
# 7 GB GitHub runner. The scientific workflow shards by domain so each runner
# only sees a file or two, but R CMD check runs everything in one process and
# needs this.
withr::defer(mysterymaps::mysterymaps_clear_isochrone_cache(),
             envir = testthat::teardown_env())
