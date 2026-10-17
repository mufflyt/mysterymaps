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
  # at the minimum, which an areally-interpolated denominator (hex-cell
  # population from sparse/empty land) routinely produces. cut() then errors
  # with "'breaks' are not unique". Caught building a real nationwide hex
  # map: 4,104 cells, most near-zero population.
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
