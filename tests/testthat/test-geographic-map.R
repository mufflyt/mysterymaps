# A state choropleth of acceptance rates. The interesting behaviour is all in
# the preparation: detecting abbreviations vs full names, aggregating a binary
# outcome to a rate, and warning about states too thin to interpret.

skip_unless_ggplot <- function() {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("maps")
  # coord_map() renders through mapproj; without it these maps cannot be built.
  skip_if_not_installed("mapproj")
}

test_that("it returns a ggplot invisibly", {
  skip_unless_ggplot()
  df <- data.frame(state = c("CO", "CA", "TX"), offered = c(1, 0, 1))
  p <- suppressWarnings(mysterymaps_geographic_map(df))
  expect_s3_class(p, "ggplot")
  expect_invisible(suppressWarnings(mysterymaps_geographic_map(df)))
})

test_that("`data` must be a data frame and the columns must exist", {
  skip_unless_ggplot()
  expect_error(mysterymaps_geographic_map(1:3), "must be a data frame")
  expect_error(
    mysterymaps_geographic_map(data.frame(a = 1), state_col = "state"),
    "Column 'state' not found")
  expect_error(
    mysterymaps_geographic_map(data.frame(state = "CO"), outcome_col = "offered"),
    "Column 'offered' not found")
})

test_that("state_col and outcome_col must be single strings", {
  skip_unless_ggplot()
  df <- data.frame(state = "CO", offered = 1)
  expect_error(mysterymaps_geographic_map(df, state_col = c("a", "b")),
               "single character string")
  expect_error(mysterymaps_geographic_map(df, outcome_col = 1),
               "single character string")
})

test_that("a non-numeric outcome is refused", {
  # tapply(mean) on a character column returns NA for every state and draws a
  # uniformly grey map that looks like missing data rather than a type error.
  skip_unless_ggplot()
  expect_error(
    mysterymaps_geographic_map(data.frame(state = "CO", offered = "yes")),
    "must be numeric")
})

test_that("direction must be 1 or -1", {
  skip_unless_ggplot()
  expect_error(
    mysterymaps_geographic_map(data.frame(state = "CO", offered = 1),
                               direction = 2),
    "must be 1 or -1")
})

test_that("an unknown palette is rejected by match.arg", {
  skip_unless_ggplot()
  expect_error(
    mysterymaps_geographic_map(data.frame(state = "CO", offered = 1),
                               palette = "rainbow"))
})

test_that("title and subtitle must be single strings or NULL", {
  skip_unless_ggplot()
  df <- data.frame(state = "CO", offered = 1)
  expect_error(mysterymaps_geographic_map(df, title = c("a", "b")),
               "single character string or NULL")
  expect_error(mysterymaps_geographic_map(df, subtitle = 1),
               "single character string or NULL")
})

test_that("an all-missing state or outcome column is an error, not a blank map", {
  skip_unless_ggplot()
  expect_error(
    mysterymaps_geographic_map(data.frame(state = NA_character_, offered = 1)),
    "No non-missing values found in `state_col`")
  expect_error(
    mysterymaps_geographic_map(data.frame(state = "CO", offered = NA_real_)),
    "No non-missing values found in `outcome_col`")
})

test_that("two-letter codes and full names both reach the map data", {
  # The detection samples the first non-missing value, so the two forms must
  # produce the same picture from the same underlying rates.
  skip_unless_ggplot()
  abb  <- data.frame(state = rep(c("CO", "CA"), each = 5),
                     offered = rep(c(1, 0), each = 5))
  full <- data.frame(state = rep(c("Colorado", "California"), each = 5),
                     offered = rep(c(1, 0), each = 5))

  p_abb  <- suppressWarnings(mysterymaps_geographic_map(abb))
  p_full <- suppressWarnings(mysterymaps_geographic_map(full))

  rates <- function(p) {
    d <- p$data
    unique(d[!is.na(d$rate), c("region", "rate")])
  }
  expect_equal(rates(p_abb), rates(p_full), ignore_attr = TRUE)
})

test_that("a binary outcome is aggregated to a per-state mean", {
  skip_unless_ggplot()
  df <- data.frame(state = rep("CO", 10), offered = c(rep(1, 6), rep(0, 4)))
  p <- mysterymaps_geographic_map(df)
  co <- unique(p$data$rate[p$data$region == "colorado"])
  expect_equal(co, 0.6)
})

test_that("pre-aggregated rates pass through untouched", {
  skip_unless_ggplot()
  df <- data.frame(state = c("CO", "CA"), rate = c(0.55, 0.72))
  p <- suppressWarnings(mysterymaps_geographic_map(df, outcome_col = "rate"))
  expect_equal(unique(p$data$rate[p$data$region == "colorado"]), 0.55)
  expect_equal(unique(p$data$rate[p$data$region == "california"]), 0.72)
})

test_that("thin states are named in a warning, not silently mapped", {
  # A state with two calls gets a rate of 0.0 or 0.5 or 1.0 and is coloured as
  # confidently as one with 400.
  skip_unless_ggplot()
  df <- data.frame(state = c(rep("CO", 20), "WY", "WY"),
                   offered = c(rep(1, 20), 1, 0))
  expect_warning(mysterymaps_geographic_map(df, low_states_warn = 5L),
                 "fewer than 5 observation")
})

test_that("low_states_warn = 0 silences the thin-state warning", {
  skip_unless_ggplot()
  df <- data.frame(state = c("CO", "WY"), offered = c(1, 0))
  expect_no_warning(mysterymaps_geographic_map(df, low_states_warn = 0L))
})

test_that("values outside [0, 1] warn that they are being averaged as rates", {
  skip_unless_ggplot()
  df <- data.frame(state = rep("CO", 6), offered = c(3, 7, 2, 9, 4, 5))
  expect_warning(mysterymaps_geographic_map(df), "outside \\[0, 1\\]")
})

test_that("Alaska and Hawaii are dropped by default and kept on request", {
  skip_unless_ggplot()
  df <- data.frame(state = c(rep("CO", 6), rep("AK", 6), rep("HI", 6)),
                   offered = rep(c(1, 0), 9))

  conus <- mysterymaps_geographic_map(df)
  expect_false(any(c("alaska", "hawaii") %in% conus$data$region[!is.na(conus$data$rate)]))

  # ggplot2::map_data("state") is CONUS-only, so keeping them changes the
  # aggregation input even though neither can be drawn.
  both <- mysterymaps_geographic_map(df, include_alaska_hawaii = TRUE)
  expect_s3_class(both, "ggplot")
})

test_that("full-name Alaska and Hawaii are dropped too, not just the codes", {
  skip_unless_ggplot()
  df <- data.frame(state = c(rep("Colorado", 6), rep("Alaska", 6)),
                   offered = rep(c(1, 0), 6))
  p <- mysterymaps_geographic_map(df)
  expect_false("alaska" %in% p$data$region[!is.na(p$data$rate)])
})

test_that("polygon draw order survives the merge", {
  # merge() reorders rows; drawing polygons out of order produces a map with
  # states sewn to each other's coastlines.
  skip_unless_ggplot()
  df <- data.frame(state = c("CO", "CA", "TX", "NY", "FL"),
                   rate = c(0.5, 0.6, 0.4, 0.7, 0.8))
  d <- suppressWarnings(mysterymaps_geographic_map(df, outcome_col = "rate"))$data
  by_group <- split(d$order, d$group)
  expect_true(all(vapply(by_group, function(o) !is.unsorted(o), logical(1))))
})

test_that("states absent from the data keep the na_color rather than a value", {
  skip_unless_ggplot()
  df <- data.frame(state = c("CO", "CA"), rate = c(0.5, 0.6))
  p <- suppressWarnings(
    mysterymaps_geographic_map(df, outcome_col = "rate", na_color = "grey80"))
  expect_true(any(is.na(p$data$rate)))
})

test_that("ggplot2, maps and mapproj are each named in their own error", {
  # mapproj is the one that used to be missing: coord_map() resolves it at
  # RENDER time, so without the guard the failure surfaced inside a caller's
  # print() or ggsave() and named ggplot2 instead of this package.
  for (pkg in c("ggplot2", "maps", "mapproj")) {
    local_mocked_bindings(
      requireNamespace = function(package, ...) !identical(package, pkg),
      .package = "base")
    expect_error(
      mysterymaps_geographic_map(data.frame(state = "CO", offered = 1)),
      sprintf("'%s' is required", pkg))
  }
})
