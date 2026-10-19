testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
}

.two_counties <- function() {
  sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
      crs = 4326))
}

.one_region <- function() {
  sf::st_sf(id = "R1", geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-101, -95, -95, -101, -101), c(38, 38, 42, 42, 38)))),
    crs = 4326))
}

testthat::test_that("sums source values whose interior point falls inside the target", {
  skip_unless_spatial()
  out <- mysterymaps_aggregate_values_to_polygons(
    .two_counties(), data.frame(id = 1:2, n = c(3, 4)), .one_region(), value_col = "n")
  testthat::expect_identical(out$id, "R1")
  testthat::expect_identical(out$n, 7)
})

testthat::test_that("a source polygon outside every target contributes nothing", {
  skip_unless_spatial()
  far_county <- sf::st_sf(id = 3L, geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(10, 12, 12, 10, 10), c(10, 10, 12, 12, 10)))), crs = 4326))
  counties <- rbind(.two_counties(), far_county)
  out <- mysterymaps_aggregate_values_to_polygons(
    counties, data.frame(id = c(1, 2, 3), n = c(3, 4, 1000)), .one_region(), value_col = "n")
  testthat::expect_identical(out$n, 7)
})

testthat::test_that("value_col names both the lookup column and the output column", {
  skip_unless_spatial()
  out <- mysterymaps_aggregate_values_to_polygons(
    .two_counties(), data.frame(id = 1:2, fem65 = c(10, 20)), .one_region(), value_col = "fem65")
  testthat::expect_true("fem65" %in% names(out))
  testthat::expect_identical(out$fem65, 30)
})

testthat::test_that("SABOTEUR: a duplicate target_poly$id errors instead of silently fanning out the value on join-back", {
  # Two physically distinct target regions sharing an id are indistinguishable
  # once this result is joined back onto target_poly: both receive the
  # identical summed value, even though only one of them actually received
  # the contributing source polygon.
  skip_unless_spatial()
  regions_dup <- sf::st_sf(id = c("R1", "R1"), geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-101, -99, -99, -101, -101), c(38, 38, 42, 42, 38)))),
    sf::st_polygon(list(cbind(c(-99, -95, -95, -99, -99), c(38, 38, 42, 42, 38)))),
    crs = 4326))
  testthat::expect_error(
    mysterymaps_aggregate_values_to_polygons(
      .two_counties(), data.frame(id = 1:2, n = c(3, 4)), regions_dup, value_col = "n"),
    "target_poly")
})

testthat::test_that("missing `id` column in source_values errors", {
  skip_unless_spatial()
  testthat::expect_error(
    mysterymaps_aggregate_values_to_polygons(
      .two_counties(), data.frame(not_id = 1:2, n = c(3, 4)), .one_region(), value_col = "n"))
})
