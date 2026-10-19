testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
  testthat::skip_if_not_installed("classInt")
}

testthat::test_that("builds a ggplot with the bivariate fill and a legend inset", {
  skip_unless_spatial()
  counties <- mm_counties(n = 9, rate = c(1, 2, 3, 4, 5, 6, 7, 8, 9))
  counties$need <- rev(counties$rate)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need",
    x_label = "Providers per Capita", y_label = "Population Need")
  testthat::expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(L) class(L$geom)[1], character(1))
  testthat::expect_true("GeomSf" %in% geoms)
  testthat::expect_true(any(vapply(p$layers, function(L)
    inherits(L$geom, "GeomCustomAnn") || inherits(L$geom, "GeomCustom"), logical(1))))
})

testthat::test_that("errors on zero rows and on an unknown variable", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4)
  counties$need <- counties$rate
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(counties[0, ], x_var = "rate", y_var = "need",
                                         x_label = "X", y_label = "Y"),
    "zero rows")
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(counties, x_var = "nope", y_var = "need",
                                         x_label = "X", y_label = "Y"))
})

testthat::test_that("too few distinct values still renders via the rank fallback", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = c(1, 1, 1, 1))
  counties$need <- c(5, 4, 3, 2)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y")
  testthat::expect_s3_class(p, "ggplot")
})

testthat::test_that("REGRESSION: skewed data with collapsing quantile breaks still renders", {
  # classInt::classIntervals(style = "quantile") can produce duplicate break
  # points even with well over 3 distinct values present, if the
  # distribution is skewed enough -- e.g. a third or more of the values tied
  # at the minimum, which is exactly what an areally-interpolated denominator
  # (hex-cell population from sparse/empty land) produces nationally. cut()
  # then errors with "'breaks' are not unique". Caught building a real
  # nationwide hex map: 4,104 cells, most near-zero population.
  skip_unless_spatial()
  counties <- mm_counties(n = 10, rate = c(rep(0, 7), 1, 2, 3))
  counties$need <- 1:10
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y")
  testthat::expect_s3_class(p, "ggplot")
})

testthat::test_that("REGRESSION: a massively tied value never splits across classes", {
  # rank(x, ties.method = "first") breaks ties by each value's POSITION in
  # x, not by anything about the data. On a real nationwide hex map where
  # 86% of cells had physician count == 0, that scattered the identical
  # value 0 across all three classes purely by st_make_grid()'s row order
  # (which sweeps geographically) -- three near-perfect vertical bands at
  # mean longitudes -113.9/-97.5/-81.7 for cells that were all, in fact,
  # zero. Reported (correctly) as "that can't be correct." A tie-safe
  # fallback must put every occurrence of a repeated value in ONE class.
  skip_unless_spatial()
  n <- 300
  # 86% zeros (triggers the duplicate-breaks fallback), the rest increasing
  # -- same shape as the real data that exposed the bug.
  x <- c(rep(0, 258), seq_len(42))
  counties <- mm_counties(n = n, rate = x)
  counties$need <- seq_len(n)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y")
  key <- p$layers[[1]]$data$.mm_bivar_key
  x_class <- as.integer(sub("-.*", "", key))
  zero_classes <- unique(x_class[x == 0])
  testthat::expect_length(zero_classes, 1L)
})

testthat::test_that("MYSTERYMAPS_BIVARIATE_PALETTE has all 9 tercile-pair keys, each a valid hex colour", {
  testthat::expect_length(MYSTERYMAPS_BIVARIATE_PALETTE, 9L)
  expected_keys <- paste(rep(1:3, each = 3), rep(1:3, 3), sep = "-")
  testthat::expect_setequal(names(MYSTERYMAPS_BIVARIATE_PALETTE), expected_keys)
  testthat::expect_true(all(grepl("^#[0-9A-Fa-f]{6}$", MYSTERYMAPS_BIVARIATE_PALETTE)))
})

testthat::test_that("MYSTERYMAPS_BIVARIATE_PALETTE is the default palette argument", {
  testthat::expect_identical(
    formals(mysterymaps_bivariate_choropleth_map)$palette,
    quote(MYSTERYMAPS_BIVARIATE_PALETTE))
})

testthat::test_that("n_classes = 3 (the default) uses the literal hand-tuned palette, not a regenerated one", {
  # MYSTERYMAPS_BIVARIATE_PALETTE's middle cells are hand-tuned for midtone
  # separation, not a plain bilinear interpolation of its four corners --
  # the default path must use the literal constant, unchanged.
  skip_unless_spatial()
  counties <- mm_counties(n = 9, rate = 1:9)
  counties$need <- rev(counties$rate)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y")
  fill_scale <- Filter(function(s) "fill" %in% s$aesthetics, p$scales$scales)[[1]]
  testthat::expect_identical(unname(fill_scale$palette(9)), unname(MYSTERYMAPS_BIVARIATE_PALETTE))
})

testthat::test_that("n_classes != 3 auto-generates an n x n palette when palette is not supplied", {
  skip_unless_spatial()
  # rate and need are deliberately NOT perfectly correlated (a fixed
  # pseudo-random permutation of 1:25): a monotonic pairing (e.g. need =
  # rev(rate)) is perfectly anti-correlated and can only ever populate the
  # anti-diagonal 5 of 25 cells, which is correct behaviour, not something
  # this test should mistake for a bug.
  counties <- mm_counties(n = 25, rate = 1:25)
  counties$need <- c(13, 2, 19, 7, 24, 11, 4, 16, 22, 9, 1, 18, 6, 25, 14,
                     3, 20, 8, 17, 5, 12, 23, 10, 21, 15)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", n_classes = 5)
  key <- p$layers[[1]]$data$.mm_bivar_key
  testthat::expect_true(all(key %in% paste(rep(1:5, each = 5), rep(1:5, 5), sep = "-")))
  testthat::expect_gt(length(unique(key)), 5L)
  fill_scale <- Filter(function(s) "fill" %in% s$aesthetics, p$scales$scales)[[1]]
  testthat::expect_length(fill_scale$palette(25), 25L)
})

testthat::test_that("an explicit palette overrides auto-generation even when n_classes != 3", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = 1:4)
  counties$need <- rev(counties$rate)
  custom <- stats::setNames(c("#000000", "#111111", "#222222", "#333333"),
                            c("1-1", "2-1", "1-2", "2-2"))
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y",
    n_classes = 2, palette = custom)
  fill_scale <- Filter(function(s) "fill" %in% s$aesthetics, p$scales$scales)[[1]]
  testthat::expect_identical(unname(fill_scale$palette(4)), unname(custom))
})

testthat::test_that("a palette of the wrong length for n_classes errors", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = 1:4)
  counties$need <- rev(counties$rate)
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(
      counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y",
      n_classes = 5, palette = MYSTERYMAPS_BIVARIATE_PALETTE),
    "n_classes = 5")
})

testthat::test_that("n_classes ties never split across classes, generalized beyond terciles", {
  # The same regression as the tercile case, at a different n_classes.
  skip_unless_spatial()
  n <- 300
  x <- c(rep(0, 258), seq_len(42))
  counties <- mm_counties(n = n, rate = x)
  counties$need <- seq_len(n)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", n_classes = 5)
  key <- p$layers[[1]]$data$.mm_bivar_key
  x_class <- as.integer(sub("-.*", "", key))
  testthat::expect_length(unique(x_class[x == 0]), 1L)
})

testthat::test_that("n_classes below 2 errors", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = 1:4)
  counties$need <- rev(counties$rate)
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(
      counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", n_classes = 1),
    class = "simpleError")
})

testthat::test_that("zero_aware = FALSE (the default) leaves classing unchanged", {
  skip_unless_spatial()
  counties <- mm_counties(n = 6, rate = c(0, 0, 1, 2, 3, 4))
  counties$need <- c(1, 6, 2, 5, 3, 4)
  p_default <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y")
  p_explicit <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", zero_aware = FALSE)
  testthat::expect_identical(
    p_default$layers[[1]]$data$.mm_bivar_key,
    p_explicit$layers[[1]]$data$.mm_bivar_key)
})

testthat::test_that("zero_aware = TRUE gives an exact zero its own tier, separate from the lowest positive class", {
  skip_unless_spatial()
  counties <- mm_counties(n = 6, rate = c(0, 0, 1, 2, 3, 4))
  counties$need <- c(1, 6, 2, 5, 3, 4)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", zero_aware = TRUE)
  key <- p$layers[[1]]$data$.mm_bivar_key
  x_class <- as.integer(sub("-.*", "", key))
  testthat::expect_true(all(x_class[counties$rate == 0] == 0L))
  testthat::expect_true(all(x_class[counties$rate > 0] >= 1L))
})

testthat::test_that("zero_aware = TRUE on one axis still carries the other axis's own class", {
  # x = 0 for two rows with different y values must not collapse to the same
  # key -- only x's information is flattened by zero_aware, never y's.
  skip_unless_spatial()
  counties <- mm_counties(n = 6, rate = c(0, 0, 1, 2, 3, 4))
  counties$need <- c(1, 6, 2, 5, 3, 4)
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", zero_aware = TRUE)
  key <- p$layers[[1]]$data$.mm_bivar_key
  zero_rows <- key[counties$rate == 0]
  testthat::expect_length(unique(zero_rows), 2L)
  testthat::expect_true(all(grepl("^0-", zero_rows)))
})

testthat::test_that("zero_aware = TRUE auto-generates an (n_classes + 1) x (n_classes + 1) default palette", {
  skip_unless_spatial()
  counties <- mm_counties(n = 9, rate = c(0, 0, 0, 1, 2, 3, 4, 5, 6))
  counties$need <- rev(seq_len(9))
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y", zero_aware = TRUE)
  fill_scale <- Filter(function(s) "fill" %in% s$aesthetics, p$scales$scales)[[1]]
  testthat::expect_length(fill_scale$palette(16), 16L)
})

testthat::test_that("a palette of the wrong length for zero_aware = TRUE errors naming the zero tier", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = c(0, 1, 2, 3))
  counties$need <- rev(counties$rate)
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(
      counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y",
      zero_aware = TRUE, n_classes = 3, palette = MYSTERYMAPS_BIVARIATE_PALETTE),
    "zero_aware = TRUE")
})

testthat::test_that("zero_aware must be a single logical value", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = 1:4)
  counties$need <- rev(counties$rate)
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(
      counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y",
      zero_aware = "yes"))
})

# ---- SABOTEUR: a negative value bypasses zero_aware's zero/positive split --
# REAL BUG, FIXED. classify_axis() only tested `x_complete == 0`, so a
# NEGATIVE value (an upstream arithmetic error, not a measurement) fell
# through into the POSITIVE quantile classing and rendered in the same
# tercile as the lowest real positive value -- the exact conflation
# zero_aware exists to prevent, reached from the other end of the scale.
# mm_reject_negative() (mysterymaps_jenks_zero_scale()'s own guard) is
# reused here rather than re-implemented.
testthat::test_that("SABOTEUR: zero_aware = TRUE rejects a negative value instead of classing it as positive", {
  skip_unless_spatial()
  counties <- mm_counties(n = 5, rate = c(-50, 0, 2, 4, 9))
  counties$need <- 1:5
  testthat::expect_error(
    mysterymaps_bivariate_choropleth_map(
      counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y",
      zero_aware = TRUE),
    "negative"
  )
})

testthat::test_that("zero_aware = FALSE is unaffected by the negative-value guard (legacy behaviour preserved)", {
  skip_unless_spatial()
  counties <- mm_counties(n = 5, rate = c(-50, 0, 2, 4, 9))
  counties$need <- 1:5
  p <- mysterymaps_bivariate_choropleth_map(
    counties, x_var = "rate", y_var = "need", x_label = "X", y_label = "Y",
    zero_aware = FALSE)
  testthat::expect_s3_class(p, "ggplot")
})

testthat::test_that("mm_bivariate_palette() interpolates corners correctly at the corners themselves", {
  pal <- mm_bivariate_palette(3)
  testthat::expect_identical(unname(pal["1-1"]), "#E8E8E8")
  testthat::expect_identical(unname(pal["3-1"]), "#5AC8C8")
  testthat::expect_identical(unname(pal["1-3"]), "#BE64AC")
  testthat::expect_identical(unname(pal["3-3"]), "#3B4994")
  testthat::expect_length(pal, 9L)
})
