# Adversarial tests for the SSOT-backed state normalisation fix.
# The bug being pinned: the first non-missing row used to decide the format of
# the ENTIRE column, so mixed-format input silently dropped whichever rows did
# not match, lowercase abbreviations matched nothing, and DC was unrenderable.

rendered_regions <- function(p, value_col) {
  agg <- tapply(!is.na(p$data[[value_col]]), p$data$region, any)
  names(agg)[agg]
}

test_that("mixed abbreviation and full-name input renders BOTH rows", {
  df <- data.frame(region = c("CO", "Texas"), rate = c(0.5, 0.7),
                   stringsAsFactors = FALSE)
  p <- mysterymaps_map_acceptance_rate(df, "region", "rate")
  hit <- rendered_regions(p, "rate_pct")
  expect_true("colorado" %in% hit)
  expect_true("texas" %in% hit)
})

test_that("format detection does not depend on row order", {
  # first row a full name vs first row an abbreviation must give the same map
  for (input in list(c("CO", "Texas"), c("Texas", "CO"))) {
    df <- data.frame(region = input, rate = c(0.5, 0.7), stringsAsFactors = FALSE)
    p <- mysterymaps_map_acceptance_rate(df, "region", "rate")
    hit <- rendered_regions(p, "rate_pct")
    expect_true(all(c("colorado", "texas") %in% hit),
                info = paste(input, collapse = "/"))
  }
})

test_that("lowercase abbreviations render", {
  df <- data.frame(region = c("co", "ny"), rate = c(0.5, 0.6),
                   stringsAsFactors = FALSE)
  p <- mysterymaps_map_acceptance_rate(df, "region", "rate")
  hit <- rendered_regions(p, "rate_pct")
  expect_true(all(c("colorado", "new york") %in% hit))
})

test_that("District of Columbia renders -- the basemap carries it", {
  df <- data.frame(region = "DC", rate = 0.5, stringsAsFactors = FALSE)
  p <- mysterymaps_map_acceptance_rate(df, "region", "rate")
  expect_true("district of columbia" %in% rendered_regions(p, "rate_pct"))
  df2 <- data.frame(region = "District of Columbia", rate = 0.5,
                    stringsAsFactors = FALSE)
  p2 <- mysterymaps_map_acceptance_rate(df2, "region", "rate")
  expect_true("district of columbia" %in% rendered_regions(p2, "rate_pct"))
})

test_that("unrecognisable region values error rather than silently dropping", {
  df <- data.frame(region = c("CO", "zz"), rate = c(0.5, 0.6),
                   stringsAsFactors = FALSE)
  expect_error(
    mysterymaps_map_acceptance_rate(df, "region", "rate"),
    "not recognisable US states"
  )
  # the error names the offender
  err <- tryCatch(
    mysterymaps_map_acceptance_rate(df, "region", "rate"),
    error = function(e) conditionMessage(e)
  )
  expect_match(err, "zz")
})

test_that("Puerto Rico parses but warns it cannot be drawn", {
  df <- data.frame(region = c("PR", "CO"), rate = c(0.5, 0.6),
                   stringsAsFactors = FALSE)
  expect_warning(
    mysterymaps_map_acceptance_rate(df, "region", "rate"),
    "puerto rico"
  )
  # ... and Colorado still renders alongside
  p <- suppressWarnings(mysterymaps_map_acceptance_rate(df, "region", "rate"))
  expect_true("colorado" %in% rendered_regions(p, "rate_pct"))
})

test_that("NA rows pass through without error or warning", {
  df <- data.frame(region = c("CO", NA), rate = c(0.5, 0.6),
                   stringsAsFactors = FALSE)
  expect_silent(p <- mysterymaps_map_acceptance_rate(df, "region", "rate"))
  expect_true("colorado" %in% rendered_regions(p, "rate_pct"))
})

test_that("geographic_map shares the fix: mixed formats both aggregate", {
  skip_if_not(exists("mysterymaps_geographic_map"))
  df <- data.frame(state = c("CO", "Texas"), outcome = c(0.4, 0.6),
                   stringsAsFactors = FALSE)
  suppressWarnings(
    g <- mysterymaps_geographic_map(df, "state", "outcome")
  )
  agg <- tapply(!is.na(g$data$rate), g$data$region, any)
  hit <- names(agg)[agg]
  expect_true(all(c("colorado", "texas") %in% hit))
})

test_that("geographic_map errors on garbage states", {
  skip_if_not(exists("mysterymaps_geographic_map"))
  df <- data.frame(state = c("CO", "xx"), outcome = c(0.4, 0.6),
                   stringsAsFactors = FALSE)
  expect_error(
    suppressWarnings(mysterymaps_geographic_map(df, "state", "outcome")),
    "not recognisable US states"
  )
})

test_that("helper: whitespace-only and empty strings are treated as missing, not garbage", {
  out <- mysterymaps:::.mm_state_regions_lower(c("", "  ", "CO"))
  expect_equal(out[3], "colorado")
  expect_true(is.na(out[1]) && is.na(out[2]))
})

test_that("helper: warn_unmappable = FALSE suppresses the basemap warning", {
  expect_silent(mysterymaps:::.mm_state_regions_lower("PR", warn_unmappable = FALSE))
  expect_warning(mysterymaps:::.mm_state_regions_lower("PR"), "puerto rico")
})
