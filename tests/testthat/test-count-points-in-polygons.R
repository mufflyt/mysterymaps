testthat::local_edition(3)

skip_unless_spatial <- function() {
  testthat::skip_if_not_installed("sf")
}

.two_squares <- function() {
  sf::st_sf(
    id = 1:2,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      sf::st_polygon(list(cbind(c(-98, -96, -96, -98, -98), c(39, 39, 41, 41, 39)))),
      crs = 4326))
}

testthat::test_that("counts points per polygon, correctly attributed by location", {
  skip_unless_spatial()
  polys <- .two_squares()
  pts <- sf::st_as_sf(data.frame(lon = c(-97, -99), lat = c(40, 40.1)),
                      coords = c("lon", "lat"), crs = 4326)
  out <- mysterymaps_count_points_in_polygons(polys, pts)
  testthat::expect_identical(out$n, c(1L, 1L))
})

testthat::test_that("a polygon with no points gets 0, not NA", {
  skip_unless_spatial()
  polys <- .two_squares()
  pts <- sf::st_as_sf(data.frame(lon = -99, lat = 40.1), coords = c("lon", "lat"), crs = 4326)
  out <- mysterymaps_count_points_in_polygons(polys, pts)
  testthat::expect_identical(out$n, c(1L, 0L))
  testthat::expect_false(anyNA(out$n))
})

testthat::test_that("count_col names the output column", {
  skip_unless_spatial()
  polys <- .two_squares()
  pts <- sf::st_as_sf(data.frame(lon = -99, lat = 40.1), coords = c("lon", "lat"), crs = 4326)
  out <- mysterymaps_count_points_in_polygons(polys, pts, count_col = "providers")
  testthat::expect_true("providers" %in% names(out))
  testthat::expect_identical(out$providers, c(1L, 0L))
})

testthat::test_that("points in a different CRS are transformed to match polygons", {
  skip_unless_spatial()
  polys <- .two_squares()
  pts_4326 <- sf::st_as_sf(data.frame(lon = -99, lat = 40.1), coords = c("lon", "lat"), crs = 4326)
  pts_other_crs <- sf::st_transform(pts_4326, 3857)
  out <- mysterymaps_count_points_in_polygons(polys, pts_other_crs)
  testthat::expect_identical(out$n, c(1L, 0L))
})

testthat::test_that("`polygons` without an `id` column errors", {
  skip_unless_spatial()
  polys <- .two_squares()
  names(polys)[1] <- "not_id"
  pts <- sf::st_as_sf(data.frame(lon = -99, lat = 40.1), coords = c("lon", "lat"), crs = 4326)
  testthat::expect_error(mysterymaps_count_points_in_polygons(polys, pts))
})

testthat::test_that("non-sf inputs error", {
  testthat::expect_error(mysterymaps_count_points_in_polygons(data.frame(id = 1), data.frame()))
})
