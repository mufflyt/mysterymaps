test_that("counts, denominator, and rate are computed over the FULL grid, not just hit cells", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(
    data.frame(lon = c(-99.1, -98.4, -97.7), lat = c(40.1, 40.3, 41.2)),
    coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    population = c(5000, 8000),
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98.5, -98.5, -100, -100), c(39, 39, 42, 42, 39)))),
      sf::st_polygon(list(cbind(c(-98.5, -97, -97, -98.5, -98.5), c(39, 39, 42, 42, 39)))),
      crs = 4326))

  out <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "population", per = 1000, cellsize = 0.5))

  expect_s3_class(out, "sf")
  expect_true(all(c("grid_id", "count", "denominator", "rate") %in% names(out)))
  expect_equal(sum(out$count), 3L)
  expect_equal(sum(out$denominator), 13000, tolerance = 1)
})

test_that("REGRESSION: a zero-count cell with real population gets rate 0, not NA", {
  # The three-way distinction this function exists to preserve: zero count
  # with population present is a MEASURED zero, not an unmeasured one.
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(
    data.frame(lon = -99.1, lat = 40.1), coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    population = 10000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
      crs = 4326))

  out <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "population", cellsize = 0.5))

  zero_count_cells <- out[out$count == 0 & out$denominator > 0.1, ]
  expect_gt(nrow(zero_count_cells), 0L)
  expect_true(all(zero_count_cells$rate == 0))
  expect_false(any(is.na(zero_count_cells$rate)))
})

test_that("min_denominator suppresses a rate for sparsely-populated cells", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(
    data.frame(lon = -99.1, lat = 40.1), coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    population = 10000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
      crs = 4326))

  out_no_floor <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "population", cellsize = 0.5))
  out_floored <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "population", cellsize = 0.5,
    min_denominator = 100))

  # Raising the floor from 0 to 100 can only ADD NA cells (sparsely-
  # populated ones now suppressed), never remove the ones already NA because
  # their denominator was genuinely zero.
  expect_gte(sum(is.na(out_floored$rate)), sum(is.na(out_no_floor$rate)))
  expect_gt(sum(is.na(out_floored$rate)) - sum(is.na(out_no_floor$rate)), 0L)
})

test_that("REGRESSION: a zero denominator is NA, not NaN, even with no floor set", {
  # 0/0 is undefined, not "below the reporting floor" -- this must hold even
  # when min_denominator is left at its default 0.
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -97, -97, -100, -100), c(39, 39, 42, 42, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                            coords = c("lon", "lat"), crs = 4326)
  # Population polygon covers only the WESTERN half of the boundary, so the
  # eastern cells interpolate to a genuine, exact zero.
  denominator_sf <- sf::st_sf(
    population = 10000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98.5, -98.5, -100, -100), c(39, 39, 42, 42, 39)))),
      crs = 4326))

  out <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "population", cellsize = 0.5))
  zero_denom <- out[out$denominator == 0, ]
  expect_gt(nrow(zero_denom), 0L)
  expect_true(all(is.na(zero_denom$rate)))
  expect_false(any(is.nan(zero_denom$rate)))
})

test_that("value_col renames the output rate column", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                            coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    pop = 1000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      crs = 4326))

  out <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "pop",
    value_col = "physicians_per_1k", cellsize = 1))
  expect_true("physicians_per_1k" %in% names(out))
  expect_false("rate" %in% names(out))
})

test_that("per rescales the rate", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                            coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    pop = 1000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      crs = 4326))

  out1 <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "pop", per = 1, cellsize = 1))
  out100 <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_sf, denominator_sf, "pop", per = 100, cellsize = 1))
  hit <- out1$count > 0
  expect_equal(out100$rate[hit], out1$rate[hit] * 100)
})

test_that("errors on an unknown denominator_col", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    crs = 4326))
  points_sf <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                            coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    pop = 1000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      crs = 4326))
  expect_error(
    mysterymaps_hex_bin_rate(boundary_sf, points_sf, denominator_sf, "nope"))
})

test_that("errors on a boundary with no CRS", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39))))))
  points_sf <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                            coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    pop = 1000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      crs = 4326))
  expect_error(
    mysterymaps_hex_bin_rate(boundary_sf, points_sf, denominator_sf, "pop"),
    "defined CRS")
})

test_that("errors on a zero-row boundary", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    crs = 4326))[0, ]
  points_sf <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                            coords = c("lon", "lat"), crs = 4326)
  denominator_sf <- sf::st_sf(
    pop = 1000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      crs = 4326))
  expect_error(
    mysterymaps_hex_bin_rate(boundary_sf, points_sf, denominator_sf, "pop"),
    "zero rows")
})

test_that("points arriving in another CRS are still counted in the right cells", {
  skip_if_not_installed("sf")
  boundary_sf <- sf::st_sf(geometry = sf::st_sfc(
    sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
    crs = 4326))
  points_wgs <- sf::st_as_sf(data.frame(lon = -99.1, lat = 40.1),
                             coords = c("lon", "lat"), crs = 4326)
  points_alb <- sf::st_transform(points_wgs, 5070)
  denominator_sf <- sf::st_sf(
    pop = 1000,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(-100, -98, -98, -100, -100), c(39, 39, 41, 41, 39)))),
      crs = 4326))

  out_wgs <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_wgs, denominator_sf, "pop", cellsize = 1))
  out_alb <- suppressWarnings(mysterymaps_hex_bin_rate(
    boundary_sf, points_alb, denominator_sf, "pop", cellsize = 1))
  expect_equal(sum(out_wgs$count), sum(out_alb$count))
})

test_that("sf is named in the error when it is not installed", {
  local_mocked_bindings(
    requireNamespace = function(package, ...) !identical(package, "sf"),
    .package = "base")
  expect_error(
    mysterymaps_hex_bin_rate(1, 2, 3, "x"), "needs the 'sf' package")
})
