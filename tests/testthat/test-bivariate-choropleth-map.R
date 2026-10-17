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
