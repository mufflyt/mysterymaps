# SPEC sections 22 and 23: CRS invariance, and spherical versus planar.
#
# The error these catch is a calculation accidentally performed in degrees when
# square metres were required. It does not throw. It produces areas that are
# wrong by a factor that varies with latitude, so a national map acquires a
# north-south gradient that is an artifact of the projection and reads as a
# finding about the workforce.

skip_no_sf <- function() skip_if_not_installed("sf")

area_m2 <- function(x, crs) {
  as.numeric(sum(sf::st_area(sf::st_transform(sf::st_geometry(x), crs))))
}

test_that("equal-area measurement agrees from any starting CRS", {
  # The same polygon expressed three ways must measure the same, because the
  # measurement CRS is fixed at EPSG:5070 regardless of how it arrived.
  skip_no_sf()
  base <- sf::st_sf(id = 1L, geometry = mm_rect(-100, 39, -98, 41))
  starts <- list(wgs84 = base,
                 albers = sf::st_transform(base, 5070),
                 webmerc = sf::st_transform(base, 3857))

  areas <- vapply(starts, area_m2, numeric(1), crs = 5070)
  expect_equal(max(areas) / min(areas), 1, tolerance = 1e-6)
})

test_that("REGRESSION: area is not measured in degrees", {
  # Two polygons of identical shape at different latitudes have the same area
  # in degrees-squared and materially different areas on the ground. If these
  # come back equal, the measurement is in the wrong units.
  skip_no_sf()
  south <- sf::st_sf(id = 1L, geometry = mm_rect(-100, 26, -99, 27))
  north <- sf::st_sf(id = 1L, geometry = mm_rect(-100, 47, -99, 48))

  a_s <- area_m2(south, 5070)
  a_n <- area_m2(north, 5070)
  expect_gt(abs(a_s - a_n) / a_s, 0.05)

  # And the degenerate comparison the package must never make.
  deg_s <- as.numeric(sf::st_area(sf::st_geometry(south)))
  deg_n <- as.numeric(sf::st_area(sf::st_geometry(north)))
  expect_false(isTRUE(all.equal(deg_s / deg_n, a_s / a_n, tolerance = 1e-3)))
})

test_that("overlap proportions are invariant to the input CRS", {
  # The package's own overlap numbers, computed from inputs handed in as
  # WGS84 and as Albers. The proportion is dimensionless and must match.
  skip_no_sf()
  run <- function(bg, iso) {
    out <- withr::local_tempdir()
    suppressWarnings(suppressMessages(
      mysterymaps_calculate_overlap(bg, iso, 30, out)))
    tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                           colClasses = c(GEOID = "character"))
    tbl[order(tbl$GEOID), c("GEOID", "intersect_area")]
  }

  bg <- mm_block_groups(4)
  iso <- mm_isochrones()
  wgs <- run(bg, iso)
  alb <- run(sf::st_transform(bg, 5070), sf::st_transform(iso, 5070))

  expect_equal(wgs$GEOID, alb$GEOID)
  expect_equal(wgs$intersect_area, alb$intersect_area, tolerance = 1e-6)
})

test_that("the area method is recorded in the artifact, not assumed", {
  # Whatever the method, the output has to say which one. An area column with
  # no method beside it cannot be checked by anyone downstream.
  skip_no_sf()
  out <- withr::local_tempdir()
  suppressWarnings(suppressMessages(
    mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))
  tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                         colClasses = c(GEOID = "character"))
  expect_true("area_method" %in% names(tbl))
  expect_true(all(tbl$area_method == "projected:EPSG:5070"))
})

test_that("s2 and planar agree for small polygons well inside a UTM zone", {
  # Where the two methods are expected to be nearly equivalent, they must be.
  # A large disagreement here means one of them is not doing what it says.
  skip_no_sf()
  small <- sf::st_sf(id = 1L, geometry = mm_rect(-105.01, 39.74, -104.99, 39.76))
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  suppressMessages(sf::sf_use_s2(TRUE));  a_s2 <- area_m2(small, 5070)
  suppressMessages(sf::sf_use_s2(FALSE)); a_pl <- area_m2(small, 5070)
  expect_equal(a_s2, a_pl, tolerance = 1e-6)
})

test_that("the intended method is used regardless of the caller's s2 setting", {
  # A caller who has s2 off for their own reasons must still get the package's
  # documented answer, not a different one.
  skip_no_sf()
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)

  results <- lapply(c(TRUE, FALSE), function(state) {
    suppressMessages(sf::sf_use_s2(state))
    out <- withr::local_tempdir()
    suppressWarnings(suppressMessages(
      mysterymaps_calculate_overlap(mm_block_groups(4), mm_isochrones(), 30, out)))
    tbl <- utils::read.csv(file.path(out, "intersect_30_minutes.csv"),
                           colClasses = c(GEOID = "character"))
    tbl[order(tbl$GEOID), ]
  })
  expect_equal(results[[1]]$intersect_area, results[[2]]$intersect_area,
               tolerance = 1e-6)
})

test_that("a CRS round trip is lossless to within coordinate tolerance", {
  skip_no_sf()
  pts <- mm_points(5)
  back <- sf::st_transform(sf::st_transform(pts, 5070), 4326)
  expect_equal(sf::st_coordinates(back), sf::st_coordinates(pts),
               tolerance = 1e-7)
})
