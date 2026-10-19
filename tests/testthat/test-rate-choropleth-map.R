testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

testthat::test_that("rate is numerator/denominator*per, not a raw count", {
  skip_unless_spatial()
  counties <- mm_counties(n = 4, rate = c(0, 0, 0, 0))
  counties$n_providers <- c(1, 2, 0, 4)
  counties$population <- c(10000, 100000, 50000, 200000)
  p <- mysterymaps_rate_choropleth_map(
    counties, numerator_var = "n_providers", denominator_var = "population",
    numerator_label = "Providers", denominator_label = "People", per = 100000)
  testthat::expect_s3_class(p, "ggplot")
  layer_data <- p$layers[[1]]$data
  expected <- counties$n_providers / counties$population * 100000
  testthat::expect_equal(layer_data$.mm_rate, expected)
})

testthat::test_that("a zero denominator becomes NA, not Inf or divide-by-zero", {
  skip_unless_spatial()
  counties <- mm_counties(n = 3)
  counties$n_providers <- c(1, 2, 3)
  counties$population <- c(0, 1000, 2000)
  p <- mysterymaps_rate_choropleth_map(
    counties, numerator_var = "n_providers", denominator_var = "population",
    numerator_label = "Providers", denominator_label = "People")
  testthat::expect_true(is.na(p$layers[[1]]$data$.mm_rate[1]))
})

testthat::test_that("the legend title is built from the full-word labels", {
  skip_unless_spatial()
  counties <- mm_counties(n = 3)
  counties$n_providers <- c(1, 2, 3)
  counties$population <- c(1000, 2000, 3000)
  p <- mysterymaps_rate_choropleth_map(
    counties, numerator_var = "n_providers", denominator_var = "population",
    numerator_label = "Urogynecologists", denominator_label = "Women Age 40 and Older",
    per = 100000)
  built_title <- p$scales$scales[[1]]$name
  testthat::expect_true(grepl("Urogynecologists", built_title) &&
                        grepl("Women Age 40 and Older", built_title))
})

testthat::test_that("REGRESSION: a measured zero rate and an undefined (NA) rate get different colours", {
  # The original implementation coloured .mm_rate with a plain continuous
  # scale_fill_viridis_c(), which put a measured zero at the same dark end of
  # the gradient as every low-but-nonzero rate -- the exact mistake
  # mysterymaps_jenks_zero_scale() exists to prevent. A zero denominator (an
  # UNDEFINED rate) is a third, different thing again and must not collapse
  # into either class.
  skip_unless_spatial()
  counties <- mm_counties(n = 3)
  counties$n_providers <- c(0, 2, 3)
  counties$population <- c(10000, 100000, 0)
  p <- mysterymaps_rate_choropleth_map(
    counties, numerator_var = "n_providers", denominator_var = "population",
    numerator_label = "Providers", denominator_label = "People", per = 100000)
  fills <- p$layers[[1]]$data$.mm_fill_color
  testthat::expect_equal(fills[1], "#e0e0e0")   # measured zero -> zero_color
  testthat::expect_equal(fills[3], "#ffffff")   # undefined rate -> na_color
  testthat::expect_false(fills[2] %in% c("#e0e0e0", "#ffffff"))
})

testthat::test_that("zero_color and na_color are overridable", {
  skip_unless_spatial()
  counties <- mm_counties(n = 2)
  counties$n_providers <- c(0, 1)
  counties$population <- c(1000, 0)
  p <- mysterymaps_rate_choropleth_map(
    counties, numerator_var = "n_providers", denominator_var = "population",
    numerator_label = "A", denominator_label = "B",
    zero_color = "pink", na_color = "black")
  fills <- p$layers[[1]]$data$.mm_fill_color
  testthat::expect_equal(fills[1], "pink")
  testthat::expect_equal(fills[2], "black")
})

testthat::test_that("digits controls the decimal places in legend labels", {
  skip_unless_spatial()
  counties <- mm_counties(n = 2)
  counties$n_providers <- c(1, 2)
  counties$population <- c(10000, 20000)
  p <- mysterymaps_rate_choropleth_map(
    counties, numerator_var = "n_providers", denominator_var = "population",
    numerator_label = "A", denominator_label = "B", per = 100000, digits = 0)
  labs <- p$scales$scales[[1]]$labels
  testthat::expect_false(any(grepl("\\.", labs)))
})

testthat::test_that("errors on zero rows", {
  skip_unless_spatial()
  counties <- mm_counties(n = 2)
  counties$n_providers <- c(1, 2)
  counties$population <- c(100, 200)
  testthat::expect_error(
    mysterymaps_rate_choropleth_map(counties[0, ], numerator_var = "n_providers",
                                    denominator_var = "population",
                                    numerator_label = "A", denominator_label = "B"),
    "zero rows")
})
