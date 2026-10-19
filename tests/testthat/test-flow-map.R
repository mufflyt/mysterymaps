testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
  testthat::skip_if_not_installed("ggplot2")
}

fixture_routes <- function() {
  line1 <- sf::st_linestring(rbind(c(-99, 40), c(-98, 40.5)))
  line2 <- sf::st_linestring(rbind(c(-98, 41), c(-97, 41.2)))
  sf::st_sf(trip = c("a", "b"), minutes = c(12, 45),
            geometry = sf::st_sfc(line1, line2, crs = 4326))
}

testthat::test_that("routes render as coloured line layers over the basemap", {
  skip_unless_spatial()
  routes <- fixture_routes()
  basemap <- sf::st_as_sf(mm_square(-100, 39, w = 4))
  p <- mysterymaps_flow_map(routes, basemap, time_var = "minutes")
  testthat::expect_s3_class(p, "ggplot")
  geoms <- vapply(p$layers, function(L) class(L$geom)[1], character(1))
  testthat::expect_gte(sum(geoms == "GeomSf"), 2L)
})

testthat::test_that("origin and destination points add shape layers when supplied", {
  skip_unless_spatial()
  routes <- fixture_routes()
  basemap <- sf::st_as_sf(mm_square(-100, 39, w = 4))
  origins <- mm_points(n = 2, lon = c(-99, -98), lat = c(40, 41))
  dests <- mm_points(n = 2, lon = c(-98, -97), lat = c(40.5, 41.2))
  p <- mysterymaps_flow_map(routes, basemap, time_var = "minutes",
                            origin_points = origins, destination_points = dests)
  geoms <- vapply(p$layers, function(L) class(L$geom)[1], character(1))
  testthat::expect_gte(sum(geoms == "GeomSf"), 4L)
})

testthat::test_that("errors on zero-row routes", {
  skip_unless_spatial()
  routes <- fixture_routes()
  basemap <- sf::st_as_sf(mm_square(-100, 39, w = 4))
  testthat::expect_error(
    mysterymaps_flow_map(routes[0, ], basemap, time_var = "minutes"), "zero rows")
})
