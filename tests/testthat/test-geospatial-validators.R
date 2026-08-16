# validate_sf_inputs() is the gate every spatial entry point runs its arguments
# through. Everything it rejects is something that produces a WRONG ANSWER
# rather than an error further down: a mismatched CRS gives areas off by orders
# of magnitude, an invalid ring gives an intersection that silently drops
# geometry, a degenerate bbox gives a zero denominator.

skip_if_no_sf <- function() skip_if_not_installed("sf")

test_that("it returns the inputs under their argument names", {
  skip_if_no_sf()
  out <- validate_sf_inputs(counties = mm_counties(), points = mm_points())
  expect_named(out, c("counties", "points"))
  expect_s3_class(out$counties, "sf")
  expect_s3_class(out$points, "sf")
})

test_that("supplying nothing is an error, not an empty success", {
  skip_if_no_sf()
  expect_error(validate_sf_inputs(), "No sf objects supplied")
})

test_that("a non-sf argument is named in the error", {
  skip_if_no_sf()
  expect_error(
    validate_sf_inputs(counties = data.frame(a = 1)),
    "`counties` must be an sf object")
})

test_that("a zero-row object is rejected before it can produce empty output", {
  skip_if_no_sf()
  expect_error(
    validate_sf_inputs(counties = mm_counties()[0, ]),
    "has no rows")
})

test_that("a missing CRS is an error rather than an assumption", {
  # sf will happily intersect two CRS-less objects and return nonsense.
  skip_if_no_sf()
  bare <- mm_counties()
  sf::st_crs(bare) <- NA
  expect_error(validate_sf_inputs(counties = bare), "Reference CRS is missing")
})

test_that("a differing CRS is transformed, with a warning naming the object", {
  skip_if_no_sf()
  projected <- sf::st_transform(mm_points(), 5070)
  expect_warning(
    out <- validate_sf_inputs(counties = mm_counties(), points = projected),
    "`points` CRS")
  expect_equal(sf::st_crs(out$points), sf::st_crs(4326))
})

test_that("target_crs transforms everything without warning", {
  # An explicit target is an instruction, not a surprise, so it is silent.
  skip_if_no_sf()
  out <- expect_silent(
    validate_sf_inputs(counties = mm_counties(), points = mm_points(),
                       target_crs = 5070))
  expect_equal(sf::st_crs(out$counties), sf::st_crs(5070))
  expect_equal(sf::st_crs(out$points), sf::st_crs(5070))
})

test_that("empty geometries are rejected and their row numbers reported", {
  skip_if_no_sf()
  cty <- mm_counties(3)
  sf::st_geometry(cty)[2] <- sf::st_sfc(sf::st_polygon(), crs = 4326)[[1]]
  expect_error(validate_sf_inputs(counties = cty),
               "contains empty geometries \\(rows: 2\\)")
})

test_that("an invalid geometry is repaired when auto_fix is on", {
  skip_if_no_sf()
  bowtie <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(0, 2, 0, 2, 0), c(0, 0, 2, 2, 0)))),
      crs = 4326))
  expect_false(all(sf::st_is_valid(bowtie)))
  out <- validate_sf_inputs(shape = bowtie)
  expect_true(all(sf::st_is_valid(out$shape)))
})

test_that("an invalid geometry is an error when auto_fix is off", {
  skip_if_no_sf()
  bowtie <- sf::st_sf(
    id = 1L,
    geometry = sf::st_sfc(
      sf::st_polygon(list(cbind(c(0, 2, 0, 2, 0), c(0, 0, 2, 2, 0)))),
      crs = 4326))
  expect_error(validate_sf_inputs(shape = bowtie, auto_fix = FALSE),
               "contains invalid geometries")
})

test_that("a geometry type outside the expected set is rejected by name", {
  skip_if_no_sf()
  expect_error(
    validate_sf_inputs(points = mm_points(),
                       expected_types = c("POLYGON", "MULTIPOLYGON")),
    "contains geometry types \\[POINT\\]")
})

test_that("expected_types accepts a character vector applied to every input", {
  skip_if_no_sf()
  expect_silent(
    validate_sf_inputs(a = mm_counties(), b = mm_surface(),
                       expected_types = c("POLYGON", "MULTIPOLYGON")))
})

test_that("expected_types accepts a named list, one entry per input", {
  skip_if_no_sf()
  expect_silent(
    validate_sf_inputs(
      counties = mm_counties(), points = mm_points(),
      expected_types = list(counties = c("POLYGON", "MULTIPOLYGON"),
                            points = "POINT")))
})

test_that("expected_types of the wrong shape is rejected", {
  skip_if_no_sf()
  expect_error(
    validate_sf_inputs(counties = mm_counties(), expected_types = 42),
    "must be a character vector or named list")
})

test_that("non-overlapping bounding boxes are refused", {
  # Two objects that do not overlap will intersect to nothing, and a
  # coverage figure of 0% reads as a finding rather than a mistake.
  skip_if_no_sf()
  far_away <- sf::st_sf(id = 1L, geometry = mm_square(x = 100, y = -40))
  expect_error(
    validate_sf_inputs(counties = mm_counties(), other = far_away),
    "do not overlap")
})

test_that("a degenerate bounding box is refused", {
  # A single point, or a set of exactly collinear ones, has zero extent in at
  # least one axis. Any area or overlap computed against it divides by zero and
  # returns a plausible-looking Inf or NaN rather than failing.
  skip_if_no_sf()
  one_point <- mm_points(n = 1)
  expect_error(validate_sf_inputs(pt = one_point), "degenerate bounding box")

  collinear <- mm_points(n = 3, lat = rep(40.5, 3))
  expect_error(validate_sf_inputs(pts = collinear), "degenerate bounding box")
})

test_that("the context string appears in every error it raises", {
  skip_if_no_sf()
  expect_error(
    validate_sf_inputs(counties = data.frame(a = 1),
                       context = "the widget build"),
    "the widget build")
})

test_that("unnamed inputs get positional names rather than failing", {
  skip_if_no_sf()
  out <- validate_sf_inputs(mm_counties())
  expect_named(out, "object_1")
})
