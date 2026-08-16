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

# ---------------------------------------------------------------------------
# mm_area_in(): the unit the CRS declares, not the unit assumed
# ---------------------------------------------------------------------------
#
# The tests above pin that the package never measures in DEGREES. This block
# pins the other half, which is subtler because the arithmetic is valid and
# only the unit is wrong: a projected CRS in US survey feet returns ft^2, and
# `/ 1e6` calls that square kilometres.

# A box inside Colorado, so that EPSG:2232 -- NAD83 / Colorado Central, in US
# survey feet -- is the CRS a study would actually reach for rather than a zone
# the geometry sits nowhere near. State plane extrapolates far outside its zone
# without complaining, which makes a fixture in the wrong place look like a
# finding about the code.
co_box <- function() {
  sf::st_geometry(sf::st_sf(id = 1L, geometry = mm_rect(-105.5, 39.0, -104.5, 40.0)))
}

test_that("REGRESSION: /1e6 is square kilometres only when the CRS is in metres", {
  # The measurement that motivated the helper. Same polygon, two CRSs; the old
  # idiom is right in one and 10.76x out in the other, silently, because
  # nothing in the call ever mentions a unit.
  skip_no_sf()
  skip_if_not_installed("units")
  g <- co_box()
  truth <- mm_area_in(g, "km^2")
  feet <- sf::st_transform(g, 2232)

  expect_equal(mm_area_in(feet, "km^2"), truth, tolerance = 1e-2)
  expect_gt(as.numeric(sf::st_area(feet)) / 1e6 / truth, 10)
  expect_lt(as.numeric(sf::st_area(feet)) / 1e6 / truth, 11)
})

test_that("REGRESSION: a conformal CRS overstates area in correct-looking metres", {
  # The half unit conversion cannot catch. EPSG:3857 declares metres and
  # returns metres; they are Mercator metres, inflated by roughly sec^2(lat).
  # Web Mercator is the default of every slippy map, so a surface arriving off
  # a tile pipeline carries this with nothing to distinguish it.
  skip_no_sf()
  skip_if_not_installed("units")
  g <- co_box()
  truth <- mm_area_in(g, "km^2")
  merc <- sf::st_transform(g, 3857)

  expect_gt(as.numeric(sf::st_area(merc)) / 1e6 / truth, 1.5)
  # The helper is unmoved, because it does not measure in the caller's CRS.
  expect_equal(mm_area_in(merc, "km^2"), truth, tolerance = 1e-3)
})

test_that("mm_area_in() gives one answer from every CRS it is handed", {
  # The property that makes the two regressions above impossible to
  # reintroduce: the measurement basis is the package's, not the caller's.
  skip_no_sf()
  skip_if_not_installed("units")
  g <- co_box()
  areas <- vapply(c(lonlat = 4326L, albers = 5070L, webmerc = 3857L,
                    utm13 = 26913L, ftUS = 2232L),
                  function(crs) mm_area_in(sf::st_transform(g, crs), "km^2"),
                  numeric(1))
  # What is left is round-trip coordinate error, not projection choice.
  expect_lt(max(areas) / min(areas) - 1, 1e-4)
})

test_that("mm_area_in() gives one answer whatever the caller's s2 setting", {
  # With s2 off, sf routes geodetic area through lwgeom -- a Suggests, absent
  # on a bare runner -- so leaving the setting alone risks not a different
  # number but an error, on exactly the machines with nothing installed.
  skip_no_sf()
  skip_if_not_installed("units")
  before <- sf::sf_use_s2()
  on.exit(suppressMessages(sf::sf_use_s2(before)), add = TRUE)
  g <- co_box()

  suppressMessages(sf::sf_use_s2(TRUE));  on  <- mm_area_in(g, "km^2")
  suppressMessages(sf::sf_use_s2(FALSE)); off <- mm_area_in(g, "km^2")
  expect_identical(on, off)
  # And the caller's setting is handed back untouched.
  expect_false(sf::sf_use_s2())
})

test_that("mm_area_in() converts to the unit asked for, not a hard-coded one", {
  skip_no_sf()
  skip_if_not_installed("units")
  g <- co_box()
  km2 <- mm_area_in(g, "km^2")
  expect_equal(mm_area_in(g, "m^2") / 1e6, km2, tolerance = 1e-9)
  expect_equal(mm_area_in(g, "mi^2") * 2.589988, km2, tolerance = 1e-4)
})

test_that("mm_area_in() sums across features rather than returning the first", {
  skip_no_sf()
  skip_if_not_installed("units")
  one <- sf::st_sf(id = 1L, geometry = mm_rect(-100, 40, -99, 41))
  two <- sf::st_sf(id = 1:2, geometry = c(mm_rect(-100, 40, -99, 41),
                                          mm_rect(-98, 40, -97, 41)))
  expect_equal(mm_area_in(two, "km^2") / mm_area_in(one, "km^2"), 2,
               tolerance = 1e-3)
})

test_that("mm_area_in() refuses geometry with no CRS instead of assuming metres", {
  skip_no_sf()
  naked <- sf::st_sfc(sf::st_polygon(list(cbind(c(0, 1, 1, 0, 0),
                                                c(0, 0, 1, 1, 0)))))
  expect_error(mm_area_in(naked, "km^2"), "no CRS")
})

test_that("mm_area_in() returns zero for empty input rather than NA", {
  skip_no_sf()
  expect_identical(mm_area_in(sf::st_sfc(), "km^2"), 0)
})

test_that("a CRS round trip is lossless to within coordinate tolerance", {
  skip_no_sf()
  pts <- mm_points(5)
  back <- sf::st_transform(sf::st_transform(pts, 5070), 4326)
  expect_equal(sf::st_coordinates(back), sf::st_coordinates(pts),
               tolerance = 1e-7)
})
