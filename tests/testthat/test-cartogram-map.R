testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

fixture_counties <- function() {
  counties <- mm_counties(n = 4, rate = c(0, 0, 0, 0))
  counties$hub_lon <- -97.5
  counties$hub_lat <- 40.5
  counties$time_min <- c(10, 20, 30, 300)
  # straight_miles chosen so county 1-3 sit near the typical pace, and
  # county 4 is a deliberate near-zero-distance case that the clip must catch.
  counties$straight_miles <- c(9.6, 19.2, 28.8, 0.01)
  counties$id <- seq_len(4)
  counties
}

testthat::test_that("the warp scale factor is clipped to scale_clip", {
  skip_unless_spatial()
  counties <- fixture_counties()
  p <- mysterymaps_cartogram_map(
    counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
    time_var = "time_min", straight_distance_var = "straight_miles",
    scale_clip = c(0.2, 3))
  sf <- p$layers[[1]]$data
  testthat::expect_true(all(sf$.mm_scale_factor >= 0.2 - 1e-9))
  testthat::expect_true(all(sf$.mm_scale_factor <= 3 + 1e-9))
  # the near-zero-distance county (#4) would blow past 3x unclipped; confirm
  # the clip actually engaged rather than the raw ratio happening to be small
  row4 <- sf[sf$.mm_id == 4, ]
  testthat::expect_equal(row4$.mm_scale_factor, 3, tolerance = 1e-6)
})

testthat::test_that("rows missing time or distance are dropped, not warped as NA", {
  skip_unless_spatial()
  counties <- fixture_counties()
  counties$time_min[2] <- NA
  p <- mysterymaps_cartogram_map(
    counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
    time_var = "time_min", straight_distance_var = "straight_miles")
  testthat::expect_equal(nrow(p$layers[[1]]$data), 3L)
})

testthat::test_that("errors on zero rows", {
  skip_unless_spatial()
  counties <- fixture_counties()
  testthat::expect_error(
    mysterymaps_cartogram_map(
      counties[0, ], hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
      time_var = "time_min", straight_distance_var = "straight_miles"),
    "zero rows")
})
