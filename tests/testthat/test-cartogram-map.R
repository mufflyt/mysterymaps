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

testthat::test_that("REGRESSION: the reference-drive-time label anchors at the line's start, not its midpoint", {
  # Centred on mean(ref_df$x), the label used to extend leftward past ref_x0
  # (only 3% of the panel width from bb$xmin) and render off the left edge of
  # the panel on real, non-square geography -- found building the README's
  # cartogram figure on North Carolina's counties. Left-justified at the
  # line's own start, the label can only extend rightward, which stays inside
  # the panel because the reference line itself is short relative to the
  # warped geometry's extent.
  skip_unless_spatial()
  counties <- fixture_counties()
  p <- mysterymaps_cartogram_map(
    counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
    time_var = "time_min", straight_distance_var = "straight_miles")
  is_text_layer <- vapply(p$layers, function(L) inherits(L$geom, "GeomText"), logical(1))
  is_line_layer <- vapply(p$layers, function(L) inherits(L$geom, "GeomLine"), logical(1))
  text_x <- unname(p$layers[[which(is_text_layer)]]$data$x)
  line_x0 <- unname(min(p$layers[[which(is_line_layer)]]$data$x))
  testthat::expect_equal(text_x, line_x0)
})

testthat::test_that("SABOTEUR: a negative time_var or straight_distance_var errors instead of clipping to the fastest tier", {
  # Without a guard, compute_scale_factor() clips a negative value to
  # scale_clip[1] -- the identical warp given to the single fastest/closest
  # LEGITIMATE row on the map, with nothing distinguishing a data error from a
  # genuinely fast trip.
  skip_unless_spatial()
  counties <- fixture_counties()
  counties$time_min[2] <- -50
  testthat::expect_error(
    mysterymaps_cartogram_map(
      counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
      time_var = "time_min", straight_distance_var = "straight_miles"),
    "negative")

  counties2 <- fixture_counties()
  counties2$straight_miles[3] <- -10
  testthat::expect_error(
    mysterymaps_cartogram_map(
      counties2, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
      time_var = "time_min", straight_distance_var = "straight_miles"),
    "negative")
})

testthat::test_that("SABOTEUR: swapped hub_lon_var/hub_lat_var errors with a clear WGS84 message, not a GEOS crash", {
  skip_unless_spatial()
  counties <- fixture_counties()
  # longitude and latitude swapped: -97.5 belongs in hub_lon, not hub_lat.
  counties$hub_lon <- 40.5
  counties$hub_lat <- -97.5
  testthat::expect_error(
    mysterymaps_cartogram_map(
      counties, hub_id_var = "id", hub_lon_var = "hub_lon", hub_lat_var = "hub_lat",
      time_var = "time_min", straight_distance_var = "straight_miles"),
    "WGS84")
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
